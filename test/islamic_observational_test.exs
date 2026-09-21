defmodule Calendrical.Islamic.ObservationalTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Islamic.Observational

  alias Calendrical.Islamic.Observational

  describe "round-trip conversions" do
    test "round-trips a recent Gregorian date" do
      {:ok, gregorian} = Date.new(2024, 4, 7, Calendrical.Gregorian)
      {:ok, observational} = Date.convert(gregorian, Observational)
      {:ok, back} = Date.convert(observational, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "round-trips 1 Muharram of several recent Hijri years" do
      for year <- 1444..1448 do
        {:ok, h} = Date.new(year, 1, 1, Observational)
        {:ok, g} = Date.convert(h, Calendrical.Gregorian)
        {:ok, back} = Date.convert(g, Observational)
        assert back.year == year
        assert back.month == 1
        assert back.day == 1
      end
    end
  end

  describe "structural invariants" do
    test "every month is 29 or 30 days long" do
      for year <- [1445, 1446, 1447], month <- 1..12 do
        days = Observational.days_in_month(year, month)
        assert days in [29, 30]
      end
    end

    test "every year is 354 or 355 days long" do
      for year <- [1445, 1446, 1447] do
        assert Observational.days_in_year(year) in [354, 355]
      end
    end

    test "consecutive 1 Muharram are days_in_year apart" do
      for year <- [1445, 1446] do
        {:ok, this} = Date.new(year, 1, 1, Observational)
        {:ok, next} = Date.new(year + 1, 1, 1, Observational)
        assert Date.diff(next, this) == Observational.days_in_year(year)
      end
    end
  end

  describe "agreement with the tabular Civil calendar" do
    @tag :slow
    test "the observational and civil calendars agree to within ±2 days" do
      # The observational and tabular calendars use different methods
      # but should never disagree by more than a couple of days because
      # both target the same lunar cycle.
      for year <- [1445, 1446], month <- [1, 6, 9, 12] do
        {:ok, obs} = Date.new(year, month, 1, Observational)
        {:ok, civ} = Date.new(year, month, 1, Calendrical.Islamic.Civil)

        {:ok, obs_g} = Date.convert(obs, Calendrical.Gregorian)
        {:ok, civ_g} = Date.convert(civ, Calendrical.Gregorian)

        diff = abs(Date.diff(obs_g, civ_g))
        assert diff <= 2, "Year #{year} month #{month}: diff #{diff} days"
      end
    end
  end

  describe "location" do
    test "uses Cairo as the canonical observation point" do
      %Geo.PointZ{coordinates: {lon, lat, _}} = Observational.location()
      assert_in_delta lon, 31.3, 0.01
      assert_in_delta lat, 30.1, 0.01
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names" do
      {:ok, m1} = Date.new(1446, 1, 1, Observational)

      assert Calendrical.localize(m1, :month, locale: "en", style: :wide) ==
               "Muharram"

      {:ok, m9} = Date.new(1446, 9, 1, Observational)

      assert Calendrical.localize(m9, :month, locale: "en", style: :wide) ==
               "Ramadan"
    end

    test "Arabic month name for Ramadan" do
      {:ok, ramadan} = Date.new(1446, 9, 1, Observational)
      assert Calendrical.localize(ramadan, :month, locale: "ar", style: :wide) == "رمضان"
    end
  end

  describe "day-of-week localization" do
    test "all 7 days of the week are localized" do
      {:ok, start} = Date.new(1446, 1, 1, Observational)
      iso = Observational.date_to_iso_days(start.year, start.month, start.day)

      names =
        for offset <- 0..6 do
          {y, m, d} = Observational.date_from_iso_days(iso + offset)
          {:ok, date} = Date.new(y, m, d, Observational)
          Calendrical.localize(date, :day_of_week, locale: "en", style: :abbreviated)
        end

      assert Enum.sort(names) == ~w[Fri Mon Sat Sun Thu Tue Wed]
    end
  end

  describe "date_at/2" do
    test "defaults to midnight (the ordinary civil-day mapping)" do
      assert Observational.date_at(~U[2025-03-01 06:00:00Z]) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.Observational]}
    end

    test ":sunset uses true Maghrib at Cairo, which here precedes the 18:00 proxy" do
      # Cairo sunset on 2025-03-01 is 17:53 local; at 17:55 the astronomical
      # boundary has rolled but the 18:00 proxy has not — they diverge.
      diverge = ~U[2025-03-01 15:55:00Z]

      assert Observational.date_at(diverge, day_start: :evening) ==
               {:ok, ~D[1446-09-01 Calendrical.Islamic.Observational]}

      assert Observational.date_at(diverge, day_start: :sunset) ==
               {:ok, ~D[1446-09-02 Calendrical.Islamic.Observational]}
    end

    test "returns an error, never raises, on bad input or an unsupported range" do
      assert {:error, {:invalid_day_start, :bogus}} =
               Observational.date_at(~U[2025-03-01 12:00:00Z], day_start: :bogus)

      assert {:error, _} =
               Observational.date_at(~U[1700-01-01 06:00:00Z], day_start: :sunset)
    end
  end
end
