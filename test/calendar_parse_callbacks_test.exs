defmodule Calendrical.CalendarParseCallbacksTest do
  use ExUnit.Case, async: true

  # The ISO 8601 callbacks a calendar answers `Date.from_iso8601/2` and
  # `NaiveDateTime.from_iso8601/2` with, through `Calendrical.Parse`.

  describe "Calendrical.Parse calendar callbacks" do
    test "parse_date/1 for a month calendar" do
      assert Calendrical.Gregorian.parse_date("2026-05-16") == {:ok, {2026, 5, 16}}
      assert Calendrical.Gregorian.parse_date("-2026-05-16") == {:ok, {-2026, 5, 16}}
      assert Calendrical.Gregorian.parse_date("2026-13-45") == {:error, :invalid_date}
      assert Calendrical.Gregorian.parse_date("nope") == {:error, :invalid_date}
    end

    test "parse_date/1 for a week calendar accepts ISO week syntax" do
      assert Calendrical.ISOWeek.parse_date("2026-W21-6") == {:ok, {2026, 21, 6}}
      assert Calendrical.ISOWeek.parse_date("-2026-W21-6") == {:ok, {-2026, 21, 6}}
    end

    test "parse_naive_datetime/1 via NaiveDateTime.from_iso8601/2" do
      assert NaiveDateTime.from_iso8601("2026-05-16 14:30:00", Calendrical.Gregorian) ==
               {:ok, ~N[2026-05-16 14:30:00 Calendrical.Gregorian]}

      assert NaiveDateTime.from_iso8601("2026-05-16", Calendrical.Gregorian) ==
               {:error, :invalid_format}
    end

    test "parse_utc_datetime/1 offset handling" do
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00Z") ==
               {:ok, {2026, 5, 16, 14, 30, 0, {0, 0}}, 0}

      # Basic-format positive and negative offsets shift the wall time.
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00+0530") ==
               {:ok, {2026, 5, 16, 9, 0, 0, {0, 0}}, 19_800}

      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 01:30:00-0530") ==
               {:ok, {2026, 5, 16, 7, 0, 0, {0, 0}}, -19_800}

      # Hour-only offsets.
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00+05") ==
               {:ok, {2026, 5, 16, 9, 30, 0, {0, 0}}, 18_000}

      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00-05") ==
               {:ok, {2026, 5, 16, 19, 30, 0, {0, 0}}, -18_000}
    end

    test "parse_utc_datetime/1 fractional seconds accept a comma" do
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00,25Z") ==
               {:ok, {2026, 5, 16, 14, 30, 0, {250_000, 2}}, 0}
    end

    test "parse_utc_datetime/1 error paths" do
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 25:30:00Z") ==
               {:error, :invalid_time}

      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00") ==
               {:error, :missing_offset}

      # Fraction marker with no digits, trailing garbage, the
      # explicitly rejected -00:00 offset, and an out-of-range
      # offset minute all fall through to a bare :error.
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00.Z") == :error
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00xyz") == :error
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00-00:00") == :error
      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16 14:30:00+05:99") == :error

      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16") == {:error, :invalid_format}
    end

    test "date_to_iso_days/3 delegates to Calendar.ISO" do
      assert Calendrical.Parse.date_to_iso_days(2026, 5, 16) ==
               Calendar.ISO.date_to_iso_days(2026, 5, 16)
    end
  end
end
