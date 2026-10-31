defmodule Calendrical.UnsupportedDateRangeTest do
  @moduledoc """
  Regression tests for out-of-domain date handling in the
  astronomical calendars.

  The Persian calendar's equinox, from `Astro.equinox/2`, can be
  computed only for Gregorian years 1000 to 3000, and its functions of
  the equinox answer an error outside them; its dates outside them are
  arithmetic (`test/persian_arithmetic_test.exs`). The observational
  Islamic calendars depend on the JPL ephemeris, which covers a
  bounded span of years. Dates outside that domain must raise
  `Calendrical.UnsupportedDateRangeError` (from conversion
  callbacks, which cannot return error tuples) or return tagged
  errors (from ordinary public functions) — never crash with
  `FunctionClauseError` or `MatchError`.

  """

  use ExUnit.Case, async: true

  describe "Calendrical.Persian's new year outside Gregorian years 1900..2100" do
    test "new_year_gregorian/1 returns a tagged error" do
      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.new_year_gregorian(900)

      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.new_year_gregorian(3500)

      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.new_year_gregorian(1899)

      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.new_year_gregorian(2101)
    end

    test "new_year_gregorian/1 still succeeds inside the range" do
      assert {:ok, ~D[2025-03-21]} = Calendrical.Persian.new_year_gregorian(2025)
    end

    test "year_end_gregorian/1 returns a tagged error when year + 1 is out of range" do
      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.year_end_gregorian(3000)
    end

    test "Date.convert/2 answers inside and outside the range" do
      assert {:ok, %Date{calendar: Calendrical.Persian}} =
               Date.convert(~D[2026-07-05], Calendrical.Persian)

      assert {:ok, %Date{calendar: Calendrical.Persian}} =
               Date.convert(~D[0900-06-01], Calendrical.Persian)
    end
  end

  # Astro answers every date within 50,000 years of 2000, from the JPL
  # ephemeris where it covers a date and from its analytical series beyond, so
  # the observational Islamic calendars answer far outside the ephemeris too.
  describe "Calendrical.Islamic.Observational beyond the JPL ephemeris" do
    test "Date.convert/2 answers inside and outside the ephemeris" do
      for date <- [~D[2026-07-05], ~D[1700-03-01], ~D[0500-06-01]] do
        assert {:ok, %Date{calendar: Calendrical.Islamic.Observational}} =
                 Date.convert(date, Calendrical.Islamic.Observational)
      end
    end

    test "date_at/2 answers outside the ephemeris" do
      assert {:ok, %Date{calendar: Calendrical.Islamic.Observational}} =
               Calendrical.Islamic.Observational.date_at(~U[1700-03-01 20:00:00Z])
    end

    test "a year beyond Astro's range is refused at once" do
      for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa] do
        {microseconds, valid?} = :timer.tc(fn -> calendar.valid_date?(10_000_000, 1, 1) end)
        refute valid?
        assert microseconds < 1_000_000
      end
    end

    test "year_of_era/3 and day_of_era/3 answer outside the ephemeris" do
      for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa] do
        assert calendar.valid_date?(1300, 1, 1)
        assert {1300, _era} = calendar.year_of_era(1300, 1, 1)
        assert {_day, _era} = calendar.day_of_era(1300, 1, 1)
      end
    end
  end

  describe "Calendrical.UnsupportedDateRangeError" do
    test "message/1 with a calendar names the calendar and range" do
      error =
        Calendrical.UnsupportedDateRangeError.exception(
          calendar: Calendrical.Persian,
          value: ~D[0900-06-01],
          range: "Gregorian years 1001 to 3000"
        )

      assert Exception.message(error) ==
               "The Calendrical.Persian calendar supports dates in " <>
                 "Gregorian years 1001 to 3000. Found ~D[0900-06-01]"
    end

    test "message/1 without a calendar names the value and what bounds it" do
      error =
        Calendrical.UnsupportedDateRangeError.exception(
          value: ~D[0500-06-01],
          range: :jpl_ephemeris
        )

      assert Exception.message(error) ==
               "The date ~D[0500-06-01] is outside the dates the installed JPL ephemeris covers"
    end
  end
end
