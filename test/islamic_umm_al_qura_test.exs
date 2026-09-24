defmodule Calendrical.Islamic.UmmAlQuraTest do
  @moduledoc """
  Tests for `Calendrical.Islamic.UmmAlQura`.

  The calendar is built from the official month lengths published by KACST
  in `priv/umm_al_qura_month_lengths.csv`. The full-table tests derive every
  expected month start from that file by summing month lengths from the
  epoch, independently of the calendar's compiled lookup structures. The
  spot checks pin dates from the KACST calendar, including months where
  R.H. van Gent's astronomical reconstruction differs from it.

  """

  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.UmmAlQura

  alias Calendrical.Islamic.UmmAlQura

  # Every month in the data file as `{year, month, first_day, days}`, with
  # first days found by summing month lengths from 1 Muharram 1 AH.
  defp official_months do
    [_header | rows] =
      "priv/umm_al_qura_month_lengths.csv"
      |> File.read!()
      |> String.split(~r/\r?\n/, trim: true)

    {months, _next_first_day} =
      rows
      |> Enum.flat_map(fn row ->
        [year | lengths] = row |> String.split(",") |> Enum.map(&String.to_integer/1)
        lengths |> Enum.with_index(1) |> Enum.map(fn {days, month} -> {year, month, days} end)
      end)
      |> Enum.map_reduce(~D[0622-07-19], fn {year, month, days}, first_day ->
        {{year, month, first_day, days}, Date.add(first_day, days)}
      end)

    months
  end

  # ─── Full-table validation ─────────────────────────────────────────────────

  test "every month's first day and length matches the KACST data file" do
    failures =
      for {year, month, first_day, days} <- official_months(),
          UmmAlQura.first_day_of_month(year, month) != {:ok, first_day} or
            UmmAlQura.days_in_month(year, month) != days do
        "#{year}/#{month}: expected #{first_day}, #{days} days"
      end

    assert failures == [],
           "#{length(failures)} months differ, first: #{Enum.join(Enum.take(failures, 10), "; ")}"
  end

  test "round-trips the first and last day of every month through the Gregorian calendar" do
    for {year, month, _first_day, days} <- official_months(), day <- [1, days] do
      {:ok, hijri} = Date.new(year, month, day, UmmAlQura)
      {:ok, gregorian} = Date.convert(hijri, Calendrical.Gregorian)
      assert Date.convert(gregorian, UmmAlQura) == {:ok, hijri}
    end
  end

  describe "range" do
    test "covers 1 AH through 1500 AH" do
      assert UmmAlQura.min_year() == 1
      assert UmmAlQura.max_year() == 1500
    end

    test "1 Muharram 1 AH is the epoch, 19 July 622" do
      assert {:ok, ~D[0622-07-19]} = UmmAlQura.first_day_of_month(1, 1)
    end

    test "30 Dhu al-Hijja 1500 AH, 16 November 2077, is the last day covered" do
      {:ok, last} = Date.new(1500, 12, 30, UmmAlQura)

      assert {:ok, ~D[2077-11-16 Calendrical.Gregorian]} =
               Date.convert(last, Calendrical.Gregorian)
    end
  end

  # ─── Spot checks ───────────────────────────────────────────────────────────

  describe "Era 1 (1356–1419 AH) spot checks" do
    test "1 Muharram 1356 AH = 14 March 1937" do
      assert {:ok, ~D[1937-03-14]} = UmmAlQura.first_day_of_month(1356, 1)
    end

    test "1 Muharram 1392 AH = 16 February 1972" do
      assert {:ok, ~D[1972-02-16]} = UmmAlQura.first_day_of_month(1392, 1)
    end

    test "1 Ramadan 1400 AH = 14 July 1980" do
      assert {:ok, ~D[1980-07-14]} = UmmAlQura.first_day_of_month(1400, 9)
    end
  end

  # R.H. van Gent's tables, which this calendar used before 1.4.0, are an
  # astronomical reconstruction that differs from KACST in 695 of the
  # months from 1356 to 1500 AH. These pin representative ones to KACST.
  describe "months where KACST differs from van Gent's reconstruction" do
    test "Sha'ban 1364 AH has 29 days (van Gent: 28)" do
      assert UmmAlQura.days_in_month(1364, 8) == 29
    end

    test "1356 AH has 355 days and 1401 AH 354 (van Gent: 353 each)" do
      assert UmmAlQura.days_in_year(1356) == 355
      assert UmmAlQura.days_in_year(1401) == 354
    end

    test "1 Rabi' al-Thani 1451 AH = 12 August 2029 (van Gent: 11 August)" do
      assert {:ok, ~D[2029-08-12]} = UmmAlQura.first_day_of_month(1451, 4)
    end

    test "1 Shawwal 1485 AH = 31 January 2063 (van Gent: 30 January)" do
      assert {:ok, ~D[2063-01-31]} = UmmAlQura.first_day_of_month(1485, 10)
    end
  end

  describe "Era 4 (≥ 1423 AH) spot checks" do
    test "1 Muharram 1423 AH = 15 March 2002" do
      assert {:ok, ~D[2002-03-15]} = UmmAlQura.first_day_of_month(1423, 1)
    end

    test "1 Ramadan 1444 AH = 23 March 2023" do
      assert {:ok, ~D[2023-03-23]} = UmmAlQura.first_day_of_month(1444, 9)
    end

    test "1 Muharram 1446 AH = 7 July 2024" do
      assert {:ok, ~D[2024-07-07]} = UmmAlQura.first_day_of_month(1446, 1)
    end

    test "1 Ramadan 1446 AH = 1 March 2025" do
      assert {:ok, ~D[2025-03-01]} = UmmAlQura.first_day_of_month(1446, 9)
    end
  end

  # ─── Calendar callbacks ────────────────────────────────────────────────────

  describe "Calendar callbacks" do
    test "Date.new/4 succeeds for valid dates" do
      assert {:ok, _} = Date.new(1446, 1, 1, UmmAlQura)
      assert {:ok, _} = Date.new(1446, 9, 29, UmmAlQura)
    end

    test "Date.new/4 fails for invalid month/day combinations" do
      assert {:error, :invalid_date} = Date.new(1446, 13, 1, UmmAlQura)
      assert {:error, :invalid_date} = Date.new(1446, 1, 31, UmmAlQura)
      # Ramadan 1446 has 29 days in UmmAlQura
      assert {:error, :invalid_date} = Date.new(1446, 9, 30, UmmAlQura)
    end

    test "Date.new/4 fails for years outside the embedded data" do
      assert {:error, :invalid_date} = Date.new(9999, 1, 1, UmmAlQura)
    end

    test "round-trips a recent Gregorian date" do
      {:ok, gregorian} = Date.new(2024, 6, 15, Calendrical.Gregorian)
      {:ok, hijri} = Date.convert(gregorian, UmmAlQura)
      {:ok, back} = Date.convert(hijri, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "days_in_month returns 29 or 30" do
      for month <- 1..12 do
        days = UmmAlQura.days_in_month(1446, month)
        assert days in [29, 30]
      end
    end

    test "days_in_year returns 354 or 355" do
      assert UmmAlQura.days_in_year(1446) in [354, 355]
    end
  end

  # ─── Structural invariants ─────────────────────────────────────────────────

  describe "structural invariants" do
    test "consecutive months in 1446 AH are 29 or 30 days apart" do
      for month <- 1..11 do
        {:ok, first_of_month} = UmmAlQura.first_day_of_month(1446, month)
        {:ok, first_of_next_month} = UmmAlQura.first_day_of_month(1446, month + 1)

        diff = Date.diff(first_of_next_month, first_of_month)
        assert diff in [29, 30]
      end
    end

    test "1 Muharram of consecutive years are 354–355 days apart" do
      {:ok, start_1445} = UmmAlQura.first_day_of_month(1445, 1)
      {:ok, start_1446} = UmmAlQura.first_day_of_month(1446, 1)

      assert Date.diff(start_1446, start_1445) in 354..355
    end
  end

  # ─── Error handling ───────────────────────────────────────────────────────

  describe "error cases" do
    test "first_day_of_month/2 returns an error for years beyond the dataset" do
      assert {:error, %Calendrical.IslamicYearOutOfRangeError{year: 9999}} =
               UmmAlQura.first_day_of_month(9999, 1)
    end

    test "first_day_of_month/2 returns an error for years before 1 AH" do
      assert {:error, %Calendrical.IslamicYearOutOfRangeError{year: 0}} =
               UmmAlQura.first_day_of_month(0, 1)

      assert {:error, :invalid_date} = Date.new(0, 1, 1, UmmAlQura)
    end

    test "first_day_of_month/2 returns an error for invalid months" do
      assert {:error, %Calendrical.IslamicYearOutOfRangeError{}} =
               UmmAlQura.first_day_of_month(1446, 0)

      assert {:error, %Calendrical.IslamicYearOutOfRangeError{}} =
               UmmAlQura.first_day_of_month(1446, 13)
    end

    test "date_to_iso_days raises for years outside the embedded data" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.date_to_iso_days(9999, 1, 1)
      end
    end

    test "date_from_iso_days raises for ISO days outside the embedded range" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.date_from_iso_days(0)
      end
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

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

      for {month, expected} <- cases do
        {:ok, date} = Date.new(1446, month, 1, UmmAlQura)
        assert Calendrical.localize(date, :month, locale: "en", style: :wide) == expected
      end
    end

    test "abbreviated month names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :month, locale: "en", style: :abbreviated) == "Ram."
    end

    test "Arabic month names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :month, locale: "ar", style: :wide) == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "English day names" do
      # 1 Ramadan 1446 AH = 1 March 2025 (Saturday)
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :day_of_week, locale: "en", style: :wide) == "Saturday"

      assert Calendrical.localize(date, :day_of_week, locale: "en", style: :abbreviated) ==
               "Sat"
    end

    test "Arabic day names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      name = Calendrical.localize(date, :day_of_week, locale: "ar", style: :wide)
      # السبت = "Saturday" in Arabic
      assert name == "السبت"
    end

    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1446, 1, 1, UmmAlQura)
      iso = UmmAlQura.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = UmmAlQura.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, UmmAlQura)
          Calendrical.localize(date, :day_of_week, locale: "en", style: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end

  describe "date_at/2" do
    # 1 March 2025 is 1 Ramadan 1446; sunset (Maghrib) at Mecca that day is
    # 18:25 local (15:25 UTC), so the 18:00 proxy is ~25 minutes early.

    test "defaults to midnight — the ordinary Mecca civil-day mapping" do
      assert UmmAlQura.date_at(~U[2025-03-01 06:00:00Z]) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.UmmAlQura]}

      # 16:00Z = 19:00 Mecca, but midnight ignores the evening.
      assert UmmAlQura.date_at(~U[2025-03-01 16:00:00Z], day_start: :midnight) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.UmmAlQura]}
    end

    test ":evening rolls to the next Hijri day at 18:00 Mecca time" do
      # 15:00Z = 18:00 Mecca exactly — rolls.
      assert UmmAlQura.date_at(~U[2025-03-01 15:00:00Z], day_start: :evening) ==
               {:ok, ~D[1446-09-02 Calendrical.Islamic.UmmAlQura]}

      # 14:59Z = 17:59 Mecca — does not roll.
      assert UmmAlQura.date_at(~U[2025-03-01 14:59:00Z], day_start: :evening) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.UmmAlQura]}
    end

    test ":sunset rolls at true Maghrib, diverging from the 18:00 proxy" do
      # 18:10 Mecca: past the 18:00 proxy but before true sunset (18:25).
      diverge = ~U[2025-03-01 15:10:00Z]

      assert UmmAlQura.date_at(diverge, day_start: :evening) ==
               {:ok, ~D[1446-09-02 Calendrical.Islamic.UmmAlQura]}

      assert UmmAlQura.date_at(diverge, day_start: :sunset) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.UmmAlQura]}

      # After true sunset, both agree.
      assert UmmAlQura.date_at(~U[2025-03-01 16:00:00Z], day_start: :sunset) ==
               {:ok, ~D[1446-09-02 Calendrical.Islamic.UmmAlQura]}
    end

    test "the day boundary is Mecca's, independent of the input time zone" do
      utc = ~U[2025-03-01 16:00:00Z]
      # Same absolute instant expressed as 19:00 in a +03:00 zone.
      riyadh = %{
        ~U[2025-03-01 19:00:00Z]
        | time_zone: "Asia/Riyadh",
          zone_abbr: "+03",
          utc_offset: 10_800,
          std_offset: 0
      }

      assert UmmAlQura.date_at(riyadh, day_start: :sunset) ==
               UmmAlQura.date_at(utc, day_start: :sunset)
    end

    test "returns an error, never raises, on bad input" do
      assert {:error, {:invalid_day_start, :bogus}} =
               UmmAlQura.date_at(~U[2025-03-01 12:00:00Z], day_start: :bogus)

      # Outside the embedded reference data.
      # After 30 Dhu al-Hijja 1500 AH (16 November 2077), the end of the tables.
      assert {:error, _} = UmmAlQura.date_at(~U[2100-01-01 12:00:00Z])
    end
  end
end
