defmodule Calendrical.Islamic.CivilTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.Civil

  alias Calendrical.Islamic.Civil

  describe "epoch and round-trip" do
    test "1 Muharram 1 AH is 19 July 622 (proleptic Gregorian)" do
      {:ok, hijri} = Date.new(1, 1, 1, Civil)
      {:ok, gregorian} = Date.convert(hijri, Calendrical.Gregorian)
      assert gregorian == ~D[0622-07-19 Calendrical.Gregorian]
    end

    test "round-trips a Gregorian date through Civil" do
      {:ok, gregorian} = Date.new(2024, 1, 1, Calendrical.Gregorian)
      {:ok, hijri} = Date.convert(gregorian, Civil)
      {:ok, back} = Date.convert(hijri, Calendrical.Gregorian)
      assert back == gregorian
    end
  end

  describe "leap_year?/1" do
    test "30-year cycle starting at year 1" do
      # Type II ("Kūshyār") cycle: years 2,5,7,10,13,16,18,21,24,26,29 are leap
      leap = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]

      for year <- 1..30 do
        assert Civil.leap_year?(year) == year in leap
      end
    end

    test "leap years repeat every 30 years" do
      for year <- 1..30 do
        assert Civil.leap_year?(year) == Civil.leap_year?(year + 30)
        assert Civil.leap_year?(year) == Civil.leap_year?(year + 600)
      end
    end
  end

  describe "days_in_month/2" do
    test "odd months are 30 days, even months are 29 days" do
      for month <- [1, 3, 5, 7, 9, 11], do: assert(Civil.days_in_month(1446, month) == 30)
      for month <- [2, 4, 6, 8, 10], do: assert(Civil.days_in_month(1446, month) == 29)
    end

    test "Dhu al-Hijjah is 29 days in ordinary years and 30 in leap years" do
      assert Civil.days_in_month(1446, 12) == 29
      assert Civil.days_in_month(1447, 12) == 30
    end
  end

  describe "days_in_year/1" do
    test "ordinary year has 354 days, leap year 355" do
      assert Civil.days_in_year(1446) == 354
      assert Civil.days_in_year(1447) == 355
    end
  end

  describe "structural invariants" do
    test "1 Muharram of consecutive years are 354 or 355 days apart" do
      for year <- 1440..1450 do
        days_in_year =
          Date.diff(
            Date.new!(year + 1, 1, 1, Civil),
            Date.new!(year, 1, 1, Civil)
          )

        assert days_in_year in [354, 355]
      end
    end

    test "consecutive months are 29 or 30 days apart" do
      for year <- [1444, 1446], month <- 1..11 do
        diff =
          Date.diff(
            Date.new!(year, month + 1, 1, Civil),
            Date.new!(year, month, 1, Civil)
          )

        assert diff in [29, 30]
      end
    end
  end
end
