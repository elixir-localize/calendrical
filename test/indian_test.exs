defmodule Calendrical.IndianTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Indian

  alias Calendrical.Indian

  describe "year offset" do
    test "Saka year is 78 behind Gregorian" do
      assert Indian.gregorian_offset() == 78
      assert Indian.gregorian_year(1947) == 2025
      assert Indian.saka_year(2025) == 1947
    end

    test "year 1 Saka corresponds to Gregorian 79 CE" do
      assert Indian.gregorian_year(1) == 79
      assert Indian.saka_year(79) == 1
    end
  end

  describe "round-trip conversions" do
    test "1 Chaitra 1947 Saka = 22 March 2025 (ordinary year)" do
      {:ok, indian} = Date.new(1947, 1, 1, Indian)
      {:ok, gregorian} = Date.convert(indian, Calendrical.Gregorian)
      assert gregorian == ~D[2025-03-22 Calendrical.Gregorian]
    end

    test "1 Chaitra 1946 Saka = 21 March 2024 (leap year)" do
      {:ok, indian} = Date.new(1946, 1, 1, Indian)
      {:ok, gregorian} = Date.convert(indian, Calendrical.Gregorian)
      assert gregorian == ~D[2024-03-21 Calendrical.Gregorian]
    end

    test "round-trips a recent Gregorian date" do
      {:ok, gregorian} = Date.new(2024, 4, 7, Calendrical.Gregorian)
      {:ok, indian} = Date.convert(gregorian, Indian)
      {:ok, back} = Date.convert(indian, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "round-trips 50 random Gregorian dates" do
      :rand.seed(:exsss, {11, 12, 13})

      for _ <- 1..50 do
        iso_days = Enum.random(50_000..900_000)
        gregorian = Date.from_gregorian_days(iso_days)
        gregorian = %{gregorian | calendar: Calendrical.Gregorian}

        {:ok, indian} = Date.convert(gregorian, Indian)
        {:ok, back} = Date.convert(indian, Calendrical.Gregorian)
        assert back == gregorian
      end
    end
  end

  describe "leap_year?/1" do
    test "follows the proleptic Gregorian leap year rule on the corresponding year" do
      # 2024 = Saka 1946 — leap (Gregorian 2024 is leap)
      assert Indian.leap_year?(1946)
      # 2025 = Saka 1947 — not leap
      refute Indian.leap_year?(1947)
      # 2000 = Saka 1922 — leap (centurial /400)
      assert Indian.leap_year?(1922)
      # 2100 = Saka 2022 — not leap (centurial not /400)
      refute Indian.leap_year?(2022)
    end
  end

  describe "days_in_month/2" do
    test "Chaitra has 30 days in ordinary years and 31 in leap years" do
      assert Indian.days_in_month(1947, 1) == 30
      assert Indian.days_in_month(1946, 1) == 31
    end

    test "months 2-6 always have 31 days" do
      for month <- 2..6 do
        assert Indian.days_in_month(1947, month) == 31
        assert Indian.days_in_month(1946, month) == 31
      end
    end

    test "months 7-12 always have 30 days" do
      for month <- 7..12 do
        assert Indian.days_in_month(1947, month) == 30
        assert Indian.days_in_month(1946, month) == 30
      end
    end
  end

  describe "days_in_year/1" do
    test "365 in ordinary years, 366 in leap years" do
      assert Indian.days_in_year(1947) == 365
      assert Indian.days_in_year(1946) == 366
    end
  end

  describe "structural invariants" do
    test "consecutive 1 Chaitras are days_in_year apart" do
      for year <- 1940..1955 do
        {:ok, this_year} = Date.new(year, 1, 1, Indian)
        {:ok, next_year} = Date.new(year + 1, 1, 1, Indian)
        assert Date.diff(next_year, this_year) == Indian.days_in_year(year)
      end
    end

    test "sum of month lengths equals year length" do
      for year <- 1940..1955 do
        sum = Enum.reduce(1..12, 0, fn m, acc -> acc + Indian.days_in_month(year, m) end)
        assert sum == Indian.days_in_year(year)
      end
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names" do
      cases = [
        {1, "Chaitra"},
        {2, "Vaisakha"},
        {3, "Jyaistha"},
        {4, "Asadha"},
        {5, "Sravana"},
        {6, "Bhadra"},
        {7, "Asvina"},
        {8, "Kartika"},
        {9, "Agrahayana"},
        {10, "Pausa"},
        {11, "Magha"},
        {12, "Phalguna"}
      ]

      for {month, expected} <- cases do
        {:ok, date} = Date.new(1947, month, 1, Indian)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected
      end
    end
  end

  describe "day-of-week localization" do
    test "English day name for 1 Chaitra 1947 (= 22 March 2025, Saturday)" do
      {:ok, date} = Date.new(1947, 1, 1, Indian)
      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :wide) == "Saturday"
    end

    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1947, 1, 1, Indian)
      iso = Indian.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Indian.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Indian)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
