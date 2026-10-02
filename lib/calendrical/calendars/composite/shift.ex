defmodule Calendrical.Composite.Shift do
  @moduledoc false

  # The months a shift of years and months moves a month by, as a member
  # calendar of a composite counts them: twelve a year in a calendar of
  # twelve months, thirteen in one of thirteen, and through the leap months
  # of a lunisolar calendar's years.
  #
  # They are counted from the first of the month in the member calendar,
  # which is a date of it whatever days of the month the composite has: a
  # change of calendar can begin a month part of the way through. A member
  # that has no first of the month is a composite itself, and its years are
  # taken as twelve months.

  @doc false
  def months(calendar, year, month, %Duration{} = duration) do
    if calendar.valid_date?(year, month, 1) do
      calendar.diff({year, month, 1}, calendar.shift_date(year, month, 1, duration), :months)
    else
      duration.year * 12 + duration.month
    end
  end

  # The months `plus/6` walks for a count of years, or of months.
  @doc false
  def months(calendar, year, month, :years, years) do
    months(calendar, year, month, Duration.new!(year: years))
  end

  def months(_calendar, _year, _month, :months, months) do
    months
  end
end
