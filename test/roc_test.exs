defmodule Calendrical.RocTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Roc

  alias Calendrical.Roc

  describe "year offset" do
    test "ROC year is 1911 behind Gregorian" do
      assert Roc.gregorian_offset() == 1911
      assert Roc.gregorian_year(113) == 2024
      assert Roc.roc_year(2024) == 113
      assert Roc.gregorian_year(115) == 2026
      assert Roc.roc_year(2026) == 115
    end

    test "year 1 ROC corresponds to Gregorian 1912" do
      assert Roc.gregorian_year(1) == 1912
      assert Roc.roc_year(1912) == 1
    end
  end

  describe "round-trip conversions" do
    test "1 January 113 ROC = 1 January 2024 CE" do
      {:ok, roc} = Date.new(113, 1, 1, Roc)
      {:ok, gregorian} = Date.convert(roc, Calendrical.Gregorian)
      assert gregorian == ~D[2024-01-01 Calendrical.Gregorian]
    end

    test "10 October 113 ROC (National Day) = 10 October 2024 CE" do
      {:ok, roc} = Date.new(113, 10, 10, Roc)
      {:ok, gregorian} = Date.convert(roc, Calendrical.Gregorian)
      assert gregorian == ~D[2024-10-10 Calendrical.Gregorian]
    end

    test "29 February 113 ROC = 29 February 2024 CE (leap day)" do
      {:ok, roc} = Date.new(113, 2, 29, Roc)
      {:ok, gregorian} = Date.convert(roc, Calendrical.Gregorian)
      assert gregorian == ~D[2024-02-29 Calendrical.Gregorian]
    end

    test "round-trips a recent Gregorian date through ROC" do
      {:ok, gregorian} = Date.new(2026, 4, 7, Calendrical.Gregorian)
      {:ok, roc} = Date.convert(gregorian, Roc)
      assert roc.year == 115
      assert roc.month == 4
      assert roc.day == 7

      {:ok, back} = Date.convert(roc, Calendrical.Gregorian)
      assert back == gregorian
    end
  end

  describe "leap_year?/1" do
    test "follows the proleptic Gregorian leap year rule" do
      # 2024 = ROC 113 — leap
      assert Roc.leap_year?(113)
      # 2025 = ROC 114 — not leap
      refute Roc.leap_year?(114)
      # 2000 = ROC 89 — leap
      assert Roc.leap_year?(89)
      # 2100 = ROC 189 — centurial not /400, not leap
      refute Roc.leap_year?(189)
    end
  end

  describe "days_in_month/2" do
    test "matches Gregorian month lengths" do
      for month <- 1..12 do
        assert Roc.days_in_month(113, month) == Calendar.ISO.days_in_month(2024, month)
      end
    end

    test "February has 29 days in a leap year and 28 in an ordinary year" do
      assert Roc.days_in_month(113, 2) == 29
      assert Roc.days_in_month(114, 2) == 28
    end
  end

  describe "valid_date?/3" do
    test "accepts valid dates" do
      assert Roc.valid_date?(113, 2, 29)
      assert Roc.valid_date?(113, 12, 31)
    end

    test "rejects invalid dates" do
      refute Roc.valid_date?(114, 2, 29)
      refute Roc.valid_date?(113, 13, 1)
      refute Roc.valid_date?(113, 4, 31)
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names match Gregorian" do
      cases = [
        {1, "January"},
        {4, "April"},
        {10, "October"},
        {12, "December"}
      ]

      for {month, expected} <- cases do
        {:ok, date} = Date.new(113, month, 1, Roc)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected
      end
    end

    test "Chinese month names" do
      {:ok, date} = Date.new(113, 1, 1, Roc)
      name = Calendrical.localize(date, :month, locale: "zh-Hant", format: :wide)
      # Verify the result contains CJK characters
      assert String.match?(name, ~r/[\x{4E00}-\x{9FFF}]/u)
    end
  end

  describe "day-of-week localization" do
    test "English day name for 1 January 113 ROC" do
      # 1 January 2024 was a Monday
      {:ok, date} = Date.new(113, 1, 1, Roc)
      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :wide) == "Monday"
    end

    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(113, 1, 1, Roc)
      iso = Roc.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Roc.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Roc)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
