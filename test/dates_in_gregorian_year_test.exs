defmodule Calendrical.DatesInGregorianYearTest do
  @moduledoc """
  Regression tests for `Calendrical.dates_in_gregorian_year/4` and the
  generated `dates_in_gregorian_year/3` callback across the calendar
  construction classes: Behaviour calendars, month- and week-compiled
  calendars, and the Julian compiler.

  """

  use ExUnit.Case, async: true

  test "a Gregorian date occurs exactly once in its own year" do
    assert Calendrical.Gregorian.dates_in_gregorian_year(2026, 7, 25) ==
             [Date.new!(2026, 7, 25, Calendrical.Gregorian)]
  end

  test "an Islamic date can occur twice in one Gregorian year" do
    assert Calendrical.Islamic.Civil.dates_in_gregorian_year(2000, 9, 29) == [
             Date.new!(1420, 9, 29, Calendrical.Islamic.Civil),
             Date.new!(1421, 9, 29, Calendrical.Islamic.Civil)
           ]
  end

  test "Julian dates resolve to the Julian year whose day falls in the Gregorian year" do
    # Julian Christmas 2025 falls on Gregorian 2026-01-07; Julian
    # Christmas 2026 falls in Gregorian 2027.
    assert Calendrical.Julian.dates_in_gregorian_year(2026, 12, 25) ==
             [Date.new!(2025, 12, 25, Calendrical.Julian)]
  end

  test "a date only valid in leap years occurs zero times in other Gregorian years" do
    # Hebrew month 6 (Adar I) exists only in leap years; 5787 is leap
    # and its Adar I falls in Gregorian 2027.
    assert Calendrical.Hebrew.dates_in_gregorian_year(2026, 6, 10) == []

    assert Calendrical.Hebrew.dates_in_gregorian_year(2027, 6, 10) ==
             [Date.new!(5787, 6, 10, Calendrical.Hebrew)]

    # The Coptic epagomenal leap day (13, 6) exists only in leap years.
    assert Calendrical.Coptic.dates_in_gregorian_year(2026, 13, 6) == []

    assert Calendrical.Coptic.dates_in_gregorian_year(2027, 13, 6) ==
             [Date.new!(1743, 13, 6, Calendrical.Coptic)]
  end

  test "week-compiled calendars resolve week and day within the Gregorian year" do
    # 2026-W01-1 is 2025-12-29 and 2027-W01-1 is 2027-01-04, so no
    # ISO week-1 Monday falls inside Gregorian 2026 at all; the
    # following Gregorian year holds exactly one.
    assert Calendrical.ISOWeek.dates_in_gregorian_year(2026, 1, 1) == []

    assert Calendrical.ISOWeek.dates_in_gregorian_year(2027, 1, 1) ==
             [Date.new!(2027, 1, 1, Calendrical.ISOWeek)]
  end

  test "the module-supplied arity agrees with the generated callback" do
    assert Calendrical.dates_in_gregorian_year(Calendrical.Islamic.Civil, 2000, 9, 29) ==
             Calendrical.Islamic.Civil.dates_in_gregorian_year(2000, 9, 29)
  end

  test "the callback is overridable on Behaviour calendars" do
    assert {:dates_in_gregorian_year, 3} in Calendrical.Hebrew.__info__(:functions)

    defmodule OverridingCalendar do
      use Calendrical.Behaviour,
        epoch: ~D[0001-01-01 Calendar.ISO],
        cldr_calendar_type: :gregorian

      def date_to_iso_days(year, month, day),
        do: Calendar.ISO.date_to_iso_days(year, month, day)

      def date_from_iso_days(iso_days), do: Calendar.ISO.date_from_iso_days(iso_days)

      @impl true
      def leap_year?(year), do: Calendar.ISO.leap_year?(year)

      @impl true
      def dates_in_gregorian_year(_gregorian_year, _month, _day), do: []
    end

    assert OverridingCalendar.dates_in_gregorian_year(2026, 7, 25) == []
  end
end
