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
      # Nisan is the 8th month of the leap year 5784
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
      # Tishri, Shevat, Nisan, Sivan and Av are always 30 days: months 1, 5,
      # 7, 9 and 11 of the ordinary year 5785, and 1, 5, 8, 10 and 12 of the
      # leap year 5784
      for month <- [1, 5, 7, 9, 11], do: assert(Hebrew.days_in_month(5785, month) == 30)
      for month <- [1, 5, 8, 10, 12], do: assert(Hebrew.days_in_month(5784, month) == 30)
    end

    test "fixed 29-day months" do
      # Tevet, Iyar, Tamuz and Elul are always 29 days: months 4, 8, 10 and
      # 12 of the ordinary year 5785, and 4, 9, 11 and 13 of the leap year 5784
      for month <- [4, 8, 10, 12], do: assert(Hebrew.days_in_month(5785, month) == 29)
      for month <- [4, 9, 11, 13], do: assert(Hebrew.days_in_month(5784, month) == 29)
    end

    test "Adar is 29 days: month 6 of an ordinary year, and month 7 (Adar II) of a leap year" do
      assert Hebrew.days_in_month(5785, 6) == 29
      assert Hebrew.days_in_month(5784, 7) == 29
    end

    test "Adar I, month 6 of a leap year, is 30 days" do
      assert Hebrew.days_in_month(5784, 6) == 30
    end

    test "a month the year does not have has no days" do
      assert Hebrew.days_in_month(5785, 13) == 0
      assert Hebrew.days_in_month(5784, 14) == 0
      assert Hebrew.days_in_month(5785, 0) == 0

      for bad <- [nil, "", :"", 1.0, %{}] do
        assert Hebrew.days_in_month(5785, bad) == 0
        assert Hebrew.days_in_month(bad, 1) == 0
      end
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
      assert Hebrew.valid_date?(5785, 6, 29)
      assert Hebrew.valid_date?(5785, 12, 29)
    end

    test "rejects a 13th month in an ordinary year" do
      refute Hebrew.valid_date?(5785, 13, 1)
    end

    test "accepts Adar I (month 6) and a 13th month in a leap year" do
      assert Hebrew.valid_date?(5784, 6, 1)
      assert Hebrew.valid_date?(5784, 6, 30)
      assert Hebrew.valid_date?(5784, 13, 29)
    end

    test "rejects day 30 of Adar in an ordinary year" do
      refute Hebrew.valid_date?(5785, 6, 30)
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

    test "every month of the year is 29 or 30 days" do
      for year <- 5780..5800, month <- 1..Hebrew.months_in_year(year) do
        assert Hebrew.days_in_month(year, month) in [29, 30]
      end
    end

    test "sum of the month lengths equals year length" do
      for year <- 5780..5800 do
        total =
          Enum.reduce(1..Hebrew.months_in_year(year), 0, fn month, acc ->
            acc + Hebrew.days_in_month(year, month)
          end)

        assert total == Hebrew.days_in_year(year)
      end
    end

    test "the day after 29 Elul is 1 Tishri of the next year" do
      for year <- 5780..5790 do
        {:ok, last_day} = Date.new(year, Hebrew.months_in_year(year), 29, Hebrew)
        {:ok, next_day} = Date.new(year + 1, 1, 1, Hebrew)
        assert Date.diff(next_day, last_day) == 1
      end
    end
  end

  describe "quarter_of_year/3" do
    test "follows the traditional months, Adar I and Adar II in the second quarter" do
      assert Hebrew.quarter_of_year(5785, 1, 1) == 1
      # 5787 is a leap year: Adar I is position 6, Adar II 7 and Nisan 8.
      assert Hebrew.quarter_of_year(5787, 6, 1) == 2
      assert Hebrew.quarter_of_year(5787, 7, 1) == 2
      assert Hebrew.quarter_of_year(5787, 8, 1) == 3
    end
  end

  describe "traditional months" do
    test "a traditional month names the same month in every year" do
      # Nisan is traditional month 7: the 7th month of an ordinary year and
      # the 8th of a leap year
      assert Hebrew.ordinal_month_from_traditional(5785, 7) == {:ok, 7}
      assert Hebrew.ordinal_month_from_traditional(5784, 7) == {:ok, 8}

      # Adar is traditional month 6, which is Adar II in a leap year
      assert Hebrew.ordinal_month_from_traditional(5785, 6) == {:ok, 6}
      assert Hebrew.ordinal_month_from_traditional(5784, 6) == {:ok, 7}

      # Adar I is the leap month that follows traditional month 5
      assert Hebrew.ordinal_month_from_traditional(5784, {5, :leap}) == {:ok, 6}

      assert Hebrew.ordinal_month_from_traditional(5785, {5, :leap}) ==
               {:error, :invalid_leap_month}
    end

    test "ordinal_month_from_traditional/2 and lunar_month_of_year/2 are inverses over every month" do
      for year <- 5780..5800, month <- 1..Hebrew.months_in_year(year) do
        traditional = Hebrew.lunar_month_of_year(year, month)
        assert Hebrew.ordinal_month_from_traditional(year, traditional) == {:ok, month}
      end
    end

    test "the traditional months of a leap year" do
      assert Enum.map(1..13, &Hebrew.lunar_month_of_year(5784, &1)) ==
               [1, 2, 3, 4, 5, {5, :leap}, 6, 7, 8, 9, 10, 11, 12]
    end

    test "the traditional months of an ordinary year are its positions" do
      assert Enum.map(1..12, &Hebrew.lunar_month_of_year(5785, &1)) == Enum.to_list(1..12)
    end

    test "the leap month" do
      assert Hebrew.leap_month(5784) == 6
      assert Hebrew.traditional_leap_month(5784) == 5
      assert Hebrew.leap_month(5785) == nil
      assert Hebrew.traditional_leap_month(5785) == nil
      assert Hebrew.leap_month(~D[5784-01-01 Calendrical.Hebrew]) == 6
      assert Hebrew.traditional_leap_month(~D[5785-01-01 Calendrical.Hebrew]) == nil
    end

    test "invalid input is an error, never an exception" do
      for bad <- [nil, "", :"", 0, 13, {6, :leap}, {5, :other}, 1.0, %{}] do
        assert {:error, _reason} = Hebrew.ordinal_month_from_traditional(5784, bad)
      end

      for bad_year <- [nil, "", :"", 1.0] do
        assert Hebrew.ordinal_month_from_traditional(bad_year, 1) == {:error, :invalid_month}
        assert Hebrew.lunar_month_of_year(bad_year, 1) == {:error, :invalid_month}
        assert Hebrew.leap_month(bad_year) == nil
        assert Hebrew.traditional_leap_month(bad_year) == nil
      end

      assert Hebrew.lunar_month_of_year(5785, 13) == {:error, :invalid_month}
      assert Hebrew.lunar_month_of_year(5785, 0) == {:error, :invalid_month}
      assert Hebrew.lunar_month_of_year(~D[2024-01-01]) == {:error, :invalid_month}
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names follow the months of an ordinary year" do
      # 5785 is an ordinary year, with no Adar I: Adar is its 6th month
      names = ~w[Tishri Heshvan Kislev Tevet Shevat Adar Nisan Iyar Sivan Tamuz Av Elul]

      for {expected_name, month} <- Enum.with_index(names, 1) do
        {:ok, date} = Date.new(5785, month, 1, Hebrew)
        assert Calendrical.localize(date, :month, locale: "en", style: :wide) == expected_name
      end
    end

    test "English month names follow the months of a leap year" do
      # 5784 is a leap year: Adar I is its 6th month and Adar II its 7th
      names =
        ["Tishri", "Heshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar II"] ++
          ~w[Nisan Iyar Sivan Tamuz Av Elul]

      for {expected_name, month} <- Enum.with_index(names, 1) do
        {:ok, date} = Date.new(5784, month, 1, Hebrew)
        assert Calendrical.localize(date, :month, locale: "en", style: :wide) == expected_name
      end
    end

    test "leap year produces 'Adar I' and 'Adar II' for months 6 and 7" do
      {:ok, adar_i} = Date.new(5784, 6, 1, Hebrew)
      assert Calendrical.localize(adar_i, :month, locale: "en", style: :wide) == "Adar I"

      {:ok, adar_ii} = Date.new(5784, 7, 1, Hebrew)
      assert Calendrical.localize(adar_ii, :month, locale: "en", style: :wide) == "Adar II"
    end

    test "abbreviated month names" do
      {:ok, tishri} = Date.new(5785, 1, 1, Hebrew)
      assert Calendrical.localize(tishri, :month, locale: "en", style: :abbreviated) == "Tishri"

      {:ok, nisan} = Date.new(5785, 7, 1, Hebrew)
      assert Calendrical.localize(nisan, :month, locale: "en", style: :abbreviated) == "Nisan"
    end

    test "Hebrew locale month names are returned in Hebrew script" do
      {:ok, tishri} = Date.new(5785, 1, 1, Hebrew)
      name = Calendrical.localize(tishri, :month, locale: "he", style: :wide)
      # Tishri in Hebrew is תשרי
      assert name == "תשרי"
    end
  end

  describe "day-of-week localization" do
    test "English day names" do
      {:ok, h} = Date.new(5784, 1, 1, Hebrew)
      # 1 Tishri 5784 = 16 September 2023, which was a Saturday
      assert Calendrical.localize(h, :day_of_week, locale: "en", style: :wide) == "Saturday"
      assert Calendrical.localize(h, :day_of_week, locale: "en", style: :abbreviated) == "Sat"
    end

    test "Hebrew locale day names are returned in Hebrew script" do
      {:ok, h} = Date.new(5784, 1, 1, Hebrew)
      name = Calendrical.localize(h, :day_of_week, locale: "he", style: :wide)
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
          Calendrical.localize(date, :day_of_week, locale: "en", style: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end

  describe "date_at/2" do
    test "defaults to midnight (the ordinary civil-day mapping)" do
      assert Hebrew.date_at(~U[2025-03-01 06:00:00Z]) ==
               {:ok, ~D[5785-06-01 Calendrical.Hebrew]}
    end

    test ":sunset and :nightfall diverge across bein hashemashot" do
      # Jerusalem, 1 Mar 2025: sunset 15:37Z, nightfall (8.5°) 16:13Z. At 16:00Z
      # the Hebrew day has begun by sunset but not yet by nightfall.
      dusk = ~U[2025-03-01 16:00:00Z]

      assert Hebrew.date_at(dusk, day_start: :sunset) ==
               {:ok, ~D[5785-06-02 Calendrical.Hebrew]}

      assert Hebrew.date_at(dusk, day_start: :nightfall) ==
               {:ok, ~D[5785-06-01 Calendrical.Hebrew]}
    end

    test ":nightfall_angle moves the boundary — a smaller depression rolls earlier" do
      # A 4° dusk (15:52Z) has passed by 16:00Z, unlike the 8.5° default.
      assert Hebrew.date_at(~U[2025-03-01 16:00:00Z], day_start: :nightfall, nightfall_angle: 4.0) ==
               {:ok, ~D[5785-06-02 Calendrical.Hebrew]}
    end

    test "accepts a custom :location (the observer's, not Jerusalem)" do
      new_york = %Geo.Point{coordinates: {-74.0060, 40.7128}}

      assert Hebrew.date_at(~U[2025-03-01 12:00:00Z], location: new_york, day_start: :sunset) ==
               {:ok, ~D[5785-06-01 Calendrical.Hebrew]}
    end

    test "returns an error, never raises, on bad input" do
      assert {:error, {:invalid_day_start, :bogus}} =
               Hebrew.date_at(~U[2025-03-01 12:00:00Z], day_start: :bogus)

      assert {:error, {:invalid_location, :nope}} =
               Hebrew.date_at(~U[2025-03-01 12:00:00Z], location: :nope)

      assert {:error, {:invalid_nightfall_angle, :nope}} =
               Hebrew.date_at(~U[2025-03-01 12:00:00Z],
                 day_start: :nightfall,
                 nightfall_angle: :nope
               )
    end
  end
end
