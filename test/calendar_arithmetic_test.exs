defmodule Calendrical.CalendarArithmetic.Test do
  use ExUnit.Case, async: true

  alias Calendrical.{Chinese, Hebrew, Korean, LunarJapanese, Vietnamese}

  describe "week-based calendars" do
    test "the days of the year are numbered from 1 to the length of the year" do
      for {calendar, year} <- [
            {Calendrical.ISOWeek, 2024},
            {Calendrical.ISOWeek, 2020},
            {Calendrical.NRF, 2023}
          ] do
        %Date.Range{} = range = Calendrical.Interval.year(year, calendar)
        days = Enum.map(range, &calendar.day_of_year(&1.year, &1.month, &1.day))
        assert days == Enum.to_list(1..calendar.days_in_year(year))
      end
    end
  end

  describe "lunisolar months and years" do
    test "a month shift walks each year's own months" do
      # Y4660 has 13 months, Y4661 has 12
      assert Chinese.plus(4660, 13, 1, :months, 13) == {4662, 1, 1}
      assert Chinese.plus(4661, 12, 1, :months, 1) == {4662, 1, 1}
      assert Chinese.plus(4662, 1, 1, :months, -13) == {4660, 13, 1}

      assert Date.shift(~D[4660-13-01 Calendrical.Chinese], month: 13) ==
               ~D[4662-01-01 Calendrical.Chinese]
    end

    test "a year shift keeps the traditional month" do
      for calendar <- [Chinese, Korean, Vietnamese, LunarJapanese] do
        mid_autumn_2023 = Date.convert!(~D[2023-09-29], calendar)
        mid_autumn_2024 = Date.convert!(~D[2024-09-17], calendar)

        assert Date.shift(mid_autumn_2023, year: 1) == mid_autumn_2024
        assert Date.shift(mid_autumn_2024, year: -1) == mid_autumn_2023
      end
    end

    test "a leap month the new year lacks becomes the ordinary month of its number" do
      # Y4660 (= AD 2023) has a leap 2nd month at ordinal 3; Y4661 has none
      assert Chinese.plus(4660, 3, 10, :years, 1) == {4661, 2, 10}
    end
  end

  describe "Hebrew months and years" do
    test "a month shift passes over Adar I in an ordinary year" do
      assert Hebrew.plus(5785, 5, 1, :months, 1) == {5785, 7, 1}
      assert Hebrew.plus(5785, 7, 1, :months, -1) == {5785, 5, 1}
      assert Hebrew.plus(5784, 5, 1, :months, 1) == {5784, 6, 1}
      assert Hebrew.plus(5784, 6, 1, :months, 13) == {5785, 7, 1}
    end

    test "a long month shift is exact over whole Metonic cycles" do
      assert Hebrew.plus(5784, 6, 1, :months, 235) == {5803, 6, 1}
      assert Hebrew.plus(5803, 6, 1, :months, -235) == {5784, 6, 1}
    end

    test "a year shift keeps the month, Adar I becoming Adar in an ordinary year" do
      assert Hebrew.plus(5784, 13, 1, :years, 1) == {5785, 13, 1}
      assert Hebrew.plus(5784, 6, 10, :years, 1) == {5785, 7, 10}
      assert Hebrew.plus(5784, 7, 10, :years, 1) == {5785, 7, 10}
    end

    test "every shifted date is a Hebrew date" do
      for month <- [1, 5, 6, 7, 12, 13], shift <- [-14, -13, -1, 1, 12, 13, 14] do
        date = Date.new!(5784, month, 29, Hebrew)
        shifted = Date.shift(date, month: shift)
        assert Hebrew.valid_date?(shifted.year, shifted.month, shifted.day)
      end
    end

    test "a year runs from 1 Tishri to the end of Elul" do
      assert Hebrew.year(5785) ==
               Date.range(~D[5785-01-01 Calendrical.Hebrew], ~D[5785-13-29 Calendrical.Hebrew])

      assert Enum.count(Hebrew.year(5785)) == Hebrew.days_in_year(5785)
    end

    test "the month of Adar II is found by its interval" do
      assert Calendrical.Interval.month(~D[5784-07-10 Calendrical.Hebrew]) ==
               Date.range(~D[5784-07-01 Calendrical.Hebrew], ~D[5784-07-29 Calendrical.Hebrew])
    end
  end

  describe "tabular Islamic dates before the Hijra" do
    test "convert to a valid date with positive month and day" do
      for calendar <- [Calendrical.Islamic.Civil, Calendrical.Islamic.Tbla] do
        date = Date.convert!(~D[0001-06-01], calendar)
        assert calendar.valid_date?(date.year, date.month, date.day)
        assert Date.convert!(date, Calendar.ISO) == ~D[0001-06-01]
      end
    end

    test "round trip across the epoch" do
      epoch = Calendrical.Islamic.Civil.date_to_iso_days(1, 1, 1)

      for iso_days <- (epoch - 800)..(epoch + 30) do
        {year, month, day} = Calendrical.Islamic.Civil.date_from_iso_days(iso_days)
        assert month in 1..12 and day in 1..30
        assert Calendrical.Islamic.Civil.date_to_iso_days(year, month, day) == iso_days
      end
    end
  end

  describe "calendars with a limited range" do
    test "a date outside the range is not valid rather than an exception" do
      refute Calendrical.Persian.valid_date?(3000, 1, 1)
      refute Calendrical.Islamic.Observational.valid_date?(5000, 1, 1)
      refute Calendrical.Islamic.Rgsa.valid_date?(5000, 1, 1)
      assert {:error, :invalid_date} = Date.new(3000, 1, 1, Calendrical.Persian)
      assert {:error, :invalid_date} = Date.new(5000, 1, 1, Calendrical.Islamic.Observational)
    end

    test "the Persian range is Persian years 380 to 2378" do
      assert Calendrical.Persian.valid_date?(380, 1, 1)
      assert Calendrical.Persian.valid_date?(2378, 12, 29)
      refute Calendrical.Persian.valid_date?(379, 12, 29)
      refute Calendrical.Persian.valid_date?(2379, 1, 1)
    end
  end

  describe "Julian new-year variants" do
    test "label years skip year 0, as the Julian calendar does" do
      for calendar <- [
            Calendrical.Julian.Dec25,
            Calendrical.Julian.Sept1,
            Calendrical.Julian.March25
          ] do
        for iso_days <- -800..800 do
          {year, month, day} = calendar.date_from_iso_days(iso_days)
          assert year != 0
          assert calendar.date_to_iso_days(year, month, day) == iso_days
        end

        assert {:error, :invalid_date} = calendar.year(0)
        assert %Date.Range{} = calendar.year(-1)
      end
    end

    test "a date-time month shift is the date's month shift" do
      {:ok, date_time} =
        NaiveDateTime.new(2023, 12, 31, 10, 30, 0, {0, 0}, Calendrical.Julian.March25)

      shifted = NaiveDateTime.shift(date_time, month: 1)

      assert NaiveDateTime.to_date(shifted) ==
               Date.shift(NaiveDateTime.to_date(date_time), month: 1)

      assert NaiveDateTime.to_date(shifted) == ~D[2023-01-31 Calendrical.Julian.March25]
    end
  end
end
