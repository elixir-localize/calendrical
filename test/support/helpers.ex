defmodule Calendrical.Helper do
  def date(year, month, day, calendar) do
    {:ok, date} = Date.new(year, month, day, calendar)
    date
  end

  # The date of a day of a week of a year, as the calendar counts its week
  # dates: a test of a week names the week, where the date holds a month
  # and a day of it.
  def week_date(year, week, day, calendar) do
    %Date{} = date = calendar.date_from_week_date(year, week, day)
    date
  end
end
