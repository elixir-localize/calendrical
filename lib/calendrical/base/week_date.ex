defmodule Calendrical.Base.WeekDate do
  @moduledoc false

  # Week dates of a calendar of months: its own weeks, as `week_of_year/3`
  # and `week/2` count them, with each day numbered as `day_of_week/4`
  # numbers it from the day the calendar's weeks begin on. Week 1 of a year
  # is the week that holds the year's first day, so a year that opens
  # mid-week has a short week 1, and every date is of its own year's weeks.
  # A year, a month, a week, a day and a day of the week are all the
  # calendar's own, as RFC 7529 reads a rule's weeks and days of the week as
  # its calendar's (decided 2026-10-16). ISO 8601's week dates are those of
  # `Calendar.ISO` and of `Calendrical.ISOWeek`.
  #
  # `iso_week_of_year/3` is another question, the week of the Gregorian year
  # a day is in, whichever calendar names the day.
  #
  # A calendar of weeks has week dates of its own, counted in the weeks it
  # is built of.

  # The date of a day of a week of a week-year: the day of the calendar week
  # numbered as the calendar numbers it, where the week, cut to its year,
  # has that day.
  def date_from_week_date(calendar, week_year, week, day)
      when is_integer(week_year) and is_integer(week) and week >= 1 and is_integer(day) and
             day >= 1 do
    case calendar.week(week_year, week) do
      %Date.Range{} = days ->
        Enum.find(days, {:error, :invalid_date}, &(day_of_week(calendar, &1) == day))

      _no_such_week ->
        {:error, :invalid_date}
    end
  end

  def date_from_week_date(_calendar, _week_year, _week, _day) do
    {:error, :invalid_date}
  end

  # The week-year, the week and the day of the week of a date.
  def week_date_from_date(calendar, year, month, day) do
    with true <- calendar.valid_date?(year, month, day),
         {week_year, week} when is_integer(week) <- calendar.week_of_year(year, month, day) do
      {week_year, week, day_of_week(calendar, %Date{year: year, month: month, day: day})}
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  # How many weeks a week-year has: as many as its year.
  def weeks_in_week_year(calendar, week_year) when is_integer(week_year) do
    weeks_in_own_year(calendar, week_year)
  end

  def weeks_in_week_year(_calendar, _week_year) do
    {:error, :invalid_date}
  end

  # A calendar's weeks in a year, as a count or as the pair an older
  # calendar answers with.
  def weeks_in_own_year(calendar, year) do
    case calendar.weeks_in_year(year) do
      {weeks, _days_in_last_week} when is_integer(weeks) -> weeks
      _no_such_year -> {:error, :invalid_date}
    end
  end

  defp day_of_week(calendar, %Date{year: year, month: month, day: day}) do
    {day_of_week, _first, _last} = calendar.day_of_week(year, month, day, :default)
    day_of_week
  end
end
