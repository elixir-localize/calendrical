defmodule Calendrical.Coverage.LunisolarTest do
  @moduledoc """
  Coverage tests for the lunisolar calendar family: `Calendrical.Chinese`,
  `Calendrical.Korean`, `Calendrical.LunarJapanese` and the shared
  `Calendrical.Lunisolar` base implementation.

  Every expected value in this file was probed against the implementation
  on Elixir 1.20.1 / OTP 29 and cross-checked against the published
  anchors (Chinese new years 2024-02-10 / 2025-01-29 / 2026-02-17, the
  intercalary sixth month of Chinese year 4662 beginning 2025-07-25,
  Chuseok 2026-09-25 and the dragon festival 2026-06-19).

  """
  use ExUnit.Case, async: true

  alias Calendrical.{Chinese, Korean, LunarJapanese, Lunisolar}

  # Beijing observation point and Chinese epoch, as used by
  # Calendrical.Chinese, for exercising the Lunisolar base module
  # directly.
  defp location(iso_days), do: Calendrical.Chinese.location(iso_days)

  defp epoch, do: Calendrical.Chinese.epoch()

  describe "Chinese cycle_and_year/1 and elapsed_years" do
    test "cycle_and_year/1 returns the sexagesimal cycle and cyclic year" do
      assert Chinese.cycle_and_year(4663) == {78, 43}
      assert Chinese.cycle_and_year(4662) == {78, 42}
    end

    test "elapsed_years/1 and elapsed_years/2 invert cycle_and_year/1" do
      assert Chinese.elapsed_years({78, 43}) == 4663
      assert Chinese.elapsed_years(78, 42) == 4662
      assert Lunisolar.elapsed_years({78, 43}) == 4663
    end
  end

  describe "Chinese cyclic_year" do
    test "cyclic_year/2 for year and month" do
      assert Chinese.cyclic_year(4663, 1) == 43
    end

    test "cyclic_year/1 for a date" do
      assert Chinese.cyclic_year(Date.new!(4662, 7, 1, Chinese)) == 42
    end

    test "Lunisolar.cyclic_year/3 ignores month and day" do
      assert Lunisolar.cyclic_year(4663, 5, 1) == 43
    end
  end

  describe "Chinese festivals and gregorian_date_for_lunar/3" do
    test "new_year_for_gregorian_year/1 across multiple years" do
      assert Chinese.new_year_for_gregorian_year(2024) == ~D[2024-02-10]
      assert Chinese.new_year_for_gregorian_year(2025) == ~D[2025-01-29]
      assert Chinese.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
    end

    test "dragon_festival_for_gregorian_year/1 across multiple years" do
      assert Chinese.dragon_festival_for_gregorian_year(2024) == ~D[2024-06-10]
      assert Chinese.dragon_festival_for_gregorian_year(2025) == ~D[2025-05-31]
      assert Chinese.dragon_festival_for_gregorian_year(2026) == ~D[2026-06-19]
    end

    test "gregorian_date_for_lunar/3 with a leap month" do
      assert Chinese.gregorian_date_for_lunar(2025, {6, :leap}, 1) == ~D[2025-07-25]
    end
  end

  describe "Chinese leap year and leap month" do
    test "leap_year?/1 both branches for integer years" do
      assert Chinese.leap_year?(4662)
      refute Chinese.leap_year?(4663)
    end

    test "leap_year?/1 for a date in this calendar" do
      assert Chinese.leap_year?(Date.new!(4662, 7, 1, Chinese))
    end

    test "leap_year?/1 converts a date in another calendar first" do
      assert Chinese.leap_year?(~D[2025-07-25])
      refute Chinese.leap_year?(~D[2026-07-05])
    end

    test "leap_month?/2 both branches" do
      assert Chinese.leap_month?(4662, 7)
      refute Chinese.leap_month?(4662, 6)
    end

    test "leap_month?/1 for a date" do
      assert Chinese.leap_month?(Date.new!(4662, 7, 1, Chinese))
    end

    test "leap_month?/3 with cycle and cyclic year" do
      assert Chinese.leap_month?(78, 42, 7)
    end

    test "leap_month/1 and traditional_leap_month/1" do
      assert Chinese.leap_month(4662) == 7
      assert Chinese.leap_month(4663) == nil
      assert Chinese.leap_month(Date.new!(4662, 7, 1, Chinese)) == 7
      assert Chinese.traditional_leap_month(4662) == 6
      assert Chinese.traditional_leap_month(4663) == nil
      assert Chinese.traditional_leap_month(Date.new!(4662, 7, 1, Chinese)) == 6
    end
  end

  describe "Chinese lunar_month_of_year and month_of_year" do
    test "lunar_month_of_year/2 over a leap year" do
      assert Chinese.lunar_month_of_year(4662, 7) == {6, :leap}
      assert Chinese.lunar_month_of_year(4662, 8) == 7
    end

    test "lunar_month_of_year/2 over an ordinary year" do
      assert Chinese.lunar_month_of_year(4663, 5) == 5
    end

    test "lunar_month_of_year/1 for a date" do
      assert Chinese.lunar_month_of_year(Date.new!(4662, 7, 1, Chinese)) == {6, :leap}
    end

    test "month_of_year/3 returns the traditional lunar month" do
      assert Chinese.month_of_year(4662, 7, 1) == {6, :leap}
    end
  end

  describe "Chinese new/3 and new!/3" do
    test "new/3 with a valid leap month" do
      assert {:ok, date} = Chinese.new(4662, {6, :leap}, 1)
      assert date.month == 7
      assert Date.convert(date, Calendar.ISO) == {:ok, ~D[2025-07-25]}
    end

    test "new/3 with the wrong leap month is invalid" do
      assert Chinese.new(4662, {5, :leap}, 1) == {:error, :invalid_date}
    end

    test "new/3 with a leap month in an ordinary year is invalid" do
      assert Chinese.new(4663, {6, :leap}, 1) == {:error, :invalid_date}
    end

    test "new/3 with a traditional month above 12 is invalid" do
      assert Chinese.new(4663, 13, 1) == {:error, :invalid_date}
    end

    test "new/3 with an invalid day is invalid" do
      assert Chinese.new(4663, 1, 31) == {:error, :invalid_date}
    end

    test "new!/3 returns a date and raises on invalid input" do
      assert Chinese.new!(4663, 1, 1) == Date.new!(4663, 1, 1, Chinese)
      assert Date.convert(Chinese.new!(4663, 1, 1), Calendar.ISO) == {:ok, ~D[2026-02-17]}

      assert_raise ArgumentError, ~r/invalid_date/, fn ->
        Chinese.new!(4663, {6, :leap}, 1)
      end
    end
  end

  describe "Chinese valid_date?/3, days_in_month/2 and days_in_year/1" do
    test "valid_date?/3 true and false branches" do
      assert Chinese.valid_date?(4663, 1, 29)
      assert Chinese.valid_date?(4663, 1, 30)
      refute Chinese.valid_date?(4663, 2, 30)
      refute Chinese.valid_date?(4663, 13, 1)
      assert Chinese.valid_date?(4662, 13, 29)
    end

    test "days_in_month/2 for 29 and 30 day months" do
      assert Chinese.days_in_month(4663, 1) == 30
      assert Chinese.days_in_month(4663, 2) == 29
      assert Chinese.days_in_month(4663, 12) == 29
      assert Chinese.days_in_month(4662, 7) == 29
      assert Chinese.days_in_month(4662, 13) == 29
    end

    test "days_in_year/1 for ordinary and leap years" do
      assert Chinese.days_in_year(4663) == 354
      assert Chinese.days_in_year(4662) == 384
    end

    test "months_in_year for ordinary and leap years" do
      assert Chinese.months_in_year(4663) == 12
      assert Chinese.months_in_year(4662) == 13
      assert Chinese.months_in_year() == {:ambiguous, 12..13}
    end
  end

  describe "Chinese iso_days conversions" do
    test "date_to_iso_days and date_from_iso_days round trip" do
      iso_days = Chinese.date_to_iso_days(4663, 1, 1)
      assert iso_days == Calendar.ISO.date_to_iso_days(2026, 2, 17)
      assert Chinese.date_to_iso_days({4663, 1, 1}) == iso_days
      assert Chinese.date_from_iso_days(iso_days) == {4663, 1, 1}
    end

    test "cyclical conversions used for testing" do
      iso_days = Chinese.date_to_iso_days(4663, 1, 1)
      assert Chinese.chinese_date_from_iso_days(iso_days) == {78, 43, 1, 1}
      assert Chinese.chinese_date_to_iso_days(78, 43, 1, 1) == iso_days
      assert Chinese.chinese_date_to_iso_days({78, 43, 1, 1}) == iso_days

      leap_start = Chinese.date_to_iso_days(4662, 7, 1)
      assert Chinese.alt_chinese_date_from_iso_days(leap_start) == {78, 42, 6, true, 1}
    end
  end

  describe "Korean korean_offset/1 and location/1" do
    test "korean_offset/1 for each historical period" do
      g = &Calendrical.Gregorian.date_to_iso_days/3

      assert Korean.korean_offset(g.(1900, 1, 1)) == 3809 / 450
      assert Korean.korean_offset(g.(1910, 1, 1)) == 8.5
      assert Korean.korean_offset(g.(1930, 1, 1)) == 9
      assert Korean.korean_offset(g.(1958, 1, 1)) == 8.5
      assert Korean.korean_offset(g.(2020, 1, 1)) == 9
    end

    test "location/1 returns Seoul with the offset in days" do
      iso_days = Calendrical.Gregorian.date_to_iso_days(2020, 1, 1)
      assert {latitude, longitude, 0, offset} = Korean.location(iso_days)
      assert_in_delta latitude, 37.5666, 0.001
      assert_in_delta longitude, 126.9666, 0.001
      assert offset == 0.375
    end
  end

  describe "Korean festivals and gregorian_date_for_lunar/3" do
    test "new_year_for_gregorian_year/1 across multiple years" do
      assert Korean.new_year_for_gregorian_year(2024) == ~D[2024-02-10]
      assert Korean.new_year_for_gregorian_year(2025) == ~D[2025-01-29]
      assert Korean.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
    end

    test "thanksgiving_for_gregorian_year/1 across multiple years" do
      assert Korean.thanksgiving_for_gregorian_year(2024) == ~D[2024-09-17]
      assert Korean.thanksgiving_for_gregorian_year(2025) == ~D[2025-10-06]
      assert Korean.thanksgiving_for_gregorian_year(2026) == ~D[2026-09-25]
    end

    test "gregorian_date_for_lunar/3 with a leap month" do
      assert Korean.gregorian_date_for_lunar(2025, {6, :leap}, 1) == ~D[2025-07-25]
    end
  end

  describe "Korean leap year and leap month" do
    test "leap_year?/1 both branches" do
      assert Korean.leap_year?(4358)
      refute Korean.leap_year?(4359)
      assert Korean.leap_year?(Date.new!(4358, 7, 1, Korean))
      assert Korean.leap_year?(~D[2025-07-25])
    end

    test "leap_month?/2 and leap_month?/1 both branches" do
      assert Korean.leap_month?(4358, 7)
      refute Korean.leap_month?(4358, 6)
      assert Korean.leap_month?(Date.new!(4358, 7, 1, Korean))
    end

    test "leap_month/1 and traditional_leap_month/1" do
      assert Korean.leap_month(4358) == 7
      assert Korean.leap_month(Date.new!(4358, 7, 1, Korean)) == 7
      assert Korean.traditional_leap_month(4358) == 6
      assert Korean.traditional_leap_month(4359) == nil
      assert Korean.traditional_leap_month(Date.new!(4358, 7, 1, Korean)) == 6
    end
  end

  describe "Korean months, cyclic year and validity" do
    test "lunar_month_of_year over ordinary and leap years" do
      assert Korean.lunar_month_of_year(4358, 7) == {6, :leap}
      assert Korean.lunar_month_of_year(4358, 8) == 7
      assert Korean.lunar_month_of_year(Date.new!(4358, 7, 1, Korean)) == {6, :leap}
      assert Korean.month_of_year(4358, 7, 1) == {6, :leap}
    end

    test "cyclic_year/2 and cyclic_year/1" do
      assert Korean.cyclic_year(4359, 1) == 39
      assert Korean.cyclic_year(Date.new!(4358, 7, 1, Korean)) == 38
    end

    test "valid_date?/3 true and false branches" do
      assert Korean.valid_date?(4358, 13, 29)
      refute Korean.valid_date?(4359, 13, 1)
    end

    test "days_in_month/2 and days_in_year/1" do
      assert Korean.days_in_month(4359, 1) == 30
      assert Korean.days_in_month(4359, 2) == 29
      assert Korean.days_in_month(4358, 7) == 29
      assert Korean.days_in_year(4359) == 355
      assert Korean.days_in_year(4358) == 384
    end
  end

  describe "Korean new/3 and new!/3" do
    test "new/3 with a valid leap month" do
      assert {:ok, date} = Korean.new(4358, {6, :leap}, 1)
      assert date.month == 7
      assert Date.convert(date, Calendar.ISO) == {:ok, ~D[2025-07-25]}
    end

    test "new/3 error paths" do
      assert Korean.new(4358, {5, :leap}, 1) == {:error, :invalid_date}
      assert Korean.new(4359, 13, 1) == {:error, :invalid_date}
      assert Korean.new(4359, 1, 31) == {:error, :invalid_date}
    end

    test "new!/3 returns a date and raises on invalid input" do
      assert Korean.new!(4359, 1, 1) == Date.new!(4359, 1, 1, Korean)

      assert_raise ArgumentError, ~r/invalid_date/, fn ->
        Korean.new!(4359, 13, 1)
      end
    end
  end

  describe "Korean iso_days conversions and new moons" do
    test "date_to_iso_days and date_from_iso_days round trip" do
      iso_days = Korean.date_to_iso_days(4359, 1, 1)
      assert iso_days == Calendar.ISO.date_to_iso_days(2026, 2, 17)
      assert Korean.date_to_iso_days({4359, 1, 1}) == iso_days
      assert Korean.date_from_iso_days(iso_days) == {4359, 1, 1}
    end

    test "new_moon_on_or_after/1" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)
      new_moon = Korean.new_moon_on_or_after(iso_days)
      assert Calendar.ISO.date_from_iso_days(new_moon) == {2026, 1, 19}
    end
  end

  describe "LunarJapanese eras" do
    test "year_of_era/1 for the first day of a lunar year" do
      assert LunarJapanese.year_of_era(1382) == {8, 236}
      assert LunarJapanese.year_of_era(1381) == {7, 236}
    end

    test "year_of_era/3 at the Reiwa transition (2019-05-01)" do
      date = Date.convert!(~D[2019-05-01], LunarJapanese)
      assert LunarJapanese.year_of_era(date.year, date.month, date.day) == {1, 236}

      before = Date.convert!(~D[2019-04-30], LunarJapanese)
      assert LunarJapanese.year_of_era(before.year, before.month, before.day) == {31, 235}
    end

    test "year_of_era/3 at the Ansei proclamation (1855-01-15)" do
      date = Date.convert!(~D[1855-01-15], LunarJapanese)
      assert date == Date.new!(1210, 12, 27, LunarJapanese)
      assert LunarJapanese.year_of_era(date.year, date.month, date.day) == {1, 227}
    end

    test "day_of_era/3 at the Reiwa transition" do
      date = Date.convert!(~D[2019-05-01], LunarJapanese)
      assert LunarJapanese.day_of_era(date.year, date.month, date.day) == {1, 236}

      before = Date.convert!(~D[2019-04-30], LunarJapanese)
      assert LunarJapanese.day_of_era(before.year, before.month, before.day) == {11070, 235}
    end

    test "calendar_year/3 is the era year" do
      date = Date.convert!(~D[1855-01-15], LunarJapanese)
      assert LunarJapanese.calendar_year(date.year, date.month, date.day) == 1
    end

    test "era_calendar_type/0 is :japanese" do
      assert LunarJapanese.era_calendar_type() == :japanese
    end
  end

  describe "LunarJapanese cycles and years" do
    test "cycle_and_year/1 and elapsed_years" do
      assert LunarJapanese.cycle_and_year(1382) == {24, 2}
      assert LunarJapanese.elapsed_years({24, 2}) == 1382
      assert LunarJapanese.elapsed_years(24, 2) == 1382
    end

    test "cyclic_year/2 and cyclic_year/1" do
      assert LunarJapanese.cyclic_year(1382, 1) == 2
      assert LunarJapanese.cyclic_year(Date.new!(1381, 7, 1, LunarJapanese)) == 1
    end

    test "leap_year?/1 both branches" do
      assert LunarJapanese.leap_year?(1381)
      refute LunarJapanese.leap_year?(1382)
      assert LunarJapanese.leap_year?(Date.new!(1381, 7, 1, LunarJapanese))
      assert LunarJapanese.leap_year?(~D[2025-07-25])
    end
  end

  describe "LunarJapanese leap months" do
    test "leap_month?/2 and leap_month?/1 both branches" do
      assert LunarJapanese.leap_month?(1381, 7)
      refute LunarJapanese.leap_month?(1381, 6)
      assert LunarJapanese.leap_month?(Date.new!(1381, 7, 1, LunarJapanese))
    end

    test "leap_month/1 and traditional_leap_month/1" do
      assert LunarJapanese.leap_month(1381) == 7
      assert LunarJapanese.leap_month(Date.new!(1381, 7, 1, LunarJapanese)) == 7
      assert LunarJapanese.traditional_leap_month(1381) == 6
      assert LunarJapanese.traditional_leap_month(1382) == nil
      assert LunarJapanese.traditional_leap_month(Date.new!(1381, 7, 1, LunarJapanese)) == 6
    end

    test "lunar_month_of_year and month_of_year over a leap year" do
      assert LunarJapanese.lunar_month_of_year(1381, 7) == {6, :leap}
      assert LunarJapanese.lunar_month_of_year(1381, 8) == 7

      assert LunarJapanese.lunar_month_of_year(Date.new!(1381, 7, 1, LunarJapanese)) ==
               {6, :leap}

      assert LunarJapanese.month_of_year(1381, 7, 1) == {6, :leap}
    end
  end

  describe "LunarJapanese new/3 and new!/3" do
    test "new/3 with a valid leap month" do
      assert {:ok, date} = LunarJapanese.new(1381, {6, :leap}, 1)
      assert date.month == 7
      assert Date.convert(date, Calendar.ISO) == {:ok, ~D[2025-07-25]}
    end

    test "new/3 for a pre-1888 date uses the Tokyo location" do
      assert {:ok, date} = LunarJapanese.new(1210, 11, 27)
      assert Date.convert(date, Calendar.ISO) == {:ok, ~D[1855-01-15]}
    end

    test "new/3 error paths" do
      assert LunarJapanese.new(1381, {5, :leap}, 1) == {:error, :invalid_date}
      assert LunarJapanese.new(1382, 13, 1) == {:error, :invalid_date}
    end

    test "new!/3 returns a date and raises on invalid input" do
      assert LunarJapanese.new!(1382, 1, 1) == Date.new!(1382, 1, 1, LunarJapanese)

      assert_raise ArgumentError, ~r/invalid_date/, fn ->
        LunarJapanese.new!(1382, 13, 1)
      end
    end
  end

  describe "LunarJapanese validity, month and year lengths" do
    test "valid_date?/3 true and false branches" do
      assert LunarJapanese.valid_date?(1381, 13, 29)
      refute LunarJapanese.valid_date?(1382, 13, 1)
    end

    test "days_in_month/2 and days_in_year/1" do
      assert LunarJapanese.days_in_month(1382, 1) == 30
      assert LunarJapanese.days_in_month(1382, 2) == 29
      assert LunarJapanese.days_in_month(1381, 7) == 29
      assert LunarJapanese.days_in_year(1382) == 355
      assert LunarJapanese.days_in_year(1381) == 384
    end
  end

  describe "LunarJapanese conversions and new moons" do
    test "gregorian_date_for_lunar/3 and new_year_for_gregorian_year/1" do
      assert LunarJapanese.gregorian_date_for_lunar(2021, 1, 1) == ~D[2021-02-12]
      assert LunarJapanese.new_year_for_gregorian_year(2026) == ~D[2026-02-17]
      assert LunarJapanese.new_year_for_gregorian_year(1855) == ~D[1855-02-17]
    end

    test "new_moon_before/1 and new_moon_on_or_after/1" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      assert Calendar.ISO.date_from_iso_days(LunarJapanese.new_moon_before(iso_days)) ==
               {2025, 12, 20}

      assert Calendar.ISO.date_from_iso_days(LunarJapanese.new_moon_on_or_after(iso_days)) ==
               {2026, 1, 19}
    end

    test "date_to_iso_days and date_from_iso_days round trip" do
      iso_days = LunarJapanese.date_to_iso_days(1382, 1, 1)
      assert iso_days == Calendar.ISO.date_to_iso_days(2026, 2, 17)
      assert LunarJapanese.date_to_iso_days({1382, 1, 1}) == iso_days
      assert LunarJapanese.date_from_iso_days(iso_days) == {1382, 1, 1}
    end

    test "location/1 switches from Tokyo to Japan standard time in 1888" do
      before = LunarJapanese.location(Calendar.ISO.date_to_iso_days(1850, 1, 1))
      assert {35.7, longitude, 24, offset} = before
      assert_in_delta longitude, 139.766, 0.001
      assert_in_delta offset, 0.38824, 0.00001

      after_1888 = LunarJapanese.location(Calendar.ISO.date_to_iso_days(2020, 1, 1))
      assert after_1888 == {35, 135, 0, 0.375}
    end
  end

  describe "Lunisolar base implementation" do
    test "new/5 for ordinary and leap months" do
      assert Lunisolar.new(4663, 1, 1, epoch(), &location/1) ==
               Calendar.ISO.date_to_iso_days(2026, 2, 17)

      assert Lunisolar.new(4662, {6, :leap}, 1, epoch(), &location/1) ==
               Calendar.ISO.date_to_iso_days(2025, 7, 25)
    end

    test "new/5 error paths" do
      assert Lunisolar.new(4662, {5, :leap}, 1, epoch(), &location/1) ==
               {:error, :invalid_date}

      assert Lunisolar.new(4663, {6, :leap}, 1, epoch(), &location/1) ==
               {:error, :invalid_date}

      assert Lunisolar.new(4663, 13, 1, epoch(), &location/1) == {:error, :invalid_date}
      assert Lunisolar.new(4663, 1, 31, epoch(), &location/1) == {:error, :invalid_date}
    end

    test "gregorian_date_for_lunar/5" do
      assert Lunisolar.gregorian_date_for_lunar(2026, 1, 1, epoch(), &location/1) ==
               {2026, 2, 17}
    end

    test "lunar_month_of_year/5 returns the leap tuple for the intercalary" do
      assert Lunisolar.lunar_month_of_year(4662, 7, 1, epoch(), &location/1) == {6, :leap}
    end

    test "leap_year?/3, leap_month/3 and leap_month?/5" do
      assert Lunisolar.leap_year?(4662, epoch(), &location/1)
      refute Lunisolar.leap_year?(4663, epoch(), &location/1)
      assert Lunisolar.leap_month(4662, epoch(), &location/1) == 7
      assert Lunisolar.leap_month(4663, epoch(), &location/1) == nil
      assert Lunisolar.leap_month?(78, 42, 7, epoch(), &location/1)
    end

    test "leap_lunisolar_year?/5 both branches" do
      assert Lunisolar.leap_lunisolar_year?(4662, 8, 1, epoch(), &location/1)
      refute Lunisolar.leap_lunisolar_year?(4663, 5, 1, epoch(), &location/1)
    end

    test "cyclical date conversions round trip" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 2, 17)

      assert Lunisolar.date_from_iso_days(iso_days, epoch(), &location/1) == {4663, 1, 1}

      assert Lunisolar.cyclical_date_from_iso_days(iso_days, epoch(), &location/1) ==
               {78, 43, 1, 1}

      assert Lunisolar.cyclical_date_to_iso_days(78, 43, 1, 1, epoch(), &location/1) ==
               iso_days

      assert Lunisolar.alt_cyclical_date_from_iso_days(iso_days, epoch(), &location/1) ==
               {78, 43, 1, false, 1}
    end

    test "alt_cyclical_date_to_iso_days/6 distinguishes leap from ordinary months" do
      ordinary = Lunisolar.alt_cyclical_date_to_iso_days(78, 42, 6, 1, epoch(), &location/1)
      assert Calendar.ISO.date_from_iso_days(ordinary) == {2025, 6, 25}

      leap =
        Lunisolar.alt_cyclical_date_to_iso_days(78, 42, {6, :leap}, 1, epoch(), &location/1)

      assert Calendar.ISO.date_from_iso_days(leap) == {2025, 7, 25}
    end

    test "new moons around 2026-01-01 in Beijing" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      assert Calendar.ISO.date_from_iso_days(Lunisolar.new_moon_before(iso_days, &location/1)) ==
               {2025, 12, 20}

      assert Calendar.ISO.date_from_iso_days(
               Lunisolar.new_moon_on_or_after(iso_days, &location/1)
             ) == {2026, 1, 19}
    end

    test "solstice, sui and new year calculations" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      assert Calendar.ISO.date_from_iso_days(
               Lunisolar.december_solstice_on_or_before(iso_days, &location/1)
             ) == {2025, 12, 21}

      assert Calendar.ISO.date_from_iso_days(Lunisolar.new_year_in_sui(iso_days, &location/1)) ==
               {2026, 2, 17}

      assert Calendar.ISO.date_from_iso_days(
               Lunisolar.new_year_on_or_before(iso_days, &location/1)
             ) == {2025, 1, 29}

      assert Calendar.ISO.date_from_iso_days(
               Lunisolar.chinese_new_year_for_gregorian_year(2026, &location/1)
             ) == {2026, 2, 17}
    end

    test "solar terms current values" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      assert Lunisolar.current_major_solar_term(iso_days, &location/1) == 11

      assert Lunisolar.current_minor_solar_term(iso_days, &location/1) == 11
      assert Lunisolar.no_major_solar_term?(iso_days, &location/1)
      assert Lunisolar.midnight_in_location(iso_days, &location/1) == 739_981.6666666666
    end

    test "solar term on-or-after functions return event moments" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      # 大寒 (sun at 300 degrees) falls on 2026-01-20 Beijing time.
      major = Lunisolar.major_solar_term_on_or_after(iso_days, &location/1)
      assert Calendar.ISO.date_from_iso_days(floor(major)) == {2026, 1, 20}
      assert Lunisolar.solar_longitude_on_or_after(300, iso_days, &location/1) == major

      # 小寒 (sun at 285 degrees) falls on 2026-01-05 Beijing time.
      minor = Lunisolar.minor_solar_term_on_or_after(iso_days, &location/1)
      assert Calendar.ISO.date_from_iso_days(floor(minor)) == {2026, 1, 5}
    end

    test "is_prior_leap_month?/3 returns false when the range is empty" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)
      refute Lunisolar.is_prior_leap_month?(iso_days, iso_days - 10, &location/1)
    end

    test "sexagesimal names" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)

      assert Lunisolar.stem_and_branch({4663, 1, 1}) == {3, 7}
      assert Lunisolar.stem_and_branch({78, 43, 1, false, 1}) == {3, 7}
      assert Lunisolar.stem_and_branch(43) == {3, 7}

      assert Lunisolar.name_difference(
               Lunisolar.stem_and_branch(1),
               Lunisolar.stem_and_branch(2)
             ) == 1

      assert Lunisolar.month_name(1, 4663) == {7, 3}
      assert Lunisolar.day_name(iso_days) == {7, 5}
      assert Lunisolar.day_name_on_or_before(Lunisolar.stem_and_branch(1), iso_days) == 739_936
    end

    test "location/2 returns a Geo.PointZ with the offset" do
      iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)
      point = Lunisolar.location(iso_days, &location/1)

      assert %Geo.PointZ{coordinates: {longitude, latitude, altitude}} = point
      assert_in_delta longitude, 116.4166, 0.001
      assert_in_delta latitude, 39.9166, 0.001
      assert altitude == 43.5
      assert point.properties.offset == 1 / 3
    end
  end
end
