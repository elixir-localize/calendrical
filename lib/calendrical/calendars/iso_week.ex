defmodule Calendrical.ISOWeek do
  @moduledoc """
  Implements the ISO Week calendar.

  A year of the ISO Week calendar has 52 or 53 whole weeks, each from
  Monday, and week 1 is the week that holds the year's fourth day. Its
  dates are a year, a month and a day of the month, as the dates of any
  calendar are: the months are the twelve of a 4-5-4 pattern of weeks,
  of 28 or 35 days. The week of a date is asked for
  (`Calendrical.week_of_year/1`, `week_date_from_date/3`), and a week
  date is read as the date it names (`date_from_week_date/3`, and
  `~D[2026-W25-2 Calendrical.ISOWeek]` is `~D[2026-06-16 Calendrical.ISOWeek]`).

  """
  use Calendrical.Calendar.Weeks, year_begins: {:monday, :on_or_before, {1, 4}}
end
