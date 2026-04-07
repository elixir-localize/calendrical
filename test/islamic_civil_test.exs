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

  describe "month name localization" do
    test "English month names" do
      cases = [
        {1, "Muharram"},
        {2, "Safar"},
        {3, "Rabiʻ I"},
        {4, "Rabiʻ II"},
        {5, "Jumada I"},
        {6, "Jumada II"},
        {7, "Rajab"},
        {8, "Shaʻban"},
        {9, "Ramadan"},
        {10, "Shawwal"},
        {11, "Dhuʻl-Qiʻdah"},
        {12, "Dhuʻl-Hijjah"}
      ]

      for {month, expected_name} <- cases do
        {:ok, date} = Date.new(1446, month, 1, Civil)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected_name
      end
    end

    test "abbreviated month names" do
      {:ok, muharram} = Date.new(1446, 1, 1, Civil)

      assert Calendrical.localize(muharram, :month, locale: "en", format: :abbreviated) ==
               "Muh."

      {:ok, ramadan} = Date.new(1446, 9, 1, Civil)

      assert Calendrical.localize(ramadan, :month, locale: "en", format: :abbreviated) ==
               "Ram."
    end

    test "Arabic month names are returned in Arabic script" do
      {:ok, ramadan} = Date.new(1446, 9, 1, Civil)
      name = Calendrical.localize(ramadan, :month, locale: "ar", format: :wide)
      # Ramadan in Arabic is رمضان
      assert name == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "English day names for known dates" do
      # 1 Muharram 1446 AH (civil) corresponds to a known Gregorian date.
      # Verify the localized day name is one of the seven valid English names.
      {:ok, date} = Date.new(1446, 1, 1, Civil)
      day = Calendrical.localize(date, :day_of_week, locale: "en", format: :wide)
      assert day in ~w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
    end

    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1446, 1, 1, Civil)
      iso = Civil.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Civil.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Civil)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end

    test "Arabic day names are returned in Arabic script" do
      {:ok, date} = Date.new(1446, 1, 1, Civil)
      name = Calendrical.localize(date, :day_of_week, locale: "ar", format: :wide)
      # Verify the result contains Arabic characters
      assert String.match?(name, ~r/[\x{0600}-\x{06FF}]/u)
    end
  end
end
