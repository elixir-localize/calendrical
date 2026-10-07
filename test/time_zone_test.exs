defmodule Calendrical.TimeZoneTest do
  @moduledoc """
  Tests for `Calendrical.TimeZone.resolve/3`, which is Localize's
  `Localize.DateTime.Timezone.resolve/3`: ISO 8601 offsets, GMT-style
  offsets, IANA names, and CLDR's names and abbreviations. A fixed
  offset is a `t:DateTime.t/0` labelled with the offset, and a wall time
  a zone's clocks pass twice is read in standard time, as ICU reads it.

  """

  use ExUnit.Case, async: true

  doctest Calendrical.TimeZone

  @naive ~N[2026-07-05 12:00:00]
  @winter ~N[2026-01-05 12:00:00]

  describe "resolve/3" do
    test "resolves an ISO 8601 offset" do
      assert {:ok, %DateTime{utc_offset: offset}} =
               Calendrical.TimeZone.resolve("+05:30", @naive)

      assert offset == 5 * 3600 + 30 * 60
    end

    test "resolves a negative ISO 8601 offset" do
      assert {:ok, %DateTime{utc_offset: offset}} = Calendrical.TimeZone.resolve("-08:00", @naive)
      assert offset == -8 * 3600
    end

    test "resolves a GMT-style offset" do
      assert {:ok, %DateTime{utc_offset: offset}} =
               Calendrical.TimeZone.resolve("GMT+02:00", @naive)

      assert offset == 2 * 3600
    end

    test "returns an error for a malformed GMT offset" do
      assert {:error, %Localize.UnknownTimezoneError{}} =
               Calendrical.TimeZone.resolve("GMT+banana", @naive)
    end

    # Every string beginning `GMT`, `UTC` or `UT` whose remainder was not
    # an offset used to reach a `resolve_iso_offset/2` with no matching
    # clause and raise `FunctionClauseError` — a raise out of a public
    # function, on ordinary caller input.
    test "a GMT-prefixed string that is not an offset returns an error rather than raising" do
      for zone <- ["GMTfoo", "GMT:", "GMT+", "GMT-", "UTCfoo", "UTC:", "UTfoo"] do
        assert {:error, %Localize.UnknownTimezoneError{}} =
                 Calendrical.TimeZone.resolve(zone, @naive)
      end
    end

    test "trailing whitespace after the literal is a bare GMT" do
      for zone <- ["GMT ", "GMT  ", "UTC ", "UT "] do
        assert {:ok, %DateTime{utc_offset: 0}} = Calendrical.TimeZone.resolve(zone, @naive)
      end
    end

    # `["GMT ", 0]` is the gmtFormat of 14 locales, `ur` and `sw-KE`
    # among them, so a space between literal and offset is ordinary
    # input rather than a typo.
    test "resolves a GMT offset separated from the literal by a space" do
      assert {:ok, %DateTime{utc_offset: 3600}} =
               Calendrical.TimeZone.resolve("GMT +01:00", @naive)
    end

    # CLDR's short gmtFormat renders a one-digit hour, and `cs` and `fi`
    # write `+H:mm` and `+H.mm`.
    test "resolves a one-digit GMT hour" do
      assert {:ok, %DateTime{utc_offset: -28_800}} = Calendrical.TimeZone.resolve("GMT-8", @naive)
      assert {:ok, %DateTime{utc_offset: 10_800}} = Calendrical.TimeZone.resolve("GMT+3", @naive)

      assert {:ok, %DateTime{utc_offset: 19_800}} =
               Calendrical.TimeZone.resolve("GMT+5:30", @naive)

      assert {:ok, %DateTime{utc_offset: 3600}} = Calendrical.TimeZone.resolve("GMT+1.00", @naive)
    end

    # `GMT0`, `GMT+0` and `GMT-0` are IANA's names of UTC, and `UTC0` is the
    # same offset written after the literal: TR35 reads the number of a
    # localized GMT format with "+, -, or nothing" before it, so an unsigned
    # number after the literal is an offset east and no hours of it is UTC.
    test "resolves the zero-offset GMT spellings" do
      for zone <- ["GMT0", "GMT+0", "GMT-0", "GMT+00:00", "UTC0"] do
        assert {:ok, %DateTime{utc_offset: 0}} = Calendrical.TimeZone.resolve(zone, @naive)
      end
    end

    test "ISO 8601 offsets still require a two-digit hour" do
      assert {:error, %Localize.UnknownTimezoneError{}} =
               Calendrical.TimeZone.resolve("+5", @naive)
    end

    # ISO 8601 reaches an offset of 23:59:59, wider than the ±14:00 any
    # IANA zone keeps, so `+15:00` is read where an hour past 23 is not.
    test "out-of-range offsets are rejected" do
      assert {:error, %Localize.UnknownTimezoneError{}} =
               Calendrical.TimeZone.resolve("+24:00", @naive)

      assert {:error, %Localize.UnknownTimezoneError{}} =
               Calendrical.TimeZone.resolve("+05:75", @naive)

      assert {:ok, %DateTime{utc_offset: 54_000}} =
               Calendrical.TimeZone.resolve("+15:00", @naive)
    end

    test "resolves an IANA zone name" do
      assert {:ok, %DateTime{time_zone: "Australia/Sydney"}} =
               Calendrical.TimeZone.resolve("Australia/Sydney", @naive)
    end

    test "resolves a common abbreviation" do
      assert {:ok, %DateTime{} = datetime} = Calendrical.TimeZone.resolve("UTC", @naive)
      assert datetime.utc_offset == 0
    end

    test "returns an error for an unrecognizable zone" do
      assert {:error, _reason} = Calendrical.TimeZone.resolve("Not/AZone", @naive)
    end
  end

  describe "resolve/3 metazone names" do
    test "resolves a metazone name to its golden zone" do
      assert {:ok, %DateTime{time_zone: "America/Los_Angeles"}} =
               Calendrical.TimeZone.resolve("Pacific Standard Time", @winter)

      assert {:ok, %DateTime{time_zone: "Asia/Tokyo"}} =
               Calendrical.TimeZone.resolve("Japan Standard Time", @naive)
    end

    test "resolves a daylight metazone name" do
      assert {:ok, %DateTime{time_zone: "America/Los_Angeles"}} =
               Calendrical.TimeZone.resolve("Pacific Daylight Time", @naive)
    end

    test "resolves a metazone name to the locale territory's representative zone" do
      assert {:ok, %DateTime{time_zone: "Europe/Berlin"}} =
               Calendrical.TimeZone.resolve("Mitteleuropäische Zeit", @naive, locale: :de)

      assert {:ok, %DateTime{time_zone: "America/Toronto"}} =
               Calendrical.TimeZone.resolve("Eastern Standard Time", @winter, locale: :"en-CA")
    end

    test "falls back to the golden zone when the locale territory has no mapping" do
      assert {:ok, %DateTime{time_zone: "America/New_York"}} =
               Calendrical.TimeZone.resolve("Eastern Standard Time", @winter, locale: :en)
    end

    test "resolves a non-Latin metazone name" do
      assert {:ok, %DateTime{time_zone: "Asia/Tokyo"}} =
               Calendrical.TimeZone.resolve("日本標準時", @naive, locale: :ja)
    end
  end

  describe "resolve/3 standard and daylight names" do
    test "a standard name keeps its own offset when the zone keeps daylight time" do
      assert {:ok, datetime} = Calendrical.TimeZone.resolve("EST", @naive)
      assert time_and_label(datetime) == {"2026-07-05 12:00:00-05:00 -05:00 -05:00", "-05:00"}

      assert {:ok, datetime} = Calendrical.TimeZone.resolve("Eastern Standard Time", @naive)
      assert time_and_label(datetime) == {"2026-07-05 12:00:00-05:00 -05:00 -05:00", "-05:00"}
    end

    test "a daylight name keeps its own offset when the zone keeps standard time" do
      assert {:ok, datetime} = Calendrical.TimeZone.resolve("EDT", @winter)
      assert time_and_label(datetime) == {"2026-01-05 12:00:00-04:00 -04:00 -04:00", "-04:00"}

      assert {:ok, datetime} =
               Calendrical.TimeZone.resolve("Mitteleuropäische Sommerzeit", @winter, locale: :de)

      assert time_and_label(datetime) == {"2026-01-05 12:00:00+02:00 +02:00 +02:00", "+02:00"}
    end

    test "is the zone's own time when the zone keeps it" do
      assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EST"}} =
               Calendrical.TimeZone.resolve("EST", @winter)

      assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EDT"}} =
               Calendrical.TimeZone.resolve("EDT", @naive)
    end

    test "a generic name follows the zone" do
      assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EDT"}} =
               Calendrical.TimeZone.resolve("Eastern Time", @naive)
    end

    test "picks the zone's reading of an overlap that keeps the named time" do
      assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EST"}} =
               Calendrical.TimeZone.resolve("EST", ~N[2026-11-01 01:30:00])

      assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EDT"}} =
               Calendrical.TimeZone.resolve("EDT", ~N[2026-11-01 01:30:00])
    end

    test "keeps the wall clock given in a spring-forward gap" do
      assert {:ok, datetime} = Calendrical.TimeZone.resolve("EST", ~N[2026-03-08 02:30:00])
      assert time_and_label(datetime) == {"2026-03-08 02:30:00-05:00 -05:00 -05:00", "-05:00"}
    end

    # 1:30 on 1 November 2026 happened twice in New York, first in daylight
    # time and then in standard time. A form naming neither is read in
    # standard time, as ICU reads it.
    test "reads a wall time a zone passes twice in standard time" do
      for zone <- ["America/New_York", "Eastern Time"] do
        assert {:ok, %DateTime{zone_abbr: "EST", utc_offset: -18_000, std_offset: 0}} =
                 Calendrical.TimeZone.resolve(zone, ~N[2026-11-01 01:30:00])
      end
    end

    test "reads daylight time as the zone's greater offset" do
      # The time zone database may write Europe/Dublin's winter as a
      # negative saving; Irish Standard Time is its summer time.
      assert {:ok, datetime} = Calendrical.TimeZone.resolve("Irish Standard Time", @winter)
      assert time_and_label(datetime) == {"2026-01-05 12:00:00+01:00 +01:00 +01:00", "+01:00"}

      assert {:ok, %DateTime{time_zone: "Europe/Dublin", zone_abbr: "IST"}} =
               Calendrical.TimeZone.resolve("Irish Standard Time", @naive)
    end
  end

  test "tz_database/0 returns the configured database module" do
    assert Calendrical.TimeZone.tz_database() == Tz.TimeZoneDatabase
  end

  # The wall clock with its offset, and the label a fixed offset carries in
  # place of a zone. A fixed offset's zone is the offset itself, as Localize
  # reads one, and its abbreviation is that same string, so `to_string/1`
  # writes the offset, then the abbreviation and the zone after it, the shape
  # `Calendar.ISO` gives every zone that is not UTC.
  defp time_and_label(datetime), do: {to_string(datetime), datetime.zone_abbr}
end
