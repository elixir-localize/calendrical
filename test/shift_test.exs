if Code.ensure_loaded?(Calendar.ISO) && function_exported?(Calendar.ISO, :shift_date, 4) do
  defmodule Calendrical.ShiftTest do
    use ExUnit.Case, async: true

    # Implements the same tests as for Calendar.ISO but using Calendrical.Gregorian

    test "shift_date/2" do
      assert Calendrical.Gregorian.shift_date(2024, 3, 2, Duration.new!([])) == {2024, 3, 2}

      assert Calendrical.Gregorian.shift_date(2024, 3, 2, Duration.new!(year: 1)) ==
               {2025, 3, 2}

      assert Calendrical.Gregorian.shift_date(2024, 3, 2, Duration.new!(month: 2)) ==
               {2024, 5, 2}

      assert Calendrical.Gregorian.shift_date(2024, 3, 2, Duration.new!(week: 3)) ==
               {2024, 3, 23}

      assert Calendrical.Gregorian.shift_date(2024, 3, 2, Duration.new!(day: 5)) == {2024, 3, 7}

      assert Calendrical.Gregorian.shift_date(0, 1, 1, Duration.new!(month: 1)) == {0, 2, 1}
      assert Calendrical.Gregorian.shift_date(0, 1, 1, Duration.new!(year: 1)) == {1, 1, 1}

      assert Calendrical.Gregorian.shift_date(0, 1, 1, Duration.new!(year: -2, month: 2)) ==
               {-2, 3, 1}

      assert Calendrical.Gregorian.shift_date(-4, 1, 1, Duration.new!(year: -1)) == {-5, 1, 1}

      assert Calendrical.Gregorian.shift_date(
               2024,
               3,
               2,
               Duration.new!(year: 1, month: 2, week: 3, day: 5)
             ) ==
               {2025, 5, 28}

      assert Calendrical.Gregorian.shift_date(
               2024,
               3,
               2,
               Duration.new!(year: -1, month: -2, week: -3)
             ) ==
               {2022, 12, 12}

      assert Calendrical.Gregorian.shift_date(2020, 2, 28, Duration.new!(day: 1)) ==
               {2020, 2, 29}

      assert Calendrical.Gregorian.shift_date(2020, 2, 29, Duration.new!(year: 1)) ==
               {2021, 2, 28}

      assert Calendrical.Gregorian.shift_date(2024, 3, 31, Duration.new!(month: -1)) ==
               {2024, 2, 29}

      assert Calendrical.Gregorian.shift_date(2024, 3, 31, Duration.new!(month: -2)) ==
               {2024, 1, 31}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 1)) ==
               {2024, 2, 29}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 2)) ==
               {2024, 3, 31}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 3)) ==
               {2024, 4, 30}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 4)) ==
               {2024, 5, 31}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 5)) ==
               {2024, 6, 30}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 6)) ==
               {2024, 7, 31}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 7)) ==
               {2024, 8, 31}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 8)) ==
               {2024, 9, 30}

      assert Calendrical.Gregorian.shift_date(2024, 1, 31, Duration.new!(month: 9)) ==
               {2024, 10, 31}
    end

    test "shift_datetime/2" do
      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian], year: 1) ==
               ~U[2001-01-01 00:00:00Z]

      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian], month: 1) ==
               ~U[2000-02-01 00:00:00Z]

      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian], month: 1, day: 28) ==
               ~U[2000-02-29 00:00:00Z]

      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian], month: 1, day: 30) ==
               ~U[2000-03-02 00:00:00Z]

      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian], month: 2, day: 29) ==
               ~U[2000-03-30 00:00:00Z]

      assert DateTime.shift(~U[2000-01-01 00:00:00Z Calendrical.Gregorian],
               microsecond: {4000, 4}
             ) ==
               ~U[2000-01-01 00:00:00.0040Z]

      assert DateTime.shift(~U[2000-02-29 00:00:00Z Calendrical.Gregorian], year: -1) ==
               ~U[1999-02-28 00:00:00Z]

      assert DateTime.shift(~U[2000-02-29 00:00:00Z Calendrical.Gregorian], month: -1) ==
               ~U[2000-01-29 00:00:00Z]

      assert DateTime.shift(~U[2000-02-29 00:00:00Z Calendrical.Gregorian], month: -1, day: -28) ==
               ~U[2000-01-01 00:00:00Z]

      assert DateTime.shift(~U[2000-02-29 00:00:00Z Calendrical.Gregorian], month: -1, day: -30) ==
               ~U[1999-12-30 00:00:00Z]

      assert DateTime.shift(~U[2000-02-29 00:00:00Z Calendrical.Gregorian], month: -1, day: -29) ==
               ~U[1999-12-31 00:00:00Z]
    end

    # Years and months are added together and the day brought into the month
    # reached once, as Calendar.ISO adds them: 29 February 2024 and a year and
    # a month is 29 March 2025, where bringing the day into February 2025 on
    # the way would make it the 28th.
    test "years and months bring the day into the month reached once" do
      assert Calendrical.Gregorian.shift_date(2024, 2, 29, Duration.new!(year: 1, month: 1)) ==
               {2025, 3, 29}

      assert Calendrical.Gregorian.shift_date(2024, 2, 29, Duration.new!(year: -1, month: 1)) ==
               {2023, 3, 29}

      assert Calendrical.Gregorian.shift_naive_datetime(
               2024,
               2,
               29,
               23,
               30,
               0,
               {0, 0},
               Duration.new!(year: 1, month: 1, hour: 1)
             ) == {2025, 3, 30, 0, 30, 0, {0, 0}}
    end

    # Calendar.ISO is the oracle: every day of 2023 to 2025, the leap day
    # among them, shifted by each duration of a grid lands where
    # Calendar.ISO lands it, as a date and as a date-time.
    test "every date shifts as Calendar.ISO shifts it" do
      dates = Enum.map(0..1095, &Date.add(~D[2023-01-01], &1))

      durations =
        for year <- [-1, 0, 1],
            month <- [-13, -1, 0, 1, 13],
            week <- [0, -1],
            day <- [0, 1, 30] do
          Duration.new!(year: year, month: month, week: week, day: day)
        end

      for date <- dates, duration <- durations do
        assert Calendrical.Gregorian.shift_date(date.year, date.month, date.day, duration) ==
                 Calendar.ISO.shift_date(date.year, date.month, date.day, duration),
               "#{inspect(date)} + #{inspect(duration)}"
      end

      time_durations =
        for month <- [0, 13], day <- [0, -1], hour <- [0, -30], second <- [0, 3601] do
          Duration.new!(
            year: 1,
            month: month,
            day: day,
            hour: hour,
            second: second,
            microsecond: {250, 6}
          )
        end

      for date <- dates, date.day >= 27, duration <- time_durations do
        {year, month, day} = {date.year, date.month, date.day}

        assert Calendrical.Gregorian.shift_naive_datetime(
                 year,
                 month,
                 day,
                 23,
                 30,
                 15,
                 {5, 6},
                 duration
               ) ==
                 Calendar.ISO.shift_naive_datetime(year, month, day, 23, 30, 15, {5, 6}, duration),
               "#{inspect(date)} 23:30:15 + #{inspect(duration)}"
      end
    end
  end
end
