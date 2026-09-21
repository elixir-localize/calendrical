defmodule Calendrical.Reform.EnglandTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Reform.England

  alias Calendrical.{Gregorian, Julian}
  alias Calendrical.Reform.England

  describe "1752 — the Gregorian adoption" do
    test "September 1752 has only 19 valid days" do
      assert England.days_in_month(1752, 9) == 19
    end

    test "1752 is a leap year (Julian rule)" do
      assert England.leap_year?(1752)
    end

    test "valid days in September 1752 are 1, 2, and 14..30" do
      for d <- 1..2 do
        assert England.valid_date?(1752, 9, d), "expected #{d} Sep 1752 to be valid"
      end

      for d <- 14..30 do
        assert England.valid_date?(1752, 9, d), "expected #{d} Sep 1752 to be valid"
      end
    end

    test "September 3-13, 1752 are not valid dates" do
      for d <- 3..13 do
        refute England.valid_date?(1752, 9, d), "expected #{d} Sep 1752 to be invalid"
      end
    end

    test "11 days are 'missing' across the transition" do
      day_before = ~D[1752-09-02 Calendrical.Reform.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1752-09-14 Calendrical.Reform.England]
    end

    test "leap years follow the calendar in force" do
      # 1100 is in the Julian era (divisible by 4 → leap); 1900 is in
      # the Gregorian era (century not divisible by 400 → not leap).
      assert England.leap_year?(1100)
      refute England.leap_year?(1900)
    end

    test "dates convert to the underlying calendars" do
      assert Date.convert(~D[1752-09-14 Calendrical.Reform.England], Gregorian) ==
               {:ok, ~D[1752-09-14 Calendrical.Gregorian]}

      assert Date.convert(~D[1752-09-02 Calendrical.Reform.England], Julian) ==
               {:ok, ~D[1752-09-02 Calendrical.Julian]}
    end

    test "modern dates convert into the composite calendar unchanged" do
      assert Date.convert(~D[2024-03-11], England) ==
               {:ok, ~D[2024-03-11 Calendrical.Reform.England]}
    end
  end

  describe "1751 — the January 1 year-start transition" do
    test "1751 is a short year of 282 days" do
      assert England.days_in_year(1751) == 282
      assert England.days_in_month(1751, 3) == 7
    end

    test "March 24, 1750 is followed by March 25, 1751" do
      day_before = ~D[1750-03-24 Calendrical.Reform.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1751-03-25 Calendrical.Reform.England]
    end

    test "December 31, 1751 is followed by January 1, 1752" do
      # 1751 became the first calendar year that ran Jan 1 → Dec 31,
      # so December 31 1751 is followed by January 1 1752.
      day_before = ~D[1751-12-31 Calendrical.Reform.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1752-01-01 Calendrical.Reform.England]
    end
  end
end
