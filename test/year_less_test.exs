defmodule Calendrical.YearLessTest do
  use ExUnit.Case, async: true

  # Year-less calendar primitives: `days_in_month/1` and
  # `months_in_year/0`. Each returns an integer when the value is the
  # same for every year, `{:ambiguous, range}` when it varies with the
  # year, and `{:error, :undefined}` when it cannot be determined
  # without a year (or the month is out of range).

  describe "days_in_month/1" do
    test "fixed-length months return their length" do
      assert Calendrical.Gregorian.days_in_month(1) == 31
      assert Calendrical.Gregorian.days_in_month(4) == 30
      assert Calendrical.Gregorian.days_in_month(12) == 31
    end

    test "February is ambiguous without a year" do
      assert Calendrical.Gregorian.days_in_month(2) == {:ambiguous, 28..29}
    end

    test "out-of-range months are undefined, not a wrapped length" do
      for month <- [0, 13, 14, -1] do
        assert Calendrical.Gregorian.days_in_month(month) == {:error, :undefined},
               "days_in_month(#{month}) should be {:error, :undefined}"
      end
    end
  end

  describe "months_in_year/0" do
    test "fixed-length calendars return an integer" do
      assert Calendrical.Gregorian.months_in_year() == 12
      assert Calendrical.Coptic.months_in_year() == 13
      # Week-based calendars (Week compiler) carry the 12-month structure.
      assert Calendrical.ISOWeek.months_in_year() == 12
    end

    test "lunisolar calendars return an ambiguous range" do
      assert Calendrical.Hebrew.months_in_year() == {:ambiguous, 12..13}
    end

    test "agrees with months_in_year/1 for a fixed-length calendar" do
      assert Calendrical.Gregorian.months_in_year() == Calendrical.Gregorian.months_in_year(2025)
    end
  end
end
