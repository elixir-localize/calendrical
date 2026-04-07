defmodule Calendrical.CompositeTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Composite

  alias Calendrical.England

  describe "England — September 1752 transition" do
    test "September 1752 has only 19 valid days" do
      assert England.days_in_month(1752, 9) == 19
    end

    test "1753 has 365 days" do
      assert England.days_in_year(1753) == 365
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
      day_before = ~D[1752-09-02 Calendrical.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1752-09-14 Calendrical.England]
    end
  end

  describe "England — March 1751 (year-start) transition" do
    test "March 24, 1750 is followed by March 25, 1751" do
      day_before = ~D[1750-03-24 Calendrical.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1751-03-25 Calendrical.England]
    end

    test "March 24, 1751 is followed by March 25, 1751 (no jump)" do
      # 1751 became the first calendar year that ran Jan 1 → Dec 31,
      # so December 31 1751 is followed by January 1 1752.
      day_before = ~D[1751-12-31 Calendrical.England]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1752-01-01 Calendrical.England]
    end
  end

  describe "Russia — February 1918 transition" do
    test "31 January 1918 is followed by 14 February 1918" do
      day_before = ~D[1918-01-31 Calendrical.Russia]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1918-02-14 Calendrical.Russia]
    end

    test "13 days are missing in February 1918" do
      for d <- 1..13 do
        refute Calendrical.Russia.valid_date?(1918, 2, d), "expected #{d} Feb 1918 to be invalid"
      end
    end
  end

  describe "Calendrical.Composite.new/2" do
    test "creates a composite calendar at runtime" do
      assert {:ok, MyTest.Composite.Denmark} =
               Calendrical.Composite.new(MyTest.Composite.Denmark,
                 calendars: [~D[1700-03-01 Calendrical.Gregorian]]
               )

      # Should be in effect: Julian before 1700-03-01, Gregorian after.
      assert MyTest.Composite.Denmark.valid_date?(1700, 3, 1)
      assert MyTest.Composite.Denmark.valid_date?(1700, 1, 1)
    end

    test "returns :module_already_exists if the module is already loaded" do
      assert {:module_already_exists, Calendrical.England} =
               Calendrical.Composite.new(Calendrical.England, calendars: [~D[1900-01-01]])
    end
  end
end
