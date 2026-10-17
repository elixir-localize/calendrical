defmodule Calendrical.Laws do
  @moduledoc false

  # The facts about a calendar's year that the laws of the calendar
  # contract are asserted over (`test/calendrical/laws_test.exs`). A law
  # names what Tempo relies on in place of knowing a calendar's kind: the
  # day scale round-trips, the fields order the days, the months and the
  # weeks tile the year, the labels agree with the periods, an absent
  # period is an error, the year-less bounds bound the years, and a shift
  # of nothing is nothing.
  #
  # Each function answers with the failures it found, so a passing law is
  # an empty list and a failing one names what was asked and what was
  # answered.

  @days_in_week 7

  # The library's calendars: every module of the application that is a
  # calendar and is compiled from `lib/`, less the calendars given.
  def calendars(except) do
    {:ok, modules} = :application.get_key(:calendrical, :modules)

    for module <- Enum.sort(modules),
        Code.ensure_loaded?(module),
        function_exported?(module, :valid_date?, 3),
        function_exported?(module, :naive_datetime_from_iso_days, 1),
        library_module?(module),
        module not in except,
        do: module
  end

  defp library_module?(module) do
    module.module_info(:compile)
    |> Keyword.get(:source)
    |> to_string()
    |> String.contains?("/lib/")
  end

  # The year of a calendar a Gregorian date falls in.
  def year_of(calendar, %Date{} = date), do: Date.convert!(date, calendar).year

  # Every day of a year, as the facts the laws read: the day, the date the
  # calendar gives it, the day the date gives back, the week of the year
  # and the day of the week.
  def atlas(calendar, year) do
    for day <- days_of_year(calendar, year) do
      {year, month, day_of_month} = date = calendar.date_from_iso_days(day)

      %{
        day: day,
        date: date,
        back: calendar.date_to_iso_days(year, month, day_of_month),
        valid?: calendar.valid_date?(year, month, day_of_month),
        week_of_year: calendar.week_of_year(year, month, day_of_month),
        day_of_week: elem(calendar.day_of_week(year, month, day_of_month, :default), 0)
      }
    end
  end

  def days_of_year(calendar, year) do
    %Date.Range{first_in_iso_days: first, last_in_iso_days: last} = calendar.year(year)
    first..last//1
  end

  # The number of days in a range of dates.
  def days_in(%Date.Range{first_in_iso_days: first, last_in_iso_days: last}), do: last - first + 1

  # Law 1: the date of a day gives the day back, and is a valid date.
  def round_trip_failures(atlas) do
    for %{day: day, date: date, back: back, valid?: valid?} <- atlas,
        back != day or not valid?,
        do: {day, date, back: back, valid?: valid?}
  end

  # Law 2: the dates of consecutive days are in lexicographic order.
  def order_failures(atlas) do
    atlas
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reject(fn [%{date: earlier}, %{date: later}] -> earlier < later end)
    |> Enum.map(fn [%{date: earlier}, %{date: later}] -> {earlier, later} end)
  end

  # Law 3: the months found by walking the year on the day scale through
  # `month/2`, each beginning the day after the one before ends. A month
  # that does not begin on the day it was asked for, or that `month/2`
  # has no range for, ends the walk with the failure.
  def months_walked(calendar, year) do
    %Date.Range{first_in_iso_days: first, last_in_iso_days: last} = calendar.year(year)
    walk(first, last, [], &month_holding(calendar, &1))
  end

  defp month_holding(calendar, day) do
    {year, month, _day} = calendar.date_from_iso_days(day)
    {calendar.month(year, month), {year, month}}
  end

  # The weeks of a week-year, `week/2` of 1 up to `weeks_in_year/1`.
  def weeks_of_year(calendar, year) do
    case calendar.weeks_in_year(year) do
      weeks when is_integer(weeks) -> Enum.map(1..weeks//1, &{&1, calendar.week(year, &1)})
      other -> {:error, {:weeks_in_year, other}}
    end
  end

  # Whether a list of ranges tiles the span from `first` to `last`: each
  # begins the day after the one before ends, the first on `first` and the
  # last on `last`.
  def tiling_failures(ranges, first, last) do
    bounds =
      Enum.map(ranges, fn {label, range} ->
        {label, range.first_in_iso_days, range.last_in_iso_days}
      end)

    gaps =
      bounds
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reject(fn [{_, _, earlier_last}, {_, later_first, _}] ->
        later_first == earlier_last + 1
      end)
      |> Enum.map(fn [earlier, later] -> {:gap_or_overlap, earlier, later} end)

    gaps ++ end_failures(bounds, first, last)
  end

  defp end_failures([], first, last), do: [{:empty, first, last}]

  defp end_failures(bounds, first, last) do
    {_label, first_start, _last} = hd(bounds)
    {_label, _first, last_end} = List.last(bounds)

    if first_start == first and last_end == last,
      do: [],
      else: [{:ends, {first, last}, {first_start, last_end}}]
  end

  defp walk(day, last, ranges, _period_holding) when day > last, do: {:ok, Enum.reverse(ranges)}

  defp walk(day, last, ranges, period_holding) do
    case period_holding.(day) do
      {%Date.Range{first_in_iso_days: ^day, last_in_iso_days: period_last} = range, label} ->
        walk(period_last + 1, last, [{label, range} | ranges], period_holding)

      {%Date.Range{} = range, label} ->
        {:error, {:does_not_begin_on_day, day, label, range}}

      {other, label} ->
        {:error, {:no_range, day, label, other}}
    end
  end

  # Law 4: a day's `week_of_year/3` names the week of `week/2` that holds
  # it.
  def week_label_failures(calendar, atlas) do
    atlas
    |> Enum.reject(fn %{day: day, week_of_year: label} -> in_week?(calendar, label, day) end)
    |> Enum.map(fn %{day: day, date: date, week_of_year: label} -> {day, date, label} end)
  end

  defp in_week?(calendar, {week_year, week}, day) do
    case calendar.week(week_year, week) do
      %Date.Range{first_in_iso_days: first, last_in_iso_days: last} -> day in first..last//1
      _no_week -> false
    end
  end

  defp in_week?(_calendar, _no_label, _day), do: false

  # Law 4: over any seven consecutive days the day of the week runs once
  # through 1 to 7, each day one after the day before.
  def day_of_week_failures(atlas) do
    atlas
    |> Enum.chunk_every(@days_in_week, 1, :discard)
    |> Enum.map(fn week -> Enum.map(week, & &1.day_of_week) end)
    |> Enum.reject(&(Enum.sort(&1) == Enum.to_list(1..@days_in_week) and consecutive?(&1)))
  end

  defp consecutive?(days_of_week) do
    days_of_week
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [earlier, later] -> rem(earlier, @days_in_week) + 1 == later end)
  end

  # Law 5: the periods a year does not have, each of which must be an
  # error: the months numbered up to the most any year has that this year
  # lacks and the ones beyond, the weeks beyond the last, and the quarters
  # beyond the fourth.
  def absent_periods(calendar, year) do
    {_fewest, most_months} = calendar.months_in_year_bounds()
    weeks = calendar.weeks_in_year(year)
    months = calendar.month_numbers(year)

    absent_months =
      for month <- [0 | Enum.to_list(1..(most_months + 1)//1)],
          not Enum.any?(months, &(month in &1)),
          do: {:month, [year, month]}

    absent_months ++
      [
        {:week, [year, 0]},
        {:week, [year, weeks + 1]},
        {:quarter, [year, 0]},
        {:quarter, [year, 5]}
      ]
  end

  def present_period_failures(calendar, periods) do
    for {period, arguments} <- periods,
        not match?({:error, _reason}, apply(calendar, period, arguments)),
        do: {period, arguments, apply(calendar, period, arguments)}
  end

  # Law 7: a shift of nothing is the date itself, and a shift of a day, a
  # week, a month or a year is a valid date, a day or a week of it the
  # day or the week after on the day scale.
  def shift_failures(calendar, atlas) do
    for %{day: day, date: {year, month, day_of_month} = date} <- Enum.take_every(atlas, 11),
        failure <- shift_failures(calendar, day, date, year, month, day_of_month),
        do: failure
  end

  defp shift_failures(calendar, day, date, year, month, day_of_month) do
    checks = [
      {%Duration{}, date},
      {%Duration{day: 1}, calendar.date_from_iso_days(day + 1)},
      {%Duration{week: 1}, calendar.date_from_iso_days(day + @days_in_week)},
      {%Duration{month: 1}, :valid},
      {%Duration{year: 1}, :valid}
    ]

    for {duration, expected} <- checks,
        shifted = calendar.shift_date(year, month, day_of_month, duration),
        not shifted?(calendar, shifted, expected),
        do: {date, duration, expected, shifted}
  end

  defp shifted?(calendar, {year, month, day}, :valid), do: calendar.valid_date?(year, month, day)
  defp shifted?(_calendar, shifted, expected), do: shifted == expected
end
