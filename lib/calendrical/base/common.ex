defmodule Calendrical.Base.Common do
  @moduledoc false

  # Logic shared verbatim by Calendrical.Base.Month and
  # Calendrical.Base.Week, plus the calendar-aligned week numbering
  # every calendar without compiled weeks shares. Only functions whose semantics are
  # identical across their users belong here; unit-specific
  # arithmetic stays in the respective base module. See
  # ARCHITECTURE.md for the division of labour between the layers.

  @days_in_week 7

  # The middle field is the month for month calendars and the week
  # for week calendars. Week calendars store the week number in the
  # %Date{} struct's :month field, because the stdlib Date struct
  # has no :week field.
  defguard is_date(year, month_or_week, day)
           when is_integer(year) and is_integer(month_or_week) and is_integer(day)

  # Maps a calendar year to its era year via the Gregorian year the
  # configuration designates: the :beginning year, the :ending year,
  # or for :majority the year containing most of the calendar year
  # (the beginning year when the year starts in January..June, the
  # ending year otherwise).
  def year_of_era(year, %{year: :ending} = config) when is_integer(year) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :beginning} = config) when is_integer(year) do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority, month_of_year: starts} = config)
      when is_integer(year) and starts <= 6 do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority} = config) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _month_or_week) do
    @days_in_week
  end

  # Calendar-aligned week numbering, which every calendar that does not
  # compile its own weeks shares: weeks run on the calendar's own week
  # boundary (the day its `day_of_week/4` numbers 1) and week 1 is the
  # week containing the first day of the year, so a year that opens
  # mid-week has a short week 1 and one that closes mid-week a short last
  # week. Every date numbers within its own year — no ISO-style spill into
  # the adjacent year's numbering. The year is the calendar's own
  # `year/1`, which need not begin on the first day of its first month (a
  # Julian year counted from 25 March).
  def week_of_year(calendar, year, month, day) when is_date(year, month, day) do
    with true <- calendar.valid_date?(year, month, day),
         {:ok, first, _days_in_year, offset} <- year_frame(calendar, year) do
      day_of_year = calendar.date_to_iso_days(year, month, day) - first + 1
      {year, div(day_of_year - 2 + offset, @days_in_week) + 1}
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week_of_year(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  def weeks_in_year(calendar, year) do
    case year_frame(calendar, year) do
      {:ok, _first, days_in_year, offset} ->
        weeks = weeks(days_in_year, offset)
        {weeks, days_in_year + offset - 1 - (weeks - 1) * @days_in_week}

      :error ->
        {:error, :invalid_date}
    end
  end

  # The days of week `week` of `year`: the calendar week holding them,
  # cut to the year.
  def week(calendar, year, week) when is_integer(week) do
    with {:ok, first, days_in_year, offset} <- year_frame(calendar, year),
         true <- week >= 1 and week <= weeks(days_in_year, offset) do
      first_day = first + max((week - 1) * @days_in_week - (offset - 1), 0)
      last_day = min(first + week * @days_in_week - offset, first + days_in_year - 1)

      Date.range(date_from_iso_days(calendar, first_day), date_from_iso_days(calendar, last_day))
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week(_calendar, _year, _week), do: {:error, :invalid_date}

  # The weeks of a month, numbered as `week_of_year/4` numbers the weeks of
  # a year: week 1 holds the month's first day and a week turns over on the
  # calendar's own week boundary. Days count from the month's first in ISO
  # days, so a month a calendar reform cuts short counts only its own.
  def week_of_month(calendar, year, month, day) when is_date(year, month, day) do
    with true <- calendar.valid_date?(year, month, day),
         %Date.Range{first: first} <- calendar.month(year, month) do
      first_days = calendar.date_to_iso_days(first.year, first.month, first.day)
      day_of_month = calendar.date_to_iso_days(year, month, day) - first_days + 1

      {first_dow, _first, _last} =
        calendar.day_of_week(first.year, first.month, first.day, :default)

      {month, div(day_of_month - 2 + first_dow, @days_in_week) + 1}
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week_of_month(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  # The ISO 8601 week of the day, whichever calendar names it, as a
  # week-based calendar's `iso_week_of_year/3` gives it.
  def iso_week_of_year(calendar, year, month, day) when is_date(year, month, day) do
    if calendar.valid_date?(year, month, day) do
      {year, month, day} =
        year
        |> calendar.date_to_iso_days(month, day)
        |> Calendrical.Gregorian.date_from_iso_days()

      Calendrical.Gregorian.iso_week_of_year(year, month, day)
    else
      {:error, :invalid_date}
    end
  end

  def iso_week_of_year(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  defp weeks(days_in_year, offset), do: div(days_in_year - 2 + offset, @days_in_week) + 1

  # The year's first day in ISO days, its length, and the position of its
  # first day within its (calendar-native) week, 1-based: 1 when the year
  # opens on the week's first day.
  defp year_frame(calendar, year) when is_integer(year) do
    case calendar.year(year) do
      %Date.Range{first: first, last: last} ->
        first_days = calendar.date_to_iso_days(first.year, first.month, first.day)
        last_days = calendar.date_to_iso_days(last.year, last.month, last.day)

        {first_dow, _first, _last} =
          calendar.day_of_week(first.year, first.month, first.day, :default)

        {:ok, first_days, last_days - first_days + 1, first_dow}

      _invalid ->
        :error
    end
  end

  defp year_frame(_calendar, _year), do: :error

  defp date_from_iso_days(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    %Date{year: year, month: month, day: day, calendar: calendar}
  end

  # The whole number of `date_part`s from `from` to `to` in `calendar`: the
  # inverse of the calendar's own `plus/6` (coercing the day into a shorter
  # month), the largest count it can add to the earlier date without passing
  # the later, negative when `to` is before `from`. A first guess from the
  # dates' positions is corrected against `plus/6`, so each calendar's own
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

  # The largest count `plus/6` can add to `from` without passing `to`, stepped
  # to from a guess near it.
  defp fit(calendar, from, to, date_part, count) when is_integer(count) do
    cond do
      count > 0 and past?(calendar, plus(calendar, from, date_part, count), to) ->
        fit(calendar, from, to, date_part, count - 1)

      not past?(calendar, plus(calendar, from, date_part, count + 1), to) ->
        fit(calendar, from, to, date_part, count + 1)

      true ->
        count
    end
  end

  defp plus(calendar, {year, month, day}, date_part, count),
    do: calendar.plus(year, month, day, date_part, count, coerce: true)

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
    months_before(calendar, year_from, year_to) + month_position(calendar, to) -
      month_position(calendar, from)
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
    with true <-
           Code.ensure_loaded?(calendar) and function_exported?(calendar, :months_in_year, 0),
         months when is_integer(months) <- calendar.months_in_year() do
      months
    else
      _varies_or_unknown -> :varies
    end
  end

  defp month_position(calendar, {year, month_or_week, day}) do
    if calendar.calendar_base() == :week do
      calendar.month_of_year(year, month_or_week, day)
    else
      month_or_week
    end
  end
end
