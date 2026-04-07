defmodule Calendrical.BuddhistTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Buddhist

  alias Calendrical.Buddhist

  describe "year offset" do
    test "Buddhist year is 543 ahead of Gregorian" do
      assert Buddhist.gregorian_offset() == 543
      assert Buddhist.buddhist_year(2024) == 2567
      assert Buddhist.gregorian_year(2567) == 2024
      assert Buddhist.buddhist_year(2026) == 2569
      assert Buddhist.gregorian_year(2569) == 2026
    end

    test "year 1 BE corresponds to proleptic Gregorian -542" do
      assert Buddhist.gregorian_year(1) == -542
      assert Buddhist.buddhist_year(-542) == 1
    end
  end

  describe "round-trip conversions" do
    test "1 January 2567 BE = 1 January 2024 CE" do
      {:ok, buddhist} = Date.new(2567, 1, 1, Buddhist)
      {:ok, gregorian} = Date.convert(buddhist, Calendrical.Gregorian)
      assert gregorian == ~D[2024-01-01 Calendrical.Gregorian]
    end

    test "29 February 2567 BE = 29 February 2024 CE (leap day)" do
      {:ok, buddhist} = Date.new(2567, 2, 29, Buddhist)
      {:ok, gregorian} = Date.convert(buddhist, Calendrical.Gregorian)
      assert gregorian == ~D[2024-02-29 Calendrical.Gregorian]
    end

    test "13 April 2569 BE (Songkran) = 13 April 2026 CE" do
      # Songkran is the Thai New Year festival, April 13-15.
      {:ok, buddhist} = Date.new(2569, 4, 13, Buddhist)
      {:ok, gregorian} = Date.convert(buddhist, Calendrical.Gregorian)
      assert gregorian == ~D[2026-04-13 Calendrical.Gregorian]
    end

    test "round-trips a recent Gregorian date through Buddhist" do
      {:ok, gregorian} = Date.new(2024, 7, 15, Calendrical.Gregorian)
      {:ok, buddhist} = Date.convert(gregorian, Buddhist)
      assert buddhist.year == 2567
      assert buddhist.month == 7
      assert buddhist.day == 15

      {:ok, back} = Date.convert(buddhist, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "round-trips 100 random Gregorian dates" do
      :rand.seed(:exsss, {7, 8, 9})

      for _ <- 1..100 do
        iso_days = Enum.random(-200_000..900_000)
        gregorian = Date.from_gregorian_days(iso_days)
        gregorian = %{gregorian | calendar: Calendrical.Gregorian}

        {:ok, buddhist} = Date.convert(gregorian, Buddhist)
        {:ok, back} = Date.convert(buddhist, Calendrical.Gregorian)
        assert back == gregorian
        assert buddhist.year == gregorian.year + 543
        assert buddhist.month == gregorian.month
        assert buddhist.day == gregorian.day
      end
    end
  end

  describe "leap_year?/1" do
    test "follows the proleptic Gregorian leap year rule (offset by 543)" do
      # 2024 CE = 2567 BE — divisible by 4, leap
      assert Buddhist.leap_year?(2567)
      # 2025 CE = 2568 BE — not divisible by 4
      refute Buddhist.leap_year?(2568)
      # 2000 CE = 2543 BE — divisible by 400, leap
      assert Buddhist.leap_year?(2543)
      # 2100 CE = 2643 BE — centurial not /400, not leap
      refute Buddhist.leap_year?(2643)
      # 1900 CE = 2443 BE — centurial not /400, not leap
      refute Buddhist.leap_year?(2443)
    end
  end

  describe "days_in_month/2" do
    test "January and December have 31 days" do
      assert Buddhist.days_in_month(2567, 1) == 31
      assert Buddhist.days_in_month(2567, 12) == 31
    end

    test "April, June, September, November have 30 days" do
      for month <- [4, 6, 9, 11] do
        assert Buddhist.days_in_month(2567, month) == 30
      end
    end

    test "February has 29 days in a leap year and 28 in an ordinary year" do
      assert Buddhist.days_in_month(2567, 2) == 29
      assert Buddhist.days_in_month(2568, 2) == 28
    end
  end

  describe "days_in_year/1" do
    test "365 in ordinary years, 366 in leap years" do
      assert Buddhist.days_in_year(2567) == 366
      assert Buddhist.days_in_year(2568) == 365
    end
  end

  describe "valid_date?/3" do
    test "accepts valid dates" do
      assert Buddhist.valid_date?(2567, 1, 1)
      assert Buddhist.valid_date?(2567, 12, 31)
      assert Buddhist.valid_date?(2567, 2, 29)
    end

    test "rejects invalid dates" do
      refute Buddhist.valid_date?(2568, 2, 29)
      refute Buddhist.valid_date?(2567, 13, 1)
      refute Buddhist.valid_date?(2567, 4, 31)
      refute Buddhist.valid_date?(2567, 0, 1)
      refute Buddhist.valid_date?(2567, 1, 0)
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names match Gregorian (CLDR shares the data)" do
      cases = [
        {1, "January"},
        {2, "February"},
        {3, "March"},
        {4, "April"},
        {5, "May"},
        {6, "June"},
        {7, "July"},
        {8, "August"},
        {9, "September"},
        {10, "October"},
        {11, "November"},
        {12, "December"}
      ]

      for {month, expected} <- cases do
        {:ok, date} = Date.new(2567, month, 1, Buddhist)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected
      end
    end

    test "abbreviated English month names" do
      {:ok, date} = Date.new(2569, 4, 1, Buddhist)
      assert Calendrical.localize(date, :month, locale: "en", format: :abbreviated) == "Apr"
    end

    test "Thai month names are returned in Thai script" do
      {:ok, april} = Date.new(2569, 4, 1, Buddhist)
      # April in Thai is เมษายน (mesayon)
      assert Calendrical.localize(april, :month, locale: "th", format: :wide) == "เมษายน"

      {:ok, december} = Date.new(2569, 12, 1, Buddhist)
      # December in Thai is ธันวาคม (thanwakhom)
      assert Calendrical.localize(december, :month, locale: "th", format: :wide) == "ธันวาคม"
    end
  end

  describe "day-of-week localization" do
    test "English day names" do
      # 1 January 2567 BE = 1 January 2024 (Monday)
      {:ok, date} = Date.new(2567, 1, 1, Buddhist)
      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :wide) == "Monday"
      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated) == "Mon"
    end

    test "Thai day names are returned in Thai script" do
      {:ok, date} = Date.new(2567, 1, 1, Buddhist)
      name = Calendrical.localize(date, :day_of_week, locale: "th", format: :wide)
      # Verify the result contains Thai characters
      assert String.match?(name, ~r/[\x{0E00}-\x{0E7F}]/u)
    end

    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(2567, 1, 1, Buddhist)
      iso = Buddhist.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Buddhist.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Buddhist)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end

  describe "structural invariants" do
    test "every Buddhist date matches the Gregorian date with year offset" do
      for year <- 2560..2580, month <- 1..12 do
        days = Buddhist.days_in_month(year, month)

        for day <- [1, days] do
          {:ok, b} = Date.new(year, month, day, Buddhist)
          {:ok, g} = Date.convert(b, Calendrical.Gregorian)
          assert g.year == year - 543
          assert g.month == month
          assert g.day == day
        end
      end
    end
  end
end
