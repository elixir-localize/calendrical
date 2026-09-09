defmodule Calendrical.TimeZoneTest do
  @moduledoc """
  Tests for `Calendrical.TimeZone.resolve/3`, which resolves the
  zone strings that appear in parsed date/time input: ISO 8601
  offsets, GMT-style offsets, IANA names, and common
  abbreviations.

  """

  use ExUnit.Case, async: true

  doctest Calendrical.TimeZone

  @naive ~N[2026-07-05 12:00:00]

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
      assert {:error, :invalid_gmt_offset} = Calendrical.TimeZone.resolve("GMT+banana", @naive)
    end

    # Every string beginning `GMT`, `UTC` or `UT` whose remainder was not
    # an offset used to reach a `resolve_iso_offset/2` with no matching
    # clause and raise `FunctionClauseError` — a raise out of a public
    # function, on ordinary caller input.
    test "a GMT-prefixed string that is not an offset returns an error rather than raising" do
      for zone <- ["GMTfoo", "GMT:", "GMT+", "GMT-", "UTCfoo", "UTC:", "UTfoo"] do
        assert {:error, :invalid_gmt_offset} = Calendrical.TimeZone.resolve(zone, @naive)
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

    # `GMT0`, `GMT+0` and `GMT-0` are canonical spellings of UTC listed in
    # `etc_zones/0`, but they carry no `/` so they never reach the IANA
    # branch.
    test "resolves the zero-offset GMT spellings" do
      for zone <- ["GMT0", "GMT+0", "GMT-0", "GMT+00:00", "UTC0"] do
        assert {:ok, %DateTime{utc_offset: 0}} = Calendrical.TimeZone.resolve(zone, @naive)
      end
    end

    test "ISO 8601 offsets still require a two-digit hour" do
      assert {:error, :invalid_offset} = Calendrical.TimeZone.resolve("+5", @naive)
    end

    test "out-of-range offsets are rejected" do
      assert {:error, :invalid_offset} = Calendrical.TimeZone.resolve("+15:00", @naive)
      assert {:error, :invalid_offset} = Calendrical.TimeZone.resolve("+05:75", @naive)
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
               Calendrical.TimeZone.resolve("Pacific Standard Time", @naive)

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
               Calendrical.TimeZone.resolve("Eastern Standard Time", @naive, locale: :"en-CA")
    end

    test "falls back to the golden zone when the locale territory has no mapping" do
      assert {:ok, %DateTime{time_zone: "America/New_York"}} =
               Calendrical.TimeZone.resolve("Eastern Standard Time", @naive, locale: :en)
    end

    test "resolves a non-Latin metazone name" do
      assert {:ok, %DateTime{time_zone: "Asia/Tokyo"}} =
               Calendrical.TimeZone.resolve("日本標準時", @naive, locale: :ja)
    end
  end

  test "tz_database/0 returns the configured database module" do
    assert Calendrical.TimeZone.tz_database() == Tz.TimeZoneDatabase
  end
end
