defmodule Calendrical.BeginsEnds.Test do
  use ExUnit.Case, async: true

  # A year of weeks numbered by `:majority` takes the Gregorian year that
  # holds seven or more of its months: a year begun in October is numbered
  # by the year it ends in, one begun in April by the year it begins in.
  defp gregorian_years(calendar, year) do
    first = Calendar.ISO.date_from_iso_days(calendar.first_gregorian_day_of_year(year))
    last = Calendar.ISO.date_from_iso_days(calendar.last_gregorian_day_of_year(year))
    {elem(first, 0), elem(last, 0)}
  end

  test "a year of weeks begun in October, as the US fiscal year is" do
    {:ok, calendar} =
      Calendrical.new(__MODULE__.October, :week, year_begins: {:monday, :on_or_before, {10, 1}})

    assert gregorian_years(calendar, 2019) == {2018, 2019}
  end

  test "a year of weeks begun in April, as the UK fiscal year is" do
    {:ok, calendar} =
      Calendrical.new(__MODULE__.April, :week, year_begins: {:monday, :on_or_before, {4, 1}})

    assert gregorian_years(calendar, 2019) == {2019, 2020}
  end
end
