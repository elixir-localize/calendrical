defmodule Calendrical.TimeZoneTest do
  @moduledoc """
  Tests for `Calendrical.TimeZone.resolve/3`, which resolves the
  zone strings that appear in parsed date/time input: ISO 8601
  offsets, GMT-style offsets, IANA names, and common
  abbreviations.

  """

  use ExUnit.Case, async: true

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

  test "tz_database/0 returns the configured database module" do
    assert Calendrical.TimeZone.tz_database() == Tzdata.TimeZoneDatabase
  end
end
