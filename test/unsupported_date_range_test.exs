defmodule Calendrical.UnsupportedDateRangeTest do
  @moduledoc """
  Regression tests for out-of-domain date handling in the
  astronomical calendars.

  Astro answers equinoxes, new moons and crescent sightings for the
  50,000 years either side of 2000. Dates beyond them must raise
  `Calendrical.UnsupportedDateRangeError` (from conversion callbacks,
  which cannot return error tuples) or return tagged errors (from
  ordinary public functions) — never crash with `FunctionClauseError`
  or `MatchError`.

  """

  use ExUnit.Case, async: true

  describe "Calendrical.Persian's new year" do
    test "new_year_gregorian/1 answers from the equinox far from the present" do
      assert {:ok, ~D[0900-03-21]} = Calendrical.Persian.new_year_gregorian(900)
      assert {:ok, %Date{year: 3500}} = Calendrical.Persian.new_year_gregorian(3500)
      assert {:ok, ~D[2025-03-21]} = Calendrical.Persian.new_year_gregorian(2025)
    end

    test "new_year_gregorian/1 returns a tagged error beyond Astro's years" do
      assert {:error, %Calendrical.UnsupportedDateRangeError{range: -48_000..52_000}} =
               Calendrical.Persian.new_year_gregorian(60_000)

      assert {:error, %Calendrical.UnsupportedDateRangeError{}} =
               Calendrical.Persian.year_end_gregorian(52_000)
    end

    test "Date.convert/2 answers far from the present and raises beyond Astro's years" do
      for date <- [~D[2026-07-05], ~D[0900-06-01], ~D[3500-06-01]] do
        assert {:ok, %Date{calendar: Calendrical.Persian}} =
                 Date.convert(date, Calendrical.Persian)
      end

      assert_raise Calendrical.UnsupportedDateRangeError, fn ->
        Date.convert(Date.new!(60_000, 1, 1), Calendrical.Persian)
      end
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
          value: Date.new!(60_000, 1, 1),
          range: -48_000..52_000
        )

      assert Exception.message(error) ==
               "The date Date.new!(60000, 1, 1) is outside the supported range of -48000..52000"
    end
  end
end
