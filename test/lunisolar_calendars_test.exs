defmodule Calendrical.LunisolarCalendarsTest do
  @moduledoc """
  Parametrized tests for the lunisolar calendar family: Chinese,
  Korean (dangi), and LunarJapanese.

  Anchors are real-world dates: lunar new years, the 2025 閏六月
  (intercalary sixth month), the Dragon Boat festival, and Chuseok.

  """

  use ExUnit.Case, async: true

  alias Calendrical.{Chinese, Korean, LunarJapanese}

  @calendars [Chinese, Korean, LunarJapanese]

  describe "lunar new year" do
    test "known Chinese New Year dates" do
      assert Chinese.new_year_for_gregorian_year(2024) == ~D[2024-02-10]
      assert Chinese.new_year_for_gregorian_year(2025) == ~D[2025-01-29]
      assert Chinese.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
    end

    test "all three calendars agree on the 2026 new year" do
      assert Korean.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
      assert LunarJapanese.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
    end

    test "the new year converts to month 1 day 1 in each calendar" do
      for calendar <- @calendars do
        new_year = calendar.new_year_for_gregorian_year(2026)
        {:ok, converted} = Date.convert(new_year, calendar)
        assert {converted.month, converted.day} == {1, 1}
      end
    end
  end

  describe "leap years and intercalary months" do
    test "the 2025 lunar year has an intercalary sixth month" do
      # CNY 2025-01-29 begins Chinese year 4662, which contains
      # 閏六月 (traditional leap month 6, ordinal position 7).
      assert Chinese.leap_year?(4662)
      assert Chinese.leap_month(4662) == 7
      assert Chinese.traditional_leap_month(4662) == 6
      assert Chinese.leap_month?(4662, 7)
    end

    test "the intercalary month resolves to its real-world date" do
      # 閏六月初一 was 2025-07-25.
      {:ok, date} = Chinese.new(4662, {6, :leap}, 1)
      assert date.month == 7
      assert Date.convert!(date, Calendar.ISO) == ~D[2025-07-25]
    end

    test "a non-intercalary month is rejected in leap notation" do
      assert Chinese.new(4662, {5, :leap}, 1) == {:error, :invalid_date}
    end

    test "ordinary years have twelve months, leap years thirteen" do
      for calendar <- @calendars do
        new_year = calendar.new_year_for_gregorian_year(2025)
        {:ok, %{year: leap_year}} = Date.convert(new_year, calendar)

        assert calendar.months_in_year(leap_year) == 13
        assert calendar.months_in_year(leap_year + 1) == 12
        assert calendar.leap_year?(leap_year)
        refute calendar.leap_year?(leap_year + 1)
      end
    end

    test "days_in_year distinguishes ordinary and leap years" do
      new_year = Chinese.new_year_for_gregorian_year(2025)
      {:ok, %{year: leap_year}} = Date.convert(new_year, Chinese)

      assert Chinese.days_in_year(leap_year) in 383..385
      assert Chinese.days_in_year(leap_year + 1) in 353..355
    end
  end

  describe "traditional and ordinal month numbering" do
    test "months after the intercalary shift by one ordinal position" do
      # In year 4662 the intercalary is at ordinal 7, so ordinal 8 is
      # traditional month 7.
      assert Chinese.month_of_year(4662, 8, 1) == 7
      # Before the intercalary the numbers coincide.
      assert Chinese.month_of_year(4662, 3, 1) == 3
    end

    test "traditional construction round-trips through ordinal dates" do
      for calendar <- [Chinese, Korean] do
        new_year = calendar.new_year_for_gregorian_year(2025)
        {:ok, %{year: year}} = Date.convert(new_year, calendar)

        # Traditional month 8 in a year whose intercalary precedes it.
        {:ok, date} = calendar.new(year, 8, 1)
        assert calendar.month_of_year(year, date.month, date.day) == 8
      end
    end
  end

  describe "festivals" do
    test "Dragon Boat festival (fifth month, fifth day)" do
      assert Chinese.dragon_festival_for_gregorian_year(2026) == ~D[2026-06-19]
    end

    test "Chuseok (eighth month, fifteenth day)" do
      assert Korean.thanksgiving_for_gregorian_year(2026) == ~D[2026-09-25]
    end
  end

  describe "round-trips" do
    test "conversions round-trip across a decade for each calendar" do
      for calendar <- @calendars, year <- [2018, 2022, 2026], month <- [2, 7, 11] do
        {:ok, date} = Date.new(year, month, 15)
        {:ok, lunar} = Date.convert(date, calendar)
        assert {:ok, ^date} = Date.convert(lunar, Calendar.ISO)
      end
    end
  end
end
