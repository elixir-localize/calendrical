defmodule Calendrical.Coverage.TimeZoneIslamicTest do
  @moduledoc """
  Coverage tests for `Calendrical.TimeZone`, `Calendrical.Islamic.Visibility`
  and `Calendrical.Islamic.UmmAlQura` (including the astronomical rule module).

  All expected values in this file were probed by executing the functions
  on the development toolchain before being asserted here.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Islamic.UmmAlQura
  alias Calendrical.Islamic.UmmAlQura.Astronomical
  alias Calendrical.Islamic.Visibility
  alias Calendrical.TimeZone

  @july ~N[2026-07-05 12:00:00]
  @january ~N[2026-01-15 12:00:00]

  # ── TimeZone — common abbreviations ──────────────────────────────

  describe "TimeZone.resolve/3 with common abbreviations" do
    test "PST resolves to America/Los_Angeles and honours DST in July" do
      assert {:ok, %DateTime{time_zone: "America/Los_Angeles", zone_abbr: "PDT"} = dt} =
               TimeZone.resolve("PST", @july)

      assert dt.utc_offset + dt.std_offset == -7 * 3600
    end

    test "PST resolves to standard time in January" do
      assert {:ok, %DateTime{time_zone: "America/Los_Angeles", zone_abbr: "PST"} = dt} =
               TimeZone.resolve("PST", @january)

      assert dt.utc_offset + dt.std_offset == -8 * 3600
    end

    test "JST resolves to Asia/Tokyo at +09:00" do
      assert {:ok, %DateTime{time_zone: "Asia/Tokyo", zone_abbr: "JST"} = dt} =
               TimeZone.resolve("JST", @july)

      assert dt.utc_offset == 9 * 3600
    end

    test "IST resolves to Asia/Kolkata at +05:30" do
      assert {:ok, %DateTime{time_zone: "Asia/Kolkata"} = dt} = TimeZone.resolve("IST", @july)
      assert dt.utc_offset == 5 * 3600 + 30 * 60
    end

    test "BST resolves to Europe/London" do
      assert {:ok, %DateTime{time_zone: "Europe/London", zone_abbr: "BST"} = dt} =
               TimeZone.resolve("BST", @july)

      assert dt.utc_offset + dt.std_offset == 3600
    end

    test "EST resolves to America/New_York" do
      assert {:ok, %DateTime{time_zone: "America/New_York"}} = TimeZone.resolve("EST", @january)
    end

    test "CET resolves to Europe/Berlin" do
      assert {:ok, %DateTime{time_zone: "Europe/Berlin"}} = TimeZone.resolve("CET", @january)
    end

    test "NZST resolves to Pacific/Auckland" do
      assert {:ok, %DateTime{time_zone: "Pacific/Auckland"}} = TimeZone.resolve("NZST", @july)
    end
  end

  # ── TimeZone — GMT / UTC / UT formats ────────────────────────────

  describe "TimeZone.resolve/3 with GMT/UTC/UT formats" do
    test "bare GMT resolves to UTC" do
      assert {:ok, %DateTime{utc_offset: 0, zone_abbr: "UTC"}} = TimeZone.resolve("GMT", @july)
    end

    test "bare UT resolves to UTC" do
      assert {:ok, %DateTime{utc_offset: 0, zone_abbr: "UTC"}} = TimeZone.resolve("UT", @july)
    end

    test "bare UTC resolves to UTC" do
      assert {:ok, %DateTime{utc_offset: 0, zone_abbr: "UTC"}} = TimeZone.resolve("UTC", @july)
    end

    test "UT+01 resolves to a one-hour offset" do
      assert {:ok, %DateTime{utc_offset: 3600}} = TimeZone.resolve("UT+01", @july)
    end

    test "UTC-05:30 resolves to a negative offset" do
      assert {:ok, %DateTime{utc_offset: offset}} = TimeZone.resolve("UTC-05:30", @july)
      assert offset == -(5 * 3600 + 30 * 60)
    end

    test "UTC+banana is an invalid GMT offset" do
      assert {:error, :invalid_gmt_offset} = TimeZone.resolve("UTC+banana", @july)
    end
  end

  # ── TimeZone — ISO offsets ───────────────────────────────────────

  describe "TimeZone.resolve/3 with ISO 8601 offsets" do
    test "Z resolves to UTC" do
      assert {:ok, %DateTime{utc_offset: 0, time_zone: "UTC", zone_abbr: "UTC"}} =
               TimeZone.resolve("Z", @july)
    end

    test "fractional offset +05:45 (Nepal) resolves" do
      assert {:ok, %DateTime{utc_offset: offset} = dt} = TimeZone.resolve("+05:45", @july)
      assert offset == 5 * 3600 + 45 * 60
      assert dt.zone_abbr == "+05:45"
    end

    test "hour-only offset +05 resolves" do
      assert {:ok, %DateTime{utc_offset: offset}} = TimeZone.resolve("+05", @july)
      assert offset == 5 * 3600
    end

    test "six-digit offset +053015 resolves including seconds" do
      assert {:ok, %DateTime{utc_offset: offset}} = TimeZone.resolve("+053015", @july)
      assert offset == 5 * 3600 + 30 * 60 + 15
    end

    test "colon-separated offset with seconds +05:30:15 resolves" do
      assert {:ok, %DateTime{utc_offset: offset}} = TimeZone.resolve("+05:30:15", @july)
      assert offset == 5 * 3600 + 30 * 60 + 15
    end

    test "negative sub-hour offset -00:30 resolves" do
      assert {:ok, %DateTime{utc_offset: -1800}} = TimeZone.resolve("-00:30", @july)
    end

    test "single-digit offset +5 is invalid" do
      assert {:error, :invalid_offset} = TimeZone.resolve("+5", @july)
    end

    test "non-numeric offset +ab is invalid" do
      assert {:error, :invalid_offset} = TimeZone.resolve("+ab", @july)
    end

    test "minutes greater than 59 are rejected" do
      assert {:error, :invalid_offset} = TimeZone.resolve("+05:99", @july)
      assert {:error, :invalid_offset} = TimeZone.resolve("+15:00", @july)
    end
  end

  # ── TimeZone — CLDR locale-name path ─────────────────────────────

  describe "TimeZone.resolve/3 with CLDR locale names" do
    # These exercise resolve_locale_name/3, lookup_cldr_zone_name/2,
    # find_zone_id/2, find_in_branch/3 and name_matches?/2. CLDR ids
    # are lowercased in the data; resolve/3 canonicalizes them against
    # the tz database's zone list.

    test "a CLDR long daylight name resolves" do
      assert {:ok, %DateTime{time_zone: "Europe/London"}} =
               TimeZone.resolve("British Summer Time", @july)
    end

    test "a CLDR long standard name resolves" do
      assert {:ok, %DateTime{utc_offset: 0}} =
               TimeZone.resolve("Coordinated Universal Time", @july)
    end

    test "an explicit :locale option is honoured for the CLDR scan" do
      assert {:ok, %DateTime{time_zone: "Europe/Dublin"}} =
               TimeZone.resolve("Irish Standard Time", @july, locale: :en)
    end

    test "a lowercase IANA id canonicalizes" do
      assert {:ok, %DateTime{time_zone: "Europe/London"}} =
               TimeZone.resolve("europe/london", @july)
    end

    test "an unknown locale falls back cleanly" do
      assert {:error, :unresolvable_zone} =
               TimeZone.resolve("Coordinated Universal Time", @july, locale: :zz)
    end

    test "a name that matches no CLDR entry is unresolvable" do
      assert {:error, :unresolvable_zone} =
               TimeZone.resolve("Middle Earth Time", @july, locale: :fr)
    end
  end

  # ── Islamic.Visibility ───────────────────────────────────────────

  @cairo %Geo.PointZ{coordinates: {31.3, 30.1, 200.0}}
  @mecca %Geo.PointZ{coordinates: {39.8262, 21.4225, 277.0}}

  # Ramadan 1446 AH began on 2025-03-01 in Egypt and Saudi Arabia: the new
  # moon fell at 00:45 UTC on 2025-02-28 and the crescent could be seen that
  # evening, the eve of 1 Ramadan.
  @ramadan_start Date.to_gregorian_days(~D[2025-03-01])
  @new_moon_day Date.to_gregorian_days(~D[2025-02-28])
  @mid_month Date.to_gregorian_days(~D[2025-03-15])

  describe "Visibility.visible_crescent?/3" do
    test "the crescent is visible at Cairo on the eve of 2025-03-01" do
      assert Visibility.visible_crescent?(@ramadan_start, @cairo)
      assert Visibility.visible_crescent?(@ramadan_start, @cairo, :odeh)
      assert Visibility.visible_crescent?(@ramadan_start, @cairo, :schaefer)
    end

    test "Yallop's criterion, stricter for a young moon, does not see it yet" do
      refute Visibility.visible_crescent?(@ramadan_start, @cairo, :yallop)
    end

    test "the eve of a date is the evening before it, not the evening of it" do
      # Astro reports the crescent for the evening of the date it is given:
      # visible on the evening of 2025-02-28, so on the eve of 1 March, and
      # not on the eve of 28 February.
      assert {:ok, class} = Astro.new_visible_crescent(@cairo, ~D[2025-02-28])
      assert class in [:A, :B, :C]
      refute Visibility.visible_crescent?(@new_moon_day, @cairo)
      assert Visibility.visible_crescent?(@ramadan_start, @cairo)
    end
  end

  describe "Visibility.phasis_on_or_before/3" do
    test "finds the month start" do
      for method <- [:odeh, :schaefer] do
        assert Date.from_gregorian_days(
                 Visibility.phasis_on_or_before(@ramadan_start, @cairo, method)
               ) == ~D[2025-03-01],
               "expected 2025-03-01 for method #{method}"
      end
    end

    test "under Yallop's criterion 2025-03-01 still belongs to the previous month" do
      assert Date.from_gregorian_days(
               Visibility.phasis_on_or_before(@ramadan_start, @cairo, :yallop)
             ) == ~D[2025-01-31]
    end

    test "mid-month dates fall back to the month start" do
      assert Date.from_gregorian_days(Visibility.phasis_on_or_before(@mid_month, @cairo)) ==
               ~D[2025-03-01]
    end

    test "a date just after the new moon belongs to the previous month" do
      # 2025-02-28 is within 3 days of the conjunction and its eve shows no
      # crescent, so the containing lunar month started ~30 days earlier
      # (Sha'ban began 2025-01-31).
      assert Date.from_gregorian_days(Visibility.phasis_on_or_before(@new_moon_day, @cairo)) ==
               ~D[2025-01-31]
    end
  end

  describe "Visibility.phasis_on_or_after/3" do
    test "the first day of a month is its own phasis" do
      assert Date.from_gregorian_days(Visibility.phasis_on_or_after(@ramadan_start, @mecca)) ==
               ~D[2025-03-01]
    end

    test "mid-month dates advance to the next month start" do
      # Eid al-Fitr was announced for 2025-03-30, but the Shawwal crescent
      # could first be seen at Cairo on the evening of the 30th.
      assert Date.from_gregorian_days(Visibility.phasis_on_or_after(@mid_month, @cairo)) ==
               ~D[2025-03-31]
    end
  end

  describe "observational calendars for modern dates" do
    test "2025-03-01 is 1 Ramadan 1446 in the Cairo and Mecca calendars" do
      for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa] do
        assert {:ok, date} = Date.convert(~D[2025-03-01], calendar)
        assert {date.year, date.month, date.day} == {1446, 9, 1}
      end
    end

    test "a month begins the day after its crescent can first be seen, not when announced" do
      # Ramadan 1445 was announced for 2024-03-11 in Egypt and Saudi Arabia,
      # but the new moon, at 09:00 UTC on 2024-03-10, left no crescent to see
      # at Cairo or Mecca until the evening of the 11th.
      for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa] do
        assert {:ok, date} = Date.convert(~D[2024-03-12], calendar)
        assert {date.year, date.month, date.day} == {1445, 9, 1}
      end
    end

    test "observational dates round-trip back to Gregorian" do
      {:ok, observational} = Date.convert(~D[2025-03-01], Calendrical.Islamic.Observational)

      assert Date.convert(observational, Calendrical.Gregorian) ==
               {:ok, ~D[2025-03-01 Calendrical.Gregorian]}
    end
  end

  # ── Islamic.UmmAlQura — reference-data paths ─────────────────────

  describe "UmmAlQura reference data" do
    test "embedded data covers 1..1500 AH" do
      assert UmmAlQura.min_year() == 1
      assert UmmAlQura.max_year() == 1500
    end

    test "first_day_of_month/2 returns the published Gregorian date" do
      assert UmmAlQura.first_day_of_month(1446, 9) == {:ok, ~D[2025-03-01]}
    end

    test "first_day_of_month/2 rejects out-of-range years" do
      assert {:error, %Calendrical.IslamicYearOutOfRangeError{} = error} =
               UmmAlQura.first_day_of_month(1501, 1)

      assert error.year == 1501
      assert error.min_year == 1
      assert error.max_year == 1500
    end

    test "first_day_of_month/2 rejects invalid months" do
      assert {:error, %Calendrical.IslamicYearOutOfRangeError{year: nil}} =
               UmmAlQura.first_day_of_month(1446, 13)
    end

    test "valid_date?/3 follows the published month lengths" do
      # Ramadan 1446 has 29 days in the Umm al-Qura tables.
      assert UmmAlQura.valid_date?(1446, 9, 29)
      refute UmmAlQura.valid_date?(1446, 9, 30)
      refute UmmAlQura.valid_date?(0, 1, 1)
      refute UmmAlQura.valid_date?(1446, 13, 1)
    end

    test "leap_year?/1 identifies 355-day years" do
      assert Enum.filter(1440..1450, &UmmAlQura.leap_year?/1) == [1441, 1443, 1447, 1448]
    end

    test "leap_year?/1 is false outside the data range" do
      refute UmmAlQura.leap_year?(UmmAlQura.max_year() + 5)
    end

    test "days_in_month/2 returns 29 or 30 per the tables" do
      assert UmmAlQura.days_in_month(1446, 9) == 29
      assert UmmAlQura.days_in_month(UmmAlQura.max_year(), 12) == 30
    end

    test "days_in_month/2 raises outside the data range" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.days_in_month(9999, 1)
      end
    end

    test "days_in_year/1 returns 354 or 355" do
      assert UmmAlQura.days_in_year(1446) == 354
      assert UmmAlQura.days_in_year(UmmAlQura.max_year()) == 354
    end

    test "days_in_year/1 raises outside the data range" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.days_in_year(9999)
      end
    end

    test "date_to_iso_days/3 and date_from_iso_days/1 round-trip" do
      iso_days = UmmAlQura.date_to_iso_days(1446, 9, 1)
      assert Date.from_gregorian_days(iso_days) == ~D[2025-03-01]

      assert UmmAlQura.date_from_iso_days(UmmAlQura.date_to_iso_days(1446, 9, 15)) ==
               {1446, 9, 15}
    end

    test "date_to_iso_days/3 raises outside the data range" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.date_to_iso_days(9999, 1, 1)
      end
    end

    test "date_from_iso_days/1 raises outside the data range" do
      assert_raise Calendrical.IslamicYearOutOfRangeError, fn ->
        UmmAlQura.date_from_iso_days(0)
      end
    end

    test "Umm al-Qura dates work through the Date API" do
      assert {:ok, date} = Date.new(1446, 9, 1, Calendrical.Islamic.UmmAlQura)

      assert Date.convert(date, Calendrical.Gregorian) ==
               {:ok, ~D[2025-03-01 Calendrical.Gregorian]}
    end
  end

  # ── Islamic.UmmAlQura — astronomical paths ───────────────────────

  describe "UmmAlQura.Astronomical.first_day_of_month/2" do
    test "Era 4 (1423 AH onward) applies the full Umm al-Qura rule" do
      assert Astronomical.first_day_of_month(1446, 9) == {:ok, ~D[2025-03-01]}
    end

    test "Era 3 (1420-1422 AH) applies the moonset-only rule" do
      assert Astronomical.first_day_of_month(1421, 1) == {:ok, ~D[2000-04-06]}
    end

    test "Era 2 (1392-1419 AH) applies the conjunction rule" do
      assert Astronomical.first_day_of_month(1400, 9) == {:ok, ~D[1980-07-13]}
    end

    test "years before 1392 AH are rejected" do
      assert Astronomical.first_day_of_month(1391, 1) == {:error, :year_out_of_range}
    end

    test "invalid months are rejected" do
      assert Astronomical.first_day_of_month(1446, 13) == {:error, :year_out_of_range}
    end
  end

  describe "UmmAlQura.Astronomical.evaluate_era_4_conditions/1" do
    test "returns the full astronomical evaluation for a month boundary" do
      assert {:ok, evaluation} = Astronomical.evaluate_era_4_conditions(~D[2025-02-28])

      assert evaluation.date == ~D[2025-02-28]
      assert evaluation.conjunction_before_sunset?
      assert evaluation.moonset_after_sunset?
      assert evaluation.new_month_starts_next_day?
      assert %DateTime{} = evaluation.conjunction_utc
      assert %DateTime{} = evaluation.sunset_mecca
      assert %DateTime{} = evaluation.moonset_mecca
      assert DateTime.compare(evaluation.moonset_mecca, evaluation.sunset_mecca) == :gt
    end
  end
end
