defmodule Calendrical.HebrewTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Hebrew

  alias Calendrical.Hebrew

  describe "round-trip conversions" do
    test "1 Tishri 5784 AM = 16 September 2023 (Gregorian)" do
      {:ok, hebrew} = Date.new(5784, 1, 1, Hebrew)
      {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
      assert gregorian == ~D[2023-09-16 Calendrical.Gregorian]
    end

    test "1 Tishri 5785 AM = 3 October 2024 (Gregorian)" do
      {:ok, hebrew} = Date.new(5785, 1, 1, Hebrew)
      {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
      assert gregorian == ~D[2024-10-03 Calendrical.Gregorian]
    end

    test "1 Tishri 5786 AM = 23 September 2025 (Gregorian)" do
      {:ok, hebrew} = Date.new(5786, 1, 1, Hebrew)
      {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
      assert gregorian == ~D[2025-09-23 Calendrical.Gregorian]
    end

    test "15 Nisan 5784 AM (Passover) = 23 April 2024 (Gregorian)" do
      # Nisan is month 8 in CLDR Hebrew numbering
      {:ok, hebrew} = Date.new(5784, 8, 15, Hebrew)
      {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
      assert gregorian == ~D[2024-04-23 Calendrical.Gregorian]
    end

    test "10 Tishri 5785 AM (Yom Kippur) = 12 October 2024 (Gregorian)" do
      {:ok, hebrew} = Date.new(5785, 1, 10, Hebrew)
      {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
      assert gregorian == ~D[2024-10-12 Calendrical.Gregorian]
    end

    test "round-trips 2024-01-01 through Hebrew" do
      {:ok, gregorian} = Date.new(2024, 1, 1, Calendrical.Gregorian)
      {:ok, hebrew} = Date.convert(gregorian, Hebrew)
      {:ok, back} = Date.convert(hebrew, Calendrical.Gregorian)
      assert back == gregorian
      # Independent verification: 2024-01-01 = 20 Tevet 5784 (Tevet = month 4)
      assert hebrew.year == 5784
      assert hebrew.month == 4
      assert hebrew.day == 20
    end

    test "round-trips 100 random Gregorian dates over a 3000-year range" do
      :rand.seed(:exsss, {1, 2, 3})

      for _ <- 1..100 do
        iso_days = Enum.random(-200_000..900_000)
        gregorian = Date.from_gregorian_days(iso_days)
        gregorian = %{gregorian | calendar: Calendrical.Gregorian}

        {:ok, hebrew} = Date.convert(gregorian, Hebrew)
        {:ok, back} = Date.convert(hebrew, Calendrical.Gregorian)
        assert back == gregorian
      end
    end
  end

  describe "leap_year?/1" do
    test "follows the 19-year Metonic cycle" do
      for y <- 1..200 do
        expected = Integer.mod(7 * y + 1, 19) < 7
        assert Hebrew.leap_year?(y) == expected
      end
    end

    test "spot checks: known recent leap and non-leap years" do
      # 5782 (Sep 2021 – Sep 2022) is a leap year (year 6 of cycle 305)
      assert Hebrew.leap_year?(5782) == true
      # 5784 (Sep 2023 – Sep 2024) is a leap year (year 8 of cycle 305)
      assert Hebrew.leap_year?(5784) == true
      # 5785 (Sep 2024 – Oct 2025) is an ordinary year (year 9 of cycle 305)
      assert Hebrew.leap_year?(5785) == false
      # 5787 (Sep 2026 – Oct 2027) is a leap year (year 11 of cycle 305)
      assert Hebrew.leap_year?(5787) == true
    end
  end

  describe "months_in_year/1" do
    test "12 in ordinary years, 13 in leap years" do
      assert Hebrew.months_in_year(5785) == 12
      assert Hebrew.months_in_year(5784) == 13
    end
  end

  describe "days_in_year/1" do
    test "year length is always one of 353/354/355/383/384/385" do
      for year <- 5780..5800 do
        assert Hebrew.days_in_year(year) in [353, 354, 355, 383, 384, 385]
      end
    end

    test "ordinary years are 353-355 days" do
      for year <- 5780..5800, not Hebrew.leap_year?(year) do
        assert Hebrew.days_in_year(year) in [353, 354, 355]
      end
    end

    test "leap years are 383-385 days" do
      for year <- 5780..5800, Hebrew.leap_year?(year) do
        assert Hebrew.days_in_year(year) in [383, 384, 385]
      end
    end
  end

  describe "days_in_month/2" do
    test "fixed 30-day months" do
      # Tishri (1), Shevat (5), Nisan (8), Sivan (10), Av (12) are always 30
      assert Hebrew.days_in_month(5785, 1) == 30
      assert Hebrew.days_in_month(5785, 5) == 30
      assert Hebrew.days_in_month(5785, 8) == 30
      assert Hebrew.days_in_month(5785, 10) == 30
      assert Hebrew.days_in_month(5785, 12) == 30
    end

    test "fixed 29-day months" do
      # Tevet (4), Iyar (9), Tamuz (11), Elul (13) are always 29
      assert Hebrew.days_in_month(5785, 4) == 29
      assert Hebrew.days_in_month(5785, 9) == 29
      assert Hebrew.days_in_month(5785, 11) == 29
      assert Hebrew.days_in_month(5785, 13) == 29
    end

    test "Adar (7) is 29 days in both ordinary and leap years" do
      assert Hebrew.days_in_month(5785, 7) == 29
      assert Hebrew.days_in_month(5784, 7) == 29
    end

    test "Adar I (6) is 30 days in a leap year and 0 (invalid) in an ordinary year" do
      assert Hebrew.days_in_month(5784, 6) == 30
      assert Hebrew.days_in_month(5785, 6) == 0
    end

    test "Heshvan (2) and Kislev (3) vary by year length" do
      # Year 5785 has 355 days → long Heshvan (30) and long Kislev (30)
      assert Hebrew.days_in_year(5785) == 355
      assert Hebrew.days_in_month(5785, 2) == 30
      assert Hebrew.days_in_month(5785, 3) == 30

      # Year 5786 has 354 days → short Heshvan (29), long Kislev (30)
      assert Hebrew.days_in_year(5786) == 354
      assert Hebrew.days_in_month(5786, 2) == 29
      assert Hebrew.days_in_month(5786, 3) == 30
    end
  end

  describe "valid_date?/3" do
    test "accepts valid dates" do
      assert Hebrew.valid_date?(5785, 1, 1)
      assert Hebrew.valid_date?(5785, 7, 29)
      assert Hebrew.valid_date?(5785, 13, 29)
    end

    test "rejects month 6 (Adar I) in an ordinary year" do
      refute Hebrew.valid_date?(5785, 6, 1)
    end

    test "accepts month 6 (Adar I) in a leap year" do
      assert Hebrew.valid_date?(5784, 6, 1)
      assert Hebrew.valid_date?(5784, 6, 30)
    end

    test "rejects day 30 in a 29-day month" do
      refute Hebrew.valid_date?(5785, 4, 30)
    end

    test "rejects months and days out of bounds" do
      refute Hebrew.valid_date?(5785, 0, 1)
      refute Hebrew.valid_date?(5785, 14, 1)
      refute Hebrew.valid_date?(5785, 1, 0)
      refute Hebrew.valid_date?(5785, 1, 31)
    end

    test "rejects negative or zero years" do
      refute Hebrew.valid_date?(0, 1, 1)
      refute Hebrew.valid_date?(-1, 1, 1)
    end
  end

  describe "structural invariants" do
    test "consecutive 1 Tishri are exactly days_in_year apart" do
      for year <- 5780..5800 do
        {:ok, this_year} = Date.new(year, 1, 1, Hebrew)
        {:ok, next_year} = Date.new(year + 1, 1, 1, Hebrew)
        assert Date.diff(next_year, this_year) == Hebrew.days_in_year(year)
      end
    end

    test "every valid month is 29 or 30 days" do
      for year <- 5780..5800 do
        valid =
          if Hebrew.leap_year?(year), do: 1..13, else: Enum.to_list(1..5) ++ Enum.to_list(7..13)

        for month <- valid do
          assert Hebrew.days_in_month(year, month) in [29, 30]
        end
      end
    end

    test "sum of valid month lengths equals year length" do
      for year <- 5780..5800 do
        valid =
          if Hebrew.leap_year?(year), do: 1..13, else: Enum.to_list(1..5) ++ Enum.to_list(7..13)

        total = Enum.reduce(valid, 0, fn m, acc -> acc + Hebrew.days_in_month(year, m) end)
        assert total == Hebrew.days_in_year(year)
      end
    end

    test "the day after 29 Elul is 1 Tishri of the next year" do
      for year <- 5780..5790 do
        {:ok, last_day} = Date.new(year, 13, 29, Hebrew)
        {:ok, next_day} = Date.new(year + 1, 1, 1, Hebrew)
        assert Date.diff(next_day, last_day) == 1
      end
    end
  end

  describe "quarter_of_year/3" do
    test "is not defined" do
      assert Hebrew.quarter_of_year(5785, 1, 1) == {:error, :not_defined}
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names follow CLDR Hebrew numbering" do
      # An ordinary year (5785). Adar at position 7 (no Adar I).
      cases = [
        {5785, 1, "Tishri"},
        {5785, 2, "Heshvan"},
        {5785, 3, "Kislev"},
        {5785, 4, "Tevet"},
        {5785, 5, "Shevat"},
        {5785, 7, "Adar"},
        {5785, 8, "Nisan"},
        {5785, 9, "Iyar"},
        {5785, 10, "Sivan"},
        {5785, 11, "Tamuz"},
        {5785, 12, "Av"},
        {5785, 13, "Elul"}
      ]

      for {year, month, expected_name} <- cases do
        {:ok, date} = Date.new(year, month, 1, Hebrew)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected_name
      end
    end

    test "leap year produces 'Adar I' and 'Adar II' for months 6 and 7" do
      {:ok, adar_i} = Date.new(5784, 6, 1, Hebrew)
      assert Calendrical.localize(adar_i, :month, locale: "en", format: :wide) == "Adar I"

      {:ok, adar_ii} = Date.new(5784, 7, 1, Hebrew)
      assert Calendrical.localize(adar_ii, :month, locale: "en", format: :wide) == "Adar II"
    end

    test "abbreviated month names" do
      {:ok, tishri} = Date.new(5785, 1, 1, Hebrew)
      assert Calendrical.localize(tishri, :month, locale: "en", format: :abbreviated) == "Tishri"

      {:ok, nisan} = Date.new(5785, 8, 1, Hebrew)
      assert Calendrical.localize(nisan, :month, locale: "en", format: :abbreviated) == "Nisan"
    end

    test "Hebrew locale month names are returned in Hebrew script" do
      {:ok, tishri} = Date.new(5785, 1, 1, Hebrew)
      name = Calendrical.localize(tishri, :month, locale: "he", format: :wide)
      # Tishri in Hebrew is תשרי
      assert name == "תשרי"
    end
  end

  describe "day-of-week localization" do
    test "English day names" do
      {:ok, h} = Date.new(5784, 1, 1, Hebrew)
      # 1 Tishri 5784 = 16 September 2023, which was a Saturday
      assert Calendrical.localize(h, :day_of_week, locale: "en", format: :wide) == "Saturday"
      assert Calendrical.localize(h, :day_of_week, locale: "en", format: :abbreviated) == "Sat"
    end

    test "Hebrew locale day names are returned in Hebrew script" do
      {:ok, h} = Date.new(5784, 1, 1, Hebrew)
      name = Calendrical.localize(h, :day_of_week, locale: "he", format: :wide)
      # Saturday in Hebrew is "יום שבת"
      assert name == "יום שבת"
    end

    test "all 7 days of the week are localized" do
      # Generate 7 consecutive Hebrew dates and check each one's
      # localized day-of-week.
      {:ok, start} = Date.new(5785, 1, 1, Hebrew)
      iso = Calendrical.Hebrew.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Calendrical.Hebrew.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Hebrew)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
