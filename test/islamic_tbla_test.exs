defmodule Calendrical.Islamic.TblaTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.Tbla

  alias Calendrical.Islamic.Tbla

  describe "epoch and round-trip" do
    test "1 Muharram 1 AH is 18 July 622 (proleptic Gregorian)" do
      {:ok, hijri} = Date.new(1, 1, 1, Tbla)
      {:ok, gregorian} = Date.convert(hijri, Calendrical.Gregorian)
      assert gregorian == ~D[0622-07-18 Calendrical.Gregorian]
    end

    test "round-trips a Gregorian date through Tbla" do
      {:ok, gregorian} = Date.new(2024, 1, 1, Calendrical.Gregorian)
      {:ok, hijri} = Date.convert(gregorian, Tbla)
      {:ok, back} = Date.convert(hijri, Calendrical.Gregorian)
      assert back == gregorian
    end
  end

  describe "civil/tbla relationship" do
    test "TBLA is exactly one day ahead of Civil for the same Gregorian date" do
      for {year, month, day} <- [{2024, 1, 1}, {2025, 6, 15}, {1900, 12, 31}, {2000, 2, 29}] do
        {:ok, gregorian} = Date.new(year, month, day, Calendrical.Gregorian)
        {:ok, civil} = Date.convert(gregorian, Calendrical.Islamic.Civil)
        {:ok, tbla} = Date.convert(gregorian, Tbla)

        # Both have the same Hijri ymd structure but tbla is 1 day "ahead"
        # because its epoch is 1 day earlier — the same Gregorian day is
        # interpreted as a Hijri day that is 1 later in the count.
        civil_iso = Calendrical.Islamic.Civil.date_to_iso_days(civil.year, civil.month, civil.day)

        tbla_iso = Tbla.date_to_iso_days(tbla.year, tbla.month, tbla.day)
        assert civil_iso == tbla_iso
      end
    end
  end

  describe "leap_year? agrees with Civil" do
    test "30-year cycle is identical to Civil" do
      for year <- 1..30 do
        assert Tbla.leap_year?(year) == Calendrical.Islamic.Civil.leap_year?(year)
      end
    end
  end

  describe "month name localization" do
    test "English month names" do
      {:ok, muharram} = Date.new(1446, 1, 1, Tbla)
      assert Calendrical.localize(muharram, :month, locale: "en", format: :wide) == "Muharram"

      {:ok, ramadan} = Date.new(1446, 9, 1, Tbla)
      assert Calendrical.localize(ramadan, :month, locale: "en", format: :wide) == "Ramadan"

      {:ok, dhul_hijjah} = Date.new(1446, 12, 1, Tbla)

      assert Calendrical.localize(dhul_hijjah, :month, locale: "en", format: :wide) ==
               "Dhuʻl-Hijjah"
    end

    test "Arabic month names" do
      {:ok, ramadan} = Date.new(1446, 9, 1, Tbla)
      assert Calendrical.localize(ramadan, :month, locale: "ar", format: :wide) == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1446, 1, 1, Tbla)
      iso = Tbla.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Tbla.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Tbla)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
