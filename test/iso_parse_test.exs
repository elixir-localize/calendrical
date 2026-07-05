defmodule Calendrical.IsoParseTest do
  @moduledoc """
  Tests for `Calendrical.Parse`, the ISO-8601-shaped parser behind
  every Behaviour calendar's `parse_date/1`, `parse_naive_datetime/1`
  and `parse_utc_datetime/1` callbacks (and therefore behind the
  `~D`/`~N`/`~U` sigils for those calendars).

  The Coptic calendar is used as the exercising calendar: it is
  arithmetic (no astronomy), supports a wide year range, and takes
  its parsing from `Calendrical.Parse` unmodified.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Parse

  @calendar Calendrical.Coptic

  describe "parse_date/2" do
    test "parses a valid date" do
      assert Parse.parse_date("1742-01-01", @calendar) == {:ok, {1742, 1, 1}}
    end

    test "parses a negative year" do
      assert Parse.parse_date("-0100-03-15", @calendar) == {:ok, {-100, 3, 15}}
    end

    test "rejects a date that is invalid in the calendar" do
      # Coptic month 13 has 5 days (6 in leap years); day 30 never exists.
      assert Parse.parse_date("1742-13-30", @calendar) == {:error, :invalid_date}
    end

    test "rejects malformed input" do
      assert Parse.parse_date("not a date", @calendar) == {:error, :invalid_date}
      assert Parse.parse_date("1742/01/01", @calendar) == {:error, :invalid_date}
      assert Parse.parse_date("", @calendar) == {:error, :invalid_date}
    end

    test "drives the ~D sigil for Behaviour calendars" do
      # The sigil parses via calendar.parse_date/1 (calendar-native
      # fields), unlike Date.from_iso8601/2 which parses as
      # Calendar.ISO and then converts.
      assert @calendar.parse_date("1742-01-01") == {:ok, {1742, 1, 1}}
      assert ~D[1742-01-01 Calendrical.Coptic].year == 1742
    end
  end

  describe "parse_week_date/2" do
    test "parses a week-formatted date" do
      assert Parse.parse_week_date("2026-W15-3", Calendrical.ISOWeek) == {:ok, {2026, 15, 3}}
    end

    test "parses a negative week-formatted year" do
      assert {:ok, {-100, 15, 3}} = Parse.parse_week_date("-0100-W15-3", Calendrical.ISOWeek)
    end

    test "falls back to plain date parsing without the W marker" do
      assert Parse.parse_week_date("1742-01-01", @calendar) == {:ok, {1742, 1, 1}}
    end
  end

  describe "parse_naive_datetime/2" do
    test "parses with a space separator" do
      assert Parse.parse_naive_datetime("1742-01-01 10:30:00", @calendar) ==
               {:ok, {1742, 1, 1, 10, 30, 0, {0, 0}}}
    end

    test "parses with a T separator" do
      assert Parse.parse_naive_datetime("1742-01-01T10:30:00", @calendar) ==
               {:ok, {1742, 1, 1, 10, 30, 0, {0, 0}}}
    end

    test "rejects input without a time part" do
      assert Parse.parse_naive_datetime("1742-01-01", @calendar) == {:error, :invalid_format}
    end
  end

  describe "parse_utc_datetime/2" do
    test "parses a Zulu datetime" do
      assert Parse.parse_utc_datetime("1742-01-01 10:30:00Z", @calendar) ==
               {:ok, {1742, 1, 1, 10, 30, 0, {0, 0}}, 0}
    end

    test "parses fractional seconds with dot and comma" do
      assert {:ok, {1742, 1, 1, 10, 30, 0, {123_456, 6}}, 0} =
               Parse.parse_utc_datetime("1742-01-01 10:30:00.123456Z", @calendar)

      assert {:ok, {1742, 1, 1, 10, 30, 0, {500_000, 1}}, 0} =
               Parse.parse_utc_datetime("1742-01-01 10:30:00,5Z", @calendar)
    end

    test "truncates fractional seconds beyond microsecond precision" do
      assert {:ok, {_, _, _, _, _, _, {123_456, 6}}, 0} =
               Parse.parse_utc_datetime("1742-01-01 10:30:00.1234567Z", @calendar)
    end

    test "normalizes a positive offset into UTC" do
      # 01:30 at +02:00 is 23:30 the previous day in UTC.
      assert {:ok, {1741, 13, 5, 23, 30, 0, {0, 0}}, 7200} =
               Parse.parse_utc_datetime("1742-01-01 01:30:00+02:00", @calendar)
    end

    test "normalizes a negative offset into UTC" do
      # 23:30 at -02:00 is 01:30 the next day in UTC.
      assert {:ok, {1742, 1, 2, 1, 30, 0, {0, 0}}, -7200} =
               Parse.parse_utc_datetime("1742-01-01 23:30:00-02:00", @calendar)
    end

    test "accepts compact and hour-only offsets" do
      assert {:ok, _fields, 19_800} =
               Parse.parse_utc_datetime("1742-01-01 10:30:00+0530", @calendar)

      assert {:ok, _fields, -18_000} =
               Parse.parse_utc_datetime("1742-01-01 10:30:00-05", @calendar)
    end

    test "rejects a missing offset" do
      assert Parse.parse_utc_datetime("1742-01-01 10:30:00", @calendar) ==
               {:error, :missing_offset}
    end

    test "rejects the -00:00 offset and out-of-range offsets" do
      assert Parse.parse_utc_datetime("1742-01-01 10:30:00-00:00", @calendar) in [
               :error,
               {:error, :invalid_format}
             ]

      assert Parse.parse_utc_datetime("1742-01-01 10:30:00+25:00", @calendar) in [
               :error,
               {:error, :invalid_format}
             ]
    end

    test "rejects input without a time part" do
      assert Parse.parse_utc_datetime("1742-01-01", @calendar) == {:error, :invalid_format}
    end
  end
end
