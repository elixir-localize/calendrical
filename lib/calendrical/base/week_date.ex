defmodule Calendrical.Base.WeekDate do
  @moduledoc false

  # Week dates by ISO 8601's rule over a calendar's own year: a week begins
  # on Monday, and week 1 of a year is the week that holds the year's fourth
  # day, so it has at least four days of the year. In the Gregorian calendar
  # these are ISO 8601's week dates. In any other calendar of months they
  # are the weeks RFC 7529 counts for a rule in that calendar (`BYWEEKNO`
  # with `RSCALE`): the same rule, over that calendar's year.
  #
  # `iso_week_of_year/3` is another question, the week of the Gregorian year
  # a day is in, whichever calendar names the day.
  #
  # A calendar of weeks has week dates of its own, counted in the weeks it
  # is built of.

  alias Calendrical.Base.Common
  alias Calendrical.Kday

  # ISO 8601's own numbers: the first day of a week, the days in one, and
  # the day of a year its first week holds.
  @monday 1
  @days_in_week 7
  @fourth_day 4

  # The date of a day of a week of a week-year.
  def date_from_week_date(calendar, week_year, week, day)
      when is_integer(week_year) and is_integer(week) and week >= 1 and is_integer(day) and
             day in 1..@days_in_week do
    with {:ok, first} <- first_week_start(calendar, week_year),
         {:ok, next_first} <- first_week_start(calendar, week_year + 1),
         week_start = first + (week - 1) * @days_in_week,
         true <- week_start < next_first do
      date_on(calendar, week_start + day - 1)
    else
      _no_such_week -> {:error, :invalid_date}
    end
  end

  def date_from_week_date(_calendar, _week_year, _week, _day) do
    {:error, :invalid_date}
  end

  # The week-year, the week and the day of the week of a date.
  def week_date_from_date(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day) do
      week_date_on(calendar, year, calendar.date_to_iso_days(year, month, day))
    else
      {:error, :invalid_date}
    end
  end

  # How many weeks a week-year has.
  def weeks_in_week_year(calendar, week_year) when is_integer(week_year) do
    with {:ok, first} <- first_week_start(calendar, week_year),
         {:ok, next_first} <- first_week_start(calendar, week_year + 1) do
      div(next_first - first, @days_in_week)
    else
      _no_such_year -> {:error, :invalid_date}
    end
  end

  def weeks_in_week_year(_calendar, _week_year) do
    {:error, :invalid_date}
  end

  # A day is of the week-year after its year where it is on or after that
  # year's first week, of its own year where it is on or after its first
  # week, and of the year before otherwise.
  defp week_date_on(calendar, year, days) do
    case week_year_start(calendar, year, days) do
      {:ok, week_year, start} ->
        {week_year, div(days - start, @days_in_week) + 1,
         Integer.mod(days - start, @days_in_week) + 1}

      :error ->
        {:error, :invalid_date}
    end
  end

  defp week_year_start(calendar, year, days) do
    Enum.find_value([year + 1, year, year - 1], :error, &started_by(calendar, &1, days))
  end

  defp started_by(calendar, week_year, days) do
    case first_week_start(calendar, week_year) do
      {:ok, start} when days >= start -> {:ok, week_year, start}
      _later_or_no_such_year -> nil
    end
  end

  # The first day of a year's week 1: the Monday on or before its fourth
  # day.
  defp first_week_start(calendar, year) do
    case Common.year_days(calendar, year) do
      {:ok, first, last} when first + @fourth_day - 1 <= last ->
        {:ok, Kday.kday_on_or_before(first + @fourth_day - 1, @monday)}

      _no_such_year ->
        :error
    end
  end

  defp date_on(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    %Date{year: year, month: month, day: day, calendar: calendar}
  end

  # A calendar of weeks counts its week dates in its own weeks
  # (`Calendrical.Base.Week.date_from_week_date/4`), and has as many weeks in
  # a week-year as in its year.
  def weeks_in_own_year(calendar, year) do
    case calendar.weeks_in_year(year) do
      {weeks, _days_in_last_week} when is_integer(weeks) -> weeks
      _no_such_year -> {:error, :invalid_date}
    end
  end
end
