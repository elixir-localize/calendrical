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

    # A field that is not digits is no date, as `Calendar.ISO` answers it,
    # where the field raised `ArgumentError`.
    test "parse_date/1 answers fields that are not digits with an error" do
      assert Calendrical.Gregorian.parse_date("2026-0a-16") == {:error, :invalid_format}
      assert Calendrical.Gregorian.parse_date("abcd-05-16") == {:error, :invalid_format}
      assert Calendrical.Gregorian.parse_date("-abcd-05-16") == {:error, :invalid_format}
      assert Calendrical.ISOWeek.parse_date("2026-W2a-6") == {:error, :invalid_format}
      assert Calendrical.NRF.parse_date("2026-W21-x") == {:error, :invalid_format}
      assert Calendar.ISO.parse_date("2026-0a-16") == {:error, :invalid_format}
    end

    # A year before 0 is checked as itself: Coptic year 3 is a leap year
    # with a sixth epagomenal day and year -3 is not.
    test "parse_date/1 checks a negative year's date in that year" do
      assert Calendrical.Coptic.parse_date("0003-13-06") == {:ok, {3, 13, 6}}
      assert Calendrical.Coptic.parse_date("-0003-13-06") == {:error, :invalid_date}
    end

    # A week date is written as ISO 8601 writes one, the year as
    # `Calendar.ISO` writes it, so it reads back for any year.
    test "a week calendar writes a date it reads back" do
      for {year, week, day, text} <- [
            {4, 9, 7, "0004-W09-7"},
            {-44, 11, 4, "-0044-W11-4"},
            {2026, 25, 2, "2026-W25-2"}
          ],
          calendar <- [Calendrical.ISOWeek, Calendrical.NRF] do
        assert calendar.date_to_string(year, week, day) == text
        assert calendar.parse_date(text) == {:ok, {year, week, day}}
      end

      assert inspect(~D[0004-W09-7 Calendrical.ISOWeek]) == "~D[0004-W09-7 Calendrical.ISOWeek]"
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
      # explicitly rejected -00:00 offset, an out-of-range offset
      # minute and a time that is not one are invalid formats, as
      # `Calendar.ISO.parse_utc_datetime/1` answers them.
      for text <- [
            "2026-05-16 14:30:00.Z",
            "2026-05-16 14:30:00xyz",
            "2026-05-16 14:30:00-00:00",
            "2026-05-16 14:30:00+05:99",
            "2026-05-16 1x:30:00Z"
          ] do
        assert Calendrical.Gregorian.parse_utc_datetime(text) == {:error, :invalid_format}, text
      end

      assert Calendrical.Gregorian.parse_utc_datetime("2026-05-16") == {:error, :invalid_format}
    end

    test "date_to_iso_days/3 delegates to Calendar.ISO" do
      assert Calendrical.Parse.date_to_iso_days(2026, 5, 16) ==
               Calendar.ISO.date_to_iso_days(2026, 5, 16)
    end
  end
end
