defmodule Calendrical.Ends.Test do
  use ExUnit.Case, async: true

  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  # A year that ends on a weekday on or after 25 July ends on the first such
  # weekday of the month's last seven days.
  test "the last gregorian day of year for a year that ends on each day of the week" do
    days = %{
      {2019, 7, 25} => 4,
      {2019, 7, 26} => 5,
      {2019, 7, 27} => 6,
      {2019, 7, 28} => 7,
      {2019, 7, 29} => 1,
      {2019, 7, 30} => 2,
      {2019, 7, 31} => 3,
      {2000, 7, 27} => 4,
      {2000, 7, 28} => 5,
      {2000, 7, 29} => 6,
      {2000, 7, 30} => 7,
      {2000, 7, 31} => 1,
      {2000, 7, 25} => 2,
      {2000, 7, 26} => 3,
      {1954, 7, 25} => 7,
      {1954, 7, 26} => 1,
      {1954, 7, 27} => 2,
      {1954, 7, 28} => 3,
      {1954, 7, 29} => 4,
      {1954, 7, 30} => 5,
      {1954, 7, 31} => 6,
      {1949, 7, 25} => 1,
      {1949, 7, 26} => 2,
      {1949, 7, 27} => 3,
      {1949, 7, 28} => 4,
      {1949, 7, 29} => 5,
      {1949, 7, 30} => 6,
      {1949, 7, 31} => 7
    }

    for {expected_date, day_of_week} <- days do
      weekday = Enum.at(@weekdays, day_of_week - 1)
      name = Module.concat([__MODULE__, "EndsJuly#{weekday}"])

      {:ok, calendar} =
        Calendrical.new(name, :week,
          year_ends: {weekday, :on_or_after, {7, 25}},
          year_number: :ending
        )

      {year, _, _} = expected_date
      last_day = calendar.last_gregorian_day_of_year(year)
      assert Calendar.ISO.date_from_iso_days(last_day) == expected_date
    end
  end

  # Examples from https://en.wikipedia.org/wiki/4–4–5_calendar
  test "the last gregorian day of year for last Saturday in August" do
    days = [
      {2014, 8, 30},
      {2015, 8, 29},
      {2016, 8, 27},
      {2017, 8, 26},
      {2018, 8, 25},
      {2019, 8, 31},
      {2020, 8, 29},
      {2021, 8, 28},
      {2022, 8, 27},
      {2023, 8, 26},
      {2024, 8, 31},
      {2025, 8, 30},
      {2026, 8, 29},
      {2027, 8, 28},
      {2028, 8, 26},
      {2029, 8, 25}
    ]

    {:ok, calendar} =
      Calendrical.new(__MODULE__.LastSaturdayOfAugust, :week,
        year_ends: {:saturday, :on_or_after, {8, 25}}
      )

    for {year, _, _} = date <- days do
      last_day = calendar.last_gregorian_day_of_year(year)
      assert Calendar.ISO.date_from_iso_days(last_day) == date
    end
  end

  test "a year that ends by its rule begins the day after the year before ends" do
    days = %{
      2019 => {2018, 7, 29},
      2000 => {1999, 8, 1}
    }

    {:ok, calendar} =
      Calendrical.new(__MODULE__.EndsJulyEnding, :week,
        year_ends: {:saturday, :on_or_after, {7, 25}},
        year_number: :ending
      )

    for {year, date} <- days do
      first_day = calendar.first_gregorian_day_of_year(year)
      assert Calendar.ISO.date_from_iso_days(first_day) == date
    end
  end
end
