defmodule Calendrical.UnsupportedDateRangeTest do
  @moduledoc """
  Regression tests for out-of-domain date handling in the
  astronomical calendars.

  The Persian calendar depends on `Astro.equinox/2`, which is
  accurate only for Gregorian years 1000 to 3000. The observational
  Islamic calendars depend on the JPL ephemeris, which covers a
  bounded span of years. Dates outside those domains must raise
  `Calendrical.UnsupportedDateRangeError` (from conversion
  callbacks, which cannot return error tuples) or return tagged
  errors (from ordinary public functions) — never crash with
  `FunctionClauseError` or `MatchError`.

  """

  use ExUnit.Case, async: true

  describe "Calendrical.Persian outside Gregorian years 1000..3000" do
    test "new_year_gregorian/1 returns a tagged error" do
      assert {:error, :year_out_of_range} = Calendrical.Persian.new_year_gregorian(900)
      assert {:error, :year_out_of_range} = Calendrical.Persian.new_year_gregorian(3500)
    end

    test "new_year_gregorian/1 still succeeds inside the range" do
      assert {:ok, ~D[2025-03-21]} = Calendrical.Persian.new_year_gregorian(2025)
    end

    test "year_end_gregorian/1 returns a tagged error when year + 1 is out of range" do
      assert {:error, :year_out_of_range} = Calendrical.Persian.year_end_gregorian(3000)
    end

    test "date_to_iso_days/3 raises UnsupportedDateRangeError with the calendar and range" do
      error =
        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          Calendrical.Persian.date_to_iso_days(300, 1, 1)
        end

      assert error.calendar == Calendrical.Persian
      assert Exception.message(error) =~ "Calendrical.Persian"
      assert Exception.message(error) =~ "1001"
    end

    test "date_from_iso_days/1 raises UnsupportedDateRangeError for an early date" do
      iso_days = Date.to_gregorian_days(~D[0900-06-01])

      assert_raise Calendrical.UnsupportedDateRangeError, fn ->
        Calendrical.Persian.date_from_iso_days(iso_days)
      end
    end

    test "Date.convert/2 raises UnsupportedDateRangeError instead of FunctionClauseError" do
      assert_raise Calendrical.UnsupportedDateRangeError, fn ->
        Date.convert(~D[0900-06-01], Calendrical.Persian)
      end

      assert_raise Calendrical.UnsupportedDateRangeError, fn ->
        Date.convert(~D[3500-06-01], Calendrical.Persian)
      end
    end

    test "Date.convert/2 still succeeds inside the range" do
      assert {:ok, %Date{calendar: Calendrical.Persian}} =
               Date.convert(~D[2026-07-05], Calendrical.Persian)
    end
  end

  # The observational Islamic calendars only fail cleanly once astro
  # returns tagged errors from the moon-event scan (astro >= 2.3.3);
  # on earlier astro versions the crash happens inside astro before
  # calendrical can intervene.
  astro_version = Application.spec(:astro, :vsn) |> to_string()

  if Version.match?(astro_version, ">= 2.3.3") do
    describe "Calendrical.Islamic.Observational outside the ephemeris range" do
      test "Date.convert/2 raises UnsupportedDateRangeError instead of MatchError" do
        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          Date.convert(~D[0500-06-01], Calendrical.Islamic.Observational)
        end
      end

      test "Date.convert/2 still succeeds inside the ephemeris range" do
        assert {:ok, %Date{calendar: Calendrical.Islamic.Observational}} =
                 Date.convert(~D[2026-07-05], Calendrical.Islamic.Observational)
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

    test "message/1 without a calendar names the value and range" do
      error =
        Calendrical.UnsupportedDateRangeError.exception(
          value: ~D[0500-06-01],
          range: "dates covered by the installed JPL ephemeris"
        )

      assert Exception.message(error) ==
               "The date ~D[0500-06-01] is outside the supported range of " <>
                 "dates covered by the installed JPL ephemeris"
    end
  end
end
