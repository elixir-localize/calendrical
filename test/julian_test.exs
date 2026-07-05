defmodule Calendrical.JulianTest do
  @moduledoc """
  Tests for `Calendrical.Julian` — the proleptic Julian calendar.

  Anchors are chosen to distinguish Julian from Gregorian rules:
  century years such as 1900 and 2100 are Julian leap years but not
  Gregorian ones, and the two calendars are offset by 13 days in the
  20th–22nd centuries.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Julian

  describe "conversions" do
    test "Gregorian and Julian differ by 13 days in the current era" do
      assert Date.convert(~D[2026-07-05], Julian) == {:ok, ~D[2026-06-22 Calendrical.Julian]}

      assert Date.convert(~D[2026-06-22 Calendrical.Julian], Calendar.ISO) ==
               {:ok, ~D[2026-07-05]}
    end

    test "round-trips across a wide year range including BCE" do
      for year <- [-500, -1, 1, 1000, 1582, 2026], month <- [1, 6, 12] do
        {:ok, date} = Date.new(year, month, 15, Julian)
        {:ok, iso} = Date.convert(date, Calendar.ISO)
        assert {:ok, ^date} = Date.convert(iso, Julian)
      end
    end

    test "year zero is invalid" do
      refute Julian.valid_date?(0, 1, 1)
      assert Julian.valid_date?(-1, 1, 1)
      assert Julian.valid_date?(1, 1, 1)
    end
  end

  describe "leap years (every fourth year, including century years)" do
    test "century years divisible by 4 are leap years" do
      assert Julian.leap_year?(1900)
      assert Julian.leap_year?(2100)
      refute Calendar.ISO.leap_year?(1900)
    end

    test "ordinary leap cycle" do
      assert Julian.leap_year?(2024)
      refute Julian.leap_year?(2026)
    end

    test "days_in_month and days_in_year follow the leap rule" do
      assert Julian.days_in_month(2100, 2) == 29
      assert Julian.days_in_month(2026, 2) == 28
      assert Julian.days_in_year(2100) == 366
      assert Julian.days_in_year(2026) == 365
    end

    test "February 29 validity follows the Julian rule" do
      assert Julian.valid_date?(1900, 2, 29)
      refute Julian.valid_date?(2026, 2, 29)
    end
  end

  describe "eras and derived years" do
    test "CE years are era 1, BCE years count backwards in era 0" do
      assert Julian.year_of_era(2026, 6, 22) == {2026, 1}
      assert Julian.year_of_era(-100, 1, 1) == {100, 0}
    end

    test "related_gregorian_year crosses the year boundary correctly" do
      # Julian Christmas 2026 falls on Gregorian 2027-01-07.
      assert Julian.related_gregorian_year(2026, 12, 25) == 2027
      assert Julian.related_gregorian_year(2026, 6, 22) == 2026
    end

    test "day_of_era counts from the epoch in both eras" do
      assert Julian.day_of_era(1, 1, 1) == {1, 1}
      assert Julian.day_of_era(1, 1, 3) == {3, 1}
      # BCE counts backwards from the day before the epoch.
      assert Julian.day_of_era(-1, 12, 31) == {1, 0}
      assert {day, 1} = Julian.day_of_era(2026, 6, 22)
      assert day > 700_000
    end
  end

  describe "periods" do
    test "quarter_of_year and month_of_year" do
      assert Julian.quarter_of_year(2026, 6, 22) == 2
      assert Julian.month_of_year(2026, 6, 22) == 6
    end

    test "weeks are not defined for the Julian calendar" do
      assert Julian.week_of_year(2026, 6, 22) == {:error, :not_defined}
      assert Julian.iso_week_of_year(2026, 6, 22) == {:error, :not_defined}
      assert Julian.week_of_month(2026, 6, 22) == {:error, :not_defined}
      assert Julian.week(2026, 2) == {:error, :not_defined}
      assert Julian.weeks_in_year(2026) == {:error, :not_defined}
    end

    test "year, quarter and month ranges" do
      assert Julian.year(2026) ==
               Date.range(~D[2026-01-01 Calendrical.Julian], ~D[2026-12-31 Calendrical.Julian])

      assert Julian.quarter(2026, 2) ==
               Date.range(~D[2026-04-01 Calendrical.Julian], ~D[2026-06-30 Calendrical.Julian])

      assert Julian.month(2026, 2) ==
               Date.range(~D[2026-02-01 Calendrical.Julian], ~D[2026-02-28 Calendrical.Julian])
    end
  end

  describe "arithmetic" do
    test "plus with coercion clamps to the end of the month" do
      assert Julian.plus(2024, 2, 29, :years, 1, coerce: true) == {2025, 2, 28}
      assert Julian.plus(2026, 1, 31, :months, 1, coerce: true) == {2026, 2, 28}
      assert Julian.plus(2026, 1, 15, :quarters, 2, coerce: true) == {2026, 7, 15}
    end

    test "plus days crosses month and year boundaries" do
      assert Julian.plus(2026, 12, 30, :days, 5, []) == {2027, 1, 4}
    end

    test "Date.shift clamps year and month shifts like Calendar.ISO" do
      assert Date.shift(~D[2026-01-31 Calendrical.Julian], month: 1) ==
               ~D[2026-02-28 Calendrical.Julian]

      assert Date.shift(~D[2024-02-29 Calendrical.Julian], year: 1) ==
               ~D[2025-02-28 Calendrical.Julian]
    end

    test "NaiveDateTime.shift clamps the date part" do
      shifted = NaiveDateTime.shift(~N[2026-01-31 10:30:00 Calendrical.Julian], month: 1)
      assert {shifted.year, shifted.month, shifted.day} == {2026, 2, 28}
      assert {shifted.hour, shifted.minute} == {10, 30}
    end
  end

  describe "weekdays" do
    test "day_of_week matches the equivalent Gregorian date" do
      {:ok, julian} = Date.convert(~D[2026-07-05], Julian)
      # 2026-07-05 is a Sunday.
      assert {7, 1, 7} = Julian.day_of_week(julian.year, julian.month, julian.day, :default)
    end
  end
end
