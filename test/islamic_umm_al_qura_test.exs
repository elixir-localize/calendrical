defmodule Calendrical.Islamic.UmmAlQuraTest do
  @moduledoc """
  Tests for `Calendrical.Islamic.UmmAlQura`.

  All expected dates are taken directly from
  `Calendrical.Islamic.UmmAlQura.ReferenceData.umm_al_qura_dates/0`,
  which encodes the official Umm al-Qura tables published by KACST and
  cross-referenced against the dataset maintained by R.H. van Gent
  (Utrecht University).

  Because the implementation embeds the official data at compile time,
  the test suite asserts 100 % accuracy with no tolerance for off-by-one
  errors.
  """

  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.UmmAlQura

  alias Calendrical.Islamic.UmmAlQura
  alias Calendrical.Islamic.UmmAlQura.ReferenceData

  # ─── Full-dataset validation ───────────────────────────────────────────────

  test "first_day_of_month/2 is correct for every entry in the official dataset" do
    reference_data = ReferenceData.umm_al_qura_dates()

    assert length(reference_data) > 0,
           "Reference data must not be empty"

    failures =
      Enum.reduce(reference_data, [], fn %{
                                           hijri_year: year,
                                           hijri_month: month,
                                           gregorian: expected
                                         },
                                         acc ->
        case UmmAlQura.first_day_of_month(year, month) do
          {:ok, ^expected} ->
            acc

          {:ok, actual} ->
            [
              "#{year}/#{month}: expected #{Date.to_iso8601(expected)}, got #{Date.to_iso8601(actual)}"
              | acc
            ]

          {:error, reason} ->
            [
              "#{year}/#{month}: expected #{Date.to_iso8601(expected)}, got error #{inspect(reason)}"
              | acc
            ]
        end
      end)

    if failures != [] do
      flunk("""
      #{length(failures)} of #{length(reference_data)} reference entries failed:

        #{failures |> Enum.reverse() |> Enum.join("\n  ")}
      """)
    end
  end

  test "round-trips every Hijri date through Gregorian and back" do
    reference_data =
      ReferenceData.umm_al_qura_dates()
      |> Enum.filter(fn %{hijri_year: y} -> y <= UmmAlQura.max_year() end)

    for %{hijri_year: y, hijri_month: m} <- reference_data do
      {:ok, hijri} = Date.new(y, m, 1, UmmAlQura)
      {:ok, gregorian} = Date.convert(hijri, Calendrical.Gregorian)
      {:ok, back} = Date.convert(gregorian, UmmAlQura)
      assert back == hijri
    end
  end

  # ─── Spot checks ───────────────────────────────────────────────────────────

  describe "Era 1 (1356–1419 AH) spot checks" do
    test "1 Muharram 1356 AH = 14 March 1937 (dataset start)" do
      assert {:ok, ~D[1937-03-14]} = UmmAlQura.first_day_of_month(1356, 1)
    end

    test "1 Muharram 1392 AH = 16 February 1972" do
      assert {:ok, ~D[1972-02-16]} = UmmAlQura.first_day_of_month(1392, 1)
    end

    test "1 Ramadan 1400 AH = 13 July 1980" do
      assert {:ok, ~D[1980-07-13]} = UmmAlQura.first_day_of_month(1400, 9)
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
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected
      end
    end

    test "abbreviated month names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :month, locale: "en", format: :abbreviated) == "Ram."
    end

    test "Arabic month names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :month, locale: "ar", format: :wide) == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "English day names" do
      # 1 Ramadan 1446 AH = 1 March 2025 (Saturday)
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :wide) == "Saturday"

      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated) ==
               "Sat"
    end

    test "Arabic day names" do
      {:ok, date} = Date.new(1446, 9, 1, UmmAlQura)
      name = Calendrical.localize(date, :day_of_week, locale: "ar", format: :wide)
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
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
