defmodule Calendrical.Base.Common do
  @moduledoc false

  # Logic shared by the makers and the derived API: the days of a
  # composite's year that have dates of their own, the date of a day of a
  # year, the test of a calendar module, and `diff/5`. See ARCHITECTURE.md
  # for the division of labour between the layers.

  # The behaviours a calendar implements. A loaded module that declares
  # both is a calendar, and what it then answers for each callback is its
  # author's to keep; one that exports some of their functions and declares
  # neither is not. `Calendrical.calendar_module?/1` and a composite's check
  # of its members ask here, each once the module is loaded.
  @calendar_behaviours [Calendar, Calendrical]

  # The first and the last of the days from `first_day` to `last_day` that
  # have a date of their own, one that names the day itself, or nil where
  # none has. They are the days a range of dates can run between: the date
  # of any other day names a day somewhere else.
  def dated_days(calendar, first_day, last_day) do
    with first_day when is_integer(first_day) <-
           Enum.find(first_day..last_day//1, &date?(calendar, &1)) do
      {first_day, Enum.find(last_day..first_day//-1, &date?(calendar, &1))}
    end
  end

  defp date?(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    calendar.date_to_iso_days(year, month, day) == iso_days
  end

  # The first and last days of a calendar's year, in ISO days. They are
  # those of its own `year/1`: a year need not begin on the first day of a
  # first month, nor end in a twelfth. A composite calendar gives the days
  # themselves, for where two stretches of its days carry the same dates the
  # dates of a year's first or last day name another day.
  def year_days(calendar, year) when is_integer(year) do
    bounds = if composite?(calendar), do: calendar.year_bounds(year), else: calendar.year(year)

    case bounds do
      {first, last} when is_integer(first) and is_integer(last) ->
        {:ok, first, last}

      %Date.Range{first: first, last: last} ->
        {:ok, calendar.date_to_iso_days(first.year, first.month, first.day),
         calendar.date_to_iso_days(last.year, last.month, last.day)}

      _no_such_year ->
        invalid_date(calendar, year: year)
    end
  end

  def year_days(calendar, year), do: invalid_date(calendar, year: year)

  # A day of a year as the calendar wrote it. In a composite calendar that
  # is the date the calendar in effect on the day gives it, even where the
  # date is another day's: England wrote 24 March 1156, the last day of its
  # 1155, as 24 March 1155. A shift or conversion that reaches such a day
  # answers the next day that has a date of its own instead.
  def date_at(calendar, iso_days) do
    writing =
      if composite?(calendar), do: calendar.calendar_for_iso_days(iso_days), else: calendar

    {year, month, day} = writing.date_from_iso_days(iso_days)
    %Date{year: year, month: month, day: day, calendar: calendar}
  end

  # The date of a day of a year. The days of a year are counted from its
  # first day, whichever day of the calendar that is.
  def date_from_day_of_year(calendar, year, day_of_year)
      when is_integer(year) and is_integer(day_of_year) and day_of_year > 0 do
    with {:ok, first, last} <- year_days(calendar, year) do
      if first + day_of_year - 1 <= last,
        do: date_at(calendar, first + day_of_year - 1),
        else: invalid_date(calendar, year: year, day_of_year: day_of_year)
    end
  end

  def date_from_day_of_year(calendar, year, day_of_year),
    do: invalid_date(calendar, year: year, day_of_year: day_of_year)

  def calendar_behaviours?(module) do
    declared =
      :attributes
      |> module.module_info()
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    Enum.all?(@calendar_behaviours, &(&1 in declared))
  end

  defp invalid_date(calendar, value) do
    {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: value)}
  end

  # A composite calendar answers for the days of its years, and for a shift
  # of years and months, itself.
  def composite?(calendar) do
    Code.ensure_loaded?(calendar) and function_exported?(calendar, :year_bounds, 1)
  end

  # The whole number of `date_part`s from `from` to `to` in `calendar`: the
  # inverse of the calendar's own `shift/6` (clamping the day into a shorter
  # month), the largest count it can add to the earlier date without passing
  # the later, negative when `to` is before `from`. A first guess from the
  # dates' positions is corrected against `shift/6`, so each calendar's own
  # arithmetic — a skipped year zero, a leap month, a reform's missing days —
  # is honoured. A calendar with a faster month count (a leap-month formula,
  # a lunisolar calendar's new moons) passes it as `months_between`.
  def diff(calendar, from, to, date_part, months_between \\ &months_between/3) do
    if iso_days(calendar, to) < iso_days(calendar, from) do
      -count(calendar, to, from, date_part, months_between)
    else
      count(calendar, from, to, date_part, months_between)
    end
  end

  defp count(calendar, from, to, :days, _months_between),
    do: iso_days(calendar, to) - iso_days(calendar, from)

  defp count(calendar, from, to, :weeks, months_between),
    do: div(count(calendar, from, to, :days, months_between), calendar.days_in_week())

  defp count(calendar, from, to, :quarters, months_between),
    do: div(count(calendar, from, to, :months, months_between), 3)

  defp count(calendar, from, to, :months, months_between),
    do: fit(calendar, from, to, :months, months_between.(calendar, from, to))

  defp count(calendar, {year_from, _, _} = from, {year_to, _, _} = to, :years, _months_between),
    do: fit(calendar, from, to, :years, year_to - year_from)

  # The largest count `shift/6` can add to `from` without passing `to`, stepped
  # to from a guess near it.
  defp fit(calendar, from, to, date_part, count) when is_integer(count) do
    cond do
      count > 0 and passes?(calendar, from, to, date_part, count) ->
        fit(calendar, from, to, date_part, count - 1)

      not passes?(calendar, from, to, date_part, count + 1) ->
        fit(calendar, from, to, date_part, count + 1)

      true ->
        count
    end
  end

  # Whether `count` of `date_part` added to `from` passes `to`. A shift that
  # reaches a later year than `to`'s passes it, which is known from the year
  # numbers alone, so no shift is made past `to`'s year: a calendar that
  # answers only for a range of years is never asked for one beyond it.
  defp passes?(calendar, from, to, date_part, count) do
    beyond_year?(calendar, from, to, date_part, count) or
      past?(calendar, shift(calendar, from, date_part, count), to)
  end

  defp beyond_year?(_calendar, {year_from, _, _}, {year_to, _, _}, :years, count),
    do: year_from + count > year_to

  # A year holds at most the calendar's largest number of months, so the
  # shift lands no earlier than the year that many months a year reach.
  defp beyond_year?(calendar, {year_from, month_from, _}, {year_to, _, _}, :months, count) do
    {_fewest, most} = months_in_year_range(calendar.info().months_in_year)
    year_from + div(month_from - 1 + count, most) > year_to
  end

  defp months_in_year_range({fewest, most}), do: {fewest, most}
  defp months_in_year_range(months) when is_integer(months), do: {months, months}

  defp shift(calendar, {year, month, day}, date_part, count),
    do: calendar.shift(year, month, day, date_part, count, clamp: true)

  defp past?(calendar, date, limit), do: iso_days(calendar, date) > iso_days(calendar, limit)

  defp iso_days(calendar, {year, month, day}) do
    case calendar.naive_datetime_to_iso_days(year, month, day, 0, 0, 0, {0, 0}) do
      {iso_days, _day_fraction} when is_integer(iso_days) -> iso_days
    end
  end

  # The months from `from`'s month to `to`'s, counted through each year's own
  # months: a year's months times the years between when every year has the
  # same number, otherwise year by year. A week calendar's month is the period
  # its `month_of_year/3` places the week in.
  def months_between(calendar, {year_from, _, _} = from, {year_to, _, _} = to) do
    months_before(calendar, year_from, year_to) + month_position(to) -
      month_position(from)
  end

  defp months_before(calendar, year_from, year_to) do
    case fixed_months_in_year(calendar) do
      months when is_integer(months) ->
        (year_to - year_from) * months

      :varies ->
        Enum.reduce(year_from..(year_to - 1)//1, 0, &(calendar.months_in_year(&1) + &2))
    end
  end

  defp fixed_months_in_year(calendar) do
    case calendar.months_in_year() do
      months when is_integer(months) -> months
      _varies_or_unknown -> :varies
    end
  end

  defp month_position({_year, month, _day}) do
    month
  end
end
