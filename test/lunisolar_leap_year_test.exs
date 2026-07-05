defmodule Calendrical.LunisolarLeapYear.Test do
  @moduledoc """
  Regression tests for lunisolar leap-year detection on 383-day years.

  The bug being protected against: `Calendrical.Lunisolar.leap_year?/3`
  used `floor(year_length / mean_synodic_month) == 13`, which truncates a
  383-day thirteen-month year to 12 (383 / 29.53 ≈ 12.97). Such years were
  reported as ordinary — `months_in_year/1` returned 12, `leap_month/1`
  returned `nil`, `days_in_month(year, 12)` fused the last two lunations
  into an impossible 59-day month, and ordinal month 13 was rejected as
  invalid — even though `date_to_iso_days`/`date_from_iso_days` produced a
  13-month sequence. Lunar year 569 (beginning in 1213 CE) is the canonical
  case; 45 of the 1240 lunar years from 645 CE to 1884 CE were affected.

  """

  use ExUnit.Case, async: true

  alias Calendrical.LunarJapanese

  describe "lunar year 569 (a 383-day leap year, intercalary 閏7月)" do
    test "is detected as a leap year with 13 months" do
      assert LunarJapanese.leap_year?(569)
      assert LunarJapanese.months_in_year(569) == 13
      assert LunarJapanese.leap_month(569) == 8
      assert LunarJapanese.traditional_leap_month(569) == 7
    end

    test "every month has a plausible lunar length and the year sums up" do
      days = for month <- 1..13, do: LunarJapanese.days_in_month(569, month)

      assert Enum.all?(days, &(&1 in 29..30))
      assert Enum.sum(days) == 383

      # The default Calendrical.Behaviour days_in_year/1 counted one
      # day too many (`next_year_start - this_year_start + 1`).
      assert LunarJapanese.days_in_year(569) == 383
    end

    test "ordinal month 13 is a valid date" do
      assert {:ok, _date} = Date.new(569, 13, 6, LunarJapanese)
    end

    test "traditional months 11 and 12 map to ordinal months 12 and 13" do
      assert {:ok, date11} = LunarJapanese.new(569, 11, 6)
      assert date11.month == 12
      assert {:ok, ~D[1213-12-26]} = Date.convert(date11, Calendar.ISO)

      assert {:ok, date12} = LunarJapanese.new(569, 12, 6)
      assert date12.month == 13
      assert {:ok, ~D[1214-01-25]} = Date.convert(date12, Calendar.ISO)
    end

    test "a day one past the end of a traditional month is invalid" do
      # Ordinal month 1 of year 569 has 29 days. Before the fix,
      # the traditional-date day validation computed month length as
      # `last - first + 1` (where `last` is the first day of the next
      # month), accepting day 30 and silently rolling it into month 2.
      assert LunarJapanese.days_in_month(569, 1) == 29
      assert {:ok, _date} = LunarJapanese.new(569, 1, 29)
      assert {:error, :invalid_date} = LunarJapanese.new(569, 1, 30)
    end
  end

  describe "other 383-day leap years detected by the fixed rule" do
    test "lunar year 1197 (beginning in 1841 CE) is a leap year" do
      assert LunarJapanese.leap_year?(1197)
      assert LunarJapanese.months_in_year(1197) == 13
      refute is_nil(LunarJapanese.leap_month(1197))
    end

    test "an adjacent ordinary year stays ordinary" do
      refute LunarJapanese.leap_year?(1198)
      assert LunarJapanese.months_in_year(1198) == 12
      assert is_nil(LunarJapanese.leap_month(1198))
      assert {:error, :invalid_date} = Date.new(1198, 13, 1, LunarJapanese)
    end
  end
end
