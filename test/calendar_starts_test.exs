defmodule Calendrical.Starts.Test do
  use ExUnit.Case, async: true

  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  # A year that begins on a weekday on or before 7 February begins on the
  # last such weekday of the month's first seven days.
  test "the first gregorian day of year for a year that begins on each day of the week" do
    days = %{
      {2019, 2, 7} => 4,
      {2019, 2, 1} => 5,
      {2019, 2, 2} => 6,
      {2019, 2, 3} => 7,
      {2019, 2, 4} => 1,
      {2019, 2, 5} => 2,
      {2019, 2, 6} => 3,
      {2000, 2, 6} => 7,
      {2000, 2, 7} => 1,
      {2000, 2, 1} => 2,
      {2000, 2, 2} => 3,
      {2000, 2, 3} => 4,
      {2000, 2, 4} => 5,
      {2000, 2, 5} => 6,
      {1954, 2, 7} => 7,
      {1954, 2, 1} => 1,
      {1954, 2, 2} => 2,
      {1954, 2, 3} => 3,
      {1954, 2, 4} => 4,
      {1954, 2, 5} => 5,
      {1954, 2, 6} => 6,
      {1949, 2, 7} => 1,
      {1949, 2, 1} => 2,
      {1949, 2, 2} => 3,
      {1949, 2, 3} => 4,
      {1949, 2, 4} => 5,
      {1949, 2, 5} => 6,
      {1949, 2, 6} => 7
    }

    for {expected_date, day_of_week} <- days do
      weekday = Enum.at(@weekdays, day_of_week - 1)
      name = Module.concat([__MODULE__, "BeginsFebruary#{weekday}"])

      {:ok, calendar} =
        Calendrical.new(name, :week, year_begins: {weekday, :on_or_before, {2, 7}})

      {year, _, _} = expected_date
      first_day = calendar.first_gregorian_day_of_year(year)
      assert Calendar.ISO.date_from_iso_days(first_day) == expected_date
    end
  end
end
