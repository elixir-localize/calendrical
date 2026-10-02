defmodule Calendrical.Reform.SwedenTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Reform.Sweden
  doctest Calendrical.Reform.Sweden.Transitional

  alias Calendrical.{Gregorian, Julian}
  alias Calendrical.Reform.Sweden

  describe "1700 — the dropped leap day" do
    test "there is no 29 February 1700" do
      refute Sweden.valid_date?(1700, 2, 29)
    end

    test "28 February 1700 is followed by 1 March 1700" do
      day_before = ~D[1700-02-28 Calendrical.Reform.Sweden]
      assert Date.shift(day_before, day: 1) == ~D[1700-03-01 Calendrical.Reform.Sweden]
    end

    test "1 March 1700 is the physical day the Julian calendar calls 29 February 1700" do
      assert Date.convert!(~D[1700-03-01 Calendrical.Reform.Sweden], Julian) ==
               ~D[1700-02-29 Calendrical.Julian]
    end
  end

  describe "1712 — the 30 February" do
    test "30 February 1712 is a valid date" do
      assert Sweden.valid_date?(1712, 2, 30)
    end

    test "February 1712 has 30 days and 1712 has 367 days" do
      assert Sweden.days_in_month(1712, 2) == 30
      assert Sweden.days_in_year(1712) == 367
    end

    test "29 February 1712 is followed by 30 February then 1 March" do
      feb_29 = ~D[1712-02-29 Calendrical.Reform.Sweden]
      feb_30 = Date.shift(feb_29, day: 1)
      assert feb_30 == ~D[1712-02-30 Calendrical.Reform.Sweden]
      assert Date.shift(feb_30, day: 1) == ~D[1712-03-01 Calendrical.Reform.Sweden]
    end

    test "30 February 1712 is the physical day the Julian calendar calls 29 February 1712" do
      assert Date.convert!(~D[1712-02-30 Calendrical.Reform.Sweden], Julian) ==
               ~D[1712-02-29 Calendrical.Julian]
    end
  end

  describe "1753 — the Gregorian adoption" do
    test "11 days are missing across the transition" do
      day_before = ~D[1753-02-17 Calendrical.Reform.Sweden]
      assert Date.shift(day_before, day: 1) == ~D[1753-03-01 Calendrical.Reform.Sweden]
    end

    test "18-28 February 1753 are not valid dates" do
      for d <- 18..28 do
        refute Sweden.valid_date?(1753, 2, d), "expected #{d} Feb 1753 to be invalid"
      end
    end

    test "after 1753 the Gregorian leap rule applies" do
      # 1800 is not a Gregorian leap year
      refute Sweden.valid_date?(1800, 2, 29)
    end
  end

  describe "round-trips across every segment" do
    test "Sweden -> Gregorian -> Sweden is stable in each era" do
      for date <- [
            ~D[1699-06-15 Calendrical.Reform.Sweden],
            ~D[1705-06-15 Calendrical.Reform.Sweden],
            ~D[1730-06-15 Calendrical.Reform.Sweden],
            ~D[1800-06-15 Calendrical.Reform.Sweden]
          ] do
        assert date |> Date.convert!(Gregorian) |> Date.convert!(Sweden) == date
      end
    end
  end

  describe "the transitional calendar on its own" do
    alias Calendrical.Reform.Sweden.Transitional

    test "every day from 1690 to 1730 round-trips, and outside the window is Julian" do
      first = Date.to_gregorian_days(~D[1690-01-01])
      last = Date.to_gregorian_days(~D[1730-12-31])

      for iso_days <- first..last do
        {year, month, day} = Transitional.date_from_iso_days(iso_days)
        assert Transitional.date_to_iso_days(year, month, day) == iso_days
      end

      assert Transitional.date_from_iso_days(Date.to_gregorian_days(~D[2025-06-15])) ==
               Calendrical.Julian.date_from_iso_days(Date.to_gregorian_days(~D[2025-06-15]))
    end

    test "February 1700 lost its leap day and February 1712 has thirty days" do
      assert Transitional.days_in_month(1700, 2) == 28
      refute Transitional.leap_year?(1700)
      assert Transitional.days_in_month(1712, 2) == 30
      assert Transitional.days_in_month(1699, 2) == 28
    end

    test "1700 has 365 days, 1712 has 367 and the years between are Julian" do
      assert Transitional.days_in_year(1700) == 365
      assert Transitional.days_in_year(1704) == 366
      assert Transitional.days_in_year(1711) == 365
      assert Transitional.days_in_year(1712) == 367
    end
  end

  # Outside 1 March 1700 to 30 February 1712 the transitional calendar is the
  # Julian calendar, which has no year 0: every answer about a date there is
  # `Calendrical.Julian`'s, an implementation of its own.
  describe "the transitional calendar around AD 1, where there is no year 0" do
    alias Calendrical.Reform.Sweden.Transitional

    @date_callbacks [
      valid_date?: 3,
      day_of_year: 3,
      day_of_era: 3,
      year_of_era: 3,
      quarter_of_year: 3,
      month_of_year: 3,
      week_of_year: 3,
      iso_week_of_year: 3,
      week_of_month: 3,
      calendar_year: 3,
      extended_year: 3,
      related_gregorian_year: 3,
      cyclic_year: 3
    ]

    @year_callbacks [:leap_year?, :months_in_year, :days_in_year, :weeks_in_year, :year]

    @years [-5, -4, -3, -2, -1, 1, 2, 3, 4, 5]

    test "there is no year 0, and 31 December 1 BC is the day before 1 January AD 1" do
      refute Transitional.valid_date?(0, 1, 1)
      refute Transitional.valid_date?(0, 12, 31)
      assert Transitional.valid_date?(-1, 12, 31)
      assert Transitional.valid_date?(-1, 12, 8)
      assert {:error, :invalid_date} = Date.new(0, 6, 15, Transitional)

      last_day = Date.new!(-1, 12, 31, Transitional)
      assert Date.shift(last_day, day: 1) == Date.new!(1, 1, 1, Transitional)
      assert Date.diff(Date.new!(1, 1, 1, Transitional), last_day) == 1

      # ISO 0000-12-06 is 8 December 1 BC in the Julian calendar.
      assert Date.convert!(~D[0000-12-06], Transitional) == Date.new!(-1, 12, 8, Transitional)
    end

    test "every date callback answers as the Julian calendar's for every day of 5 BC to AD 5" do
      first = Julian.date_to_iso_days(-5, 1, 1)
      last = Julian.date_to_iso_days(5, 12, 31)

      for iso_days <- first..last do
        {year, month, day} = Julian.date_from_iso_days(iso_days)
        assert Transitional.date_from_iso_days(iso_days) == {year, month, day}

        for {callback, 3} <- @date_callbacks do
          assert apply(Transitional, callback, [year, month, day]) ==
                   apply(Julian, callback, [year, month, day]),
                 "#{callback} of #{inspect({year, month, day})}"
        end

        assert Transitional.day_of_week(year, month, day, :default) ==
                 Julian.day_of_week(year, month, day, :default)
      end
    end

    test "its years and months are the Julian calendar's" do
      for year <- @years do
        for callback <- @year_callbacks do
          assert labels(apply(Transitional, callback, [year])) ==
                   labels(apply(Julian, callback, [year])),
                 "#{callback} of #{year}"
        end

        for month <- 1..12 do
          assert Transitional.days_in_month(year, month) == Julian.days_in_month(year, month)
          assert labels(Transitional.month(year, month)) == labels(Julian.month(year, month))
        end

        for quarter <- 1..4 do
          assert labels(Transitional.quarter(year, quarter)) ==
                   labels(Julian.quarter(year, quarter))
        end
      end

      assert Transitional.days_in_year(-1) == 366
      assert Transitional.days_in_month(-1, 12) == 31
      assert labels(Transitional.year(-1)) == {{-1, 1, 1}, {-1, 12, 31}}
    end

    test "the years BC are era 0, counted back from 1 BC, and extend from 0 down" do
      assert Transitional.year_of_era(1) == {1, 1}
      assert Transitional.year_of_era(-1) == {1, 0}
      assert Transitional.year_of_era(-44, 3, 15) == {44, 0}

      assert Transitional.day_of_era(1, 1, 1) == {1, 1}
      assert Transitional.day_of_era(1, 1, 2) == {2, 1}
      assert Transitional.day_of_era(-1, 12, 31) == {1, 0}
      assert Transitional.day_of_era(-1, 12, 30) == {2, 0}

      assert Transitional.extended_year(1, 6, 15) == 1
      assert Transitional.extended_year(-1, 6, 15) == 0
      assert Transitional.extended_year(-2, 6, 15) == -1

      assert Date.year_of_era(Date.new!(-1, 6, 15, Transitional)) == {1, 0}
      assert Date.day_of_era(Date.new!(-1, 12, 31, Transitional)) == {1, 0}
    end

    # The days of an era count on by one each day through the window, where
    # they counted from the Gregorian calendar's first day, two days later.
    test "the days of the era run on through 1700 and 1712" do
      assert Transitional.day_of_era(1700, 2, 28) == Julian.day_of_era(1700, 2, 28)
      assert Transitional.day_of_era(1700, 3, 1) == Julian.day_of_era(1700, 2, 29)
      assert Transitional.day_of_era(1712, 2, 30) == Julian.day_of_era(1712, 2, 29)
      assert Transitional.day_of_era(1712, 3, 1) == Julian.day_of_era(1712, 3, 1)

      {before, 1} = Sweden.day_of_era(1700, 2, 28)
      assert Sweden.day_of_era(1700, 3, 1) == {before + 1, 1}

      {last, 1} = Sweden.day_of_era(1712, 2, 30)
      assert Sweden.day_of_era(1712, 3, 1) == {last + 1, 1}
    end

    test "years, quarters and months step over the missing year" do
      assert Transitional.plus(-2, 6, 3, :years, 2) == {1, 6, 3}
      assert Transitional.plus(-1, 6, 15, :years, 1) == {1, 6, 15}
      assert Transitional.plus(1, 6, 15, :years, -1) == {-1, 6, 15}
      assert Transitional.plus(3, 6, 15, :years, -5) == {-3, 6, 15}
      assert Transitional.plus(-1, 12, 31, :months, 1) == {1, 1, 31}
      assert Transitional.plus(1, 1, 31, :months, -1) == {-1, 12, 31}
      assert Transitional.plus(-1, 11, 15, :quarters, 1) == {1, 2, 15}
      assert Transitional.plus(-1, 12, 31, :days, 1) == {1, 1, 1}

      # 4 BC is no leap year in the proleptic Julian calendar and 5 BC is.
      assert Transitional.plus(-5, 2, 29, :years, 1, coerce: true) == {-4, 2, 28}

      assert Transitional.diff({-2, 6, 3}, {-1, 6, 3}, :years) == 1
      assert Transitional.diff({-1, 6, 1}, {1, 6, 1}, :years) == 1
      assert Transitional.diff({-1, 6, 1}, {1, 6, 1}, :months) == 12
      assert Transitional.diff({1, 6, 1}, {-1, 6, 1}, :years) == -1

      assert Date.shift(Date.new!(-1, 6, 15, Transitional), year: 1) ==
               Date.new!(1, 6, 15, Transitional)

      assert Date.shift(Date.new!(1, 1, 31, Transitional), month: -1) ==
               Date.new!(-1, 12, 31, Transitional)
    end

    test "plus/6 and diff/3 are the Julian calendar's from 5 BC to AD 5" do
      dates =
        for year <- @years,
            {month, day} <- [{1, 1}, {1, 31}, {2, 28}, {6, 15}, {12, 31}],
            do: {year, month, day}

      for {year, month, day} = from <- dates,
          part <- [:years, :quarters, :months, :weeks, :days],
          count <- [-30, -13, -12, -3, -1, 0, 1, 2, 12, 13, 30] do
        assert Transitional.plus(year, month, day, part, count, coerce: true) ==
                 Julian.plus(year, month, day, part, count, coerce: true),
               "#{inspect(from)} plus #{count} #{part}"
      end

      for from <- dates, to <- dates, part <- [:years, :months, :days] do
        assert Transitional.diff(from, to, part) == Julian.diff(from, to, part),
               "#{inspect(from)} to #{inspect(to)} in #{part}"
      end
    end

    # Within the window the calendar's own months are counted: a year after
    # 30 February 1712 is 28 February 1713, and a month before 30 March 1712
    # is 30 February.
    test "plus/6 brings a day into the months of 1700 and 1712" do
      assert Transitional.plus(1712, 2, 30, :years, 1, coerce: true) == {1713, 2, 28}
      assert Transitional.plus(1712, 3, 30, :months, -1, coerce: true) == {1712, 2, 30}
      assert Transitional.plus(1696, 2, 29, :years, 4, coerce: true) == {1700, 2, 28}
      assert Transitional.plus(1708, 2, 29, :years, 4, coerce: true) == {1712, 2, 29}
    end
  end

  # A range's dates by their fields, so one calendar's range can be compared
  # with another's.
  defp labels(%Date.Range{first: first, last: last}),
    do: {{first.year, first.month, first.day}, {last.year, last.month, last.day}}

  defp labels(other), do: other
end
