defmodule Calendrical.Islamic.RgsaTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.Rgsa

  alias Calendrical.Islamic.Rgsa

  describe "round-trip conversions" do
    test "round-trips a recent Gregorian date" do
      {:ok, gregorian} = Date.new(2024, 4, 7, Calendrical.Gregorian)
      {:ok, rgsa} = Date.convert(gregorian, Rgsa)
      {:ok, back} = Date.convert(rgsa, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "round-trips 1 Muharram of several recent Hijri years" do
      for year <- 1444..1447 do
        {:ok, h} = Date.new(year, 1, 1, Rgsa)
        {:ok, g} = Date.convert(h, Calendrical.Gregorian)
        {:ok, back} = Date.convert(g, Rgsa)
        assert back.year == year
        assert back.month == 1
        assert back.day == 1
      end
    end
  end

  describe "structural invariants" do
    test "every month is 29 or 30 days long" do
      for year <- [1445, 1446], month <- 1..12 do
        days = Rgsa.days_in_month(year, month)
        assert days in [29, 30]
      end
    end

    test "every year is 354 or 355 days long" do
      for year <- [1445, 1446] do
        assert Rgsa.days_in_year(year) in [354, 355]
      end
    end
  end

  describe "location" do
    test "uses Mecca as the observation point" do
      %Geo.PointZ{coordinates: {lon, lat, _}} = Rgsa.location()
      assert_in_delta lon, 39.8262, 0.001
      assert_in_delta lat, 21.4225, 0.001
    end
  end

  describe "agreement with the tabular Umm al-Qura calendar" do
    test "Rgsa and UmmAlQura agree to within ±2 days for recent months" do
      # The Saudi sighting calendar and the official Umm al-Qura table
      # are computed by different methods (astronomical visibility
      # at Mecca vs published KACST tables) but target the same
      # observed lunar cycle, so they should not differ by more than
      # a day or two.
      for year <- [1445, 1446], month <- [1, 9, 12] do
        {:ok, rgsa} = Date.new(year, month, 1, Rgsa)
        {:ok, umm} = Date.new(year, month, 1, Calendrical.Islamic.UmmAlQura)

        {:ok, rgsa_g} = Date.convert(rgsa, Calendrical.Gregorian)
        {:ok, umm_g} = Date.convert(umm, Calendrical.Gregorian)

        diff = abs(Date.diff(rgsa_g, umm_g))
        assert diff <= 2, "Year #{year} month #{month}: diff #{diff} days"
      end
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names" do
      {:ok, m9} = Date.new(1446, 9, 1, Rgsa)
      assert Calendrical.localize(m9, :month, locale: "en", format: :wide) == "Ramadan"
    end

    test "Arabic month name for Ramadan" do
      {:ok, ramadan} = Date.new(1446, 9, 1, Rgsa)
      assert Calendrical.localize(ramadan, :month, locale: "ar", format: :wide) == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1446, 1, 1, Rgsa)
      iso = Rgsa.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Rgsa.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Rgsa)
          Calendrical.localize(date, :day_of_week, locale: "en", format: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end
end
