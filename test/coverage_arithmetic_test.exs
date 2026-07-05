defmodule Calendrical.CoverageTest.JulianFeb1 do
  @moduledoc false

  # Defined at test-load time (rather than in test/support) so that the
  # `Calendrical.Julian.__using__/1` macro executes while the module is
  # cover-compiled, exercising the macro entry point.
  use Calendrical.Julian, new_year_starting_month_and_day: {2, 1}
end

defmodule CoverageArithmeticTest do
  @moduledoc """
  Coverage tests for the arithmetic-oriented calendar modules:
  `Calendrical.Ethiopic`, `Calendrical.Coptic`, `Calendrical.Julian`,
  `Calendrical.Interval`, `Calendrical.Preference` and `Calendrical.Era`.

  """

  use ExUnit.Case, async: true

  alias Calendrical.{Ethiopic, Coptic, Julian, Interval, Preference, Era}

  describe "Ethiopic and Coptic day_of_week/4 with explicit weekday starts" do
    test "Ethiopic :default keeps the native Saturday-based numbering" do
      assert Ethiopic.day_of_week(2018, 1, 1, :default) == {4, 6, 5}
    end

    test "Coptic :default keeps the native Saturday-based numbering" do
      assert Coptic.day_of_week(1742, 1, 1, :default) == {4, 6, 5}
    end

    test "Ethiopic explicit weekday starts renumber the week as {n, 1, 7}" do
      assert Ethiopic.day_of_week(2018, 1, 1, :monday) == {4, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :tuesday) == {3, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :wednesday) == {2, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :thursday) == {1, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :friday) == {7, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :saturday) == {6, 1, 7}
      assert Ethiopic.day_of_week(2018, 1, 1, :sunday) == {5, 1, 7}
    end

    test "Coptic explicit weekday starts renumber the week as {n, 1, 7}" do
      assert Coptic.day_of_week(1742, 1, 1, :monday) == {4, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :tuesday) == {3, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :wednesday) == {2, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :thursday) == {1, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :friday) == {7, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :saturday) == {6, 1, 7}
      assert Coptic.day_of_week(1742, 1, 1, :sunday) == {5, 1, 7}
    end
  end

  describe "Ethiopic and Coptic eras" do
    test "year_of_era for era 0 (years before year 1)" do
      assert Ethiopic.year_of_era(-50) == {50, 0}
      assert Ethiopic.year_of_era(-50, 1, 1) == {50, 0}
      assert Coptic.year_of_era(-50) == {50, 0}
      assert Coptic.year_of_era(-50, 2, 3) == {50, 0}
    end

    test "year_of_era for era 1" do
      assert Ethiopic.year_of_era(2018) == {2018, 1}
      assert Coptic.year_of_era(1742, 1, 1) == {1742, 1}
    end

    test "day_of_era returns the era for era-0 and era-1 dates" do
      assert {_day, 0} = Ethiopic.day_of_era(-50, 1, 1)
      assert {_day, 0} = Coptic.day_of_era(-50, 1, 1)
      assert {_day, 1} = Ethiopic.day_of_era(2018, 1, 1)
      assert {_day, 1} = Coptic.day_of_era(1742, 1, 1)
    end

    test "day_of_era is consistent with days_in_year across consecutive years" do
      {day_2018, 1} = Ethiopic.day_of_era(2018, 1, 1)
      {day_2019, 1} = Ethiopic.day_of_era(2019, 1, 1)
      assert day_2019 - day_2018 == Ethiopic.days_in_year(2018)

      {day_1742, 1} = Coptic.day_of_era(1742, 1, 1)
      {day_1743, 1} = Coptic.day_of_era(1743, 1, 1)
      assert day_1743 - day_1742 == Coptic.days_in_year(1742)
    end
  end

  describe "Ethiopic and Coptic days_in_month/2 and valid_date?/3" do
    test "months 1..12 always have 30 days" do
      for month <- 1..12 do
        assert Ethiopic.days_in_month(2018, month) == 30
        assert Coptic.days_in_month(1742, month) == 30
      end
    end

    test "month 13 has 5 days in an ordinary year and 6 in a leap year" do
      assert Ethiopic.days_in_month(2018, 13) == 5
      assert Ethiopic.days_in_month(2019, 13) == 6
      assert Coptic.days_in_month(1742, 13) == 5
      assert Coptic.days_in_month(1743, 13) == 6
    end

    test "days_in_month/1 is undefined for these calendars" do
      assert Ethiopic.days_in_month(5) == {:error, :undefined}
      assert Coptic.days_in_month(13) == {:error, :undefined}
    end

    test "valid_date? false branches" do
      refute Ethiopic.valid_date?(2018, 14, 1)
      refute Ethiopic.valid_date?(2018, 1, 31)
      refute Ethiopic.valid_date?(2018, 13, 6)
      assert Ethiopic.valid_date?(2019, 13, 6)
      refute Coptic.valid_date?(1742, 14, 1)
      refute Coptic.valid_date?(1742, 13, 6)
      assert Coptic.valid_date?(1743, 13, 6)
    end
  end

  describe "Ethiopic and Coptic period ranges" do
    test "year/1 returns a Date.Range spanning the 13 months" do
      range = Ethiopic.year(2018)
      assert range.first == ~D[2018-01-01 Calendrical.Ethiopic]
      assert range.last == ~D[2018-13-05 Calendrical.Ethiopic]

      range = Coptic.year(1743)
      assert range.first == ~D[1743-01-01 Calendrical.Coptic]
      assert range.last == ~D[1743-13-06 Calendrical.Coptic]
    end

    test "month/2 returns a Date.Range including the epagomenal month" do
      range = Ethiopic.month(2018, 13)
      assert range.first == ~D[2018-13-01 Calendrical.Ethiopic]
      assert range.last == ~D[2018-13-05 Calendrical.Ethiopic]

      range = Coptic.month(1743, 13)
      assert range.first == ~D[1743-13-01 Calendrical.Coptic]
      assert range.last == ~D[1743-13-06 Calendrical.Coptic]
    end

    test "quarter and week functions are not defined for 13-month calendars" do
      assert Ethiopic.quarter(2018, 1) == {:error, :not_defined}
      assert Ethiopic.week(2018, 1) == {:error, :not_defined}
      assert Ethiopic.quarter_of_year(2018, 5, 1) == {:error, :not_defined}
      assert Coptic.quarter_of_year(1742, 5, 1) == {:error, :not_defined}
      assert Ethiopic.week_of_year(2018, 5, 1) == {:error, :not_defined}
      assert Ethiopic.iso_week_of_year(2018, 5, 1) == {:error, :not_defined}
      assert Ethiopic.week_of_month(2018, 5, 1) == {:error, :not_defined}
      assert Ethiopic.weeks_in_year(2018) == {:error, :not_defined}
    end
  end

  describe "Ethiopic and Coptic plus/6 and shift functions" do
    test "plus :months wraps into the epagomenal month and the next year" do
      assert Ethiopic.plus(2018, 12, 30, :months, 1) == {2018, 13, 30}
      assert Ethiopic.plus(2018, 12, 30, :months, 1, coerce: true) == {2018, 13, 5}
      assert Ethiopic.plus(2018, 13, 5, :months, 1, coerce: true) == {2019, 1, 5}
      assert Ethiopic.plus(2018, 1, 1, :months, -1, coerce: true) == {2017, 13, 1}
      assert Coptic.plus(1742, 12, 30, :months, 2, coerce: true) == {1743, 1, 30}
    end

    test "shift_date by months" do
      assert Ethiopic.shift_date(2018, 1, 1, Duration.new!(month: 1)) == {2018, 2, 1}
    end

    test "shift_time delegates to Calendar.ISO" do
      assert Ethiopic.shift_time(12, 0, 0, {0, 0}, Duration.new!(hour: 1)) ==
               {13, 0, 0, {0, 0}}
    end

    test "shift_naive_datetime by days" do
      assert Ethiopic.shift_naive_datetime(2018, 1, 1, 0, 0, 0, {0, 0}, Duration.new!(day: 1)) ==
               {2018, 1, 2, 0, 0, 0, {0, 0}}
    end
  end

  describe "Ethiopic and Coptic identity and conversion functions" do
    test "related_gregorian_year" do
      assert Ethiopic.related_gregorian_year(2018, 1, 1) == 2025
      assert Coptic.related_gregorian_year(1742, 1, 1) == 2025
    end

    test "calendar identity functions" do
      assert Ethiopic.calendar_year(2018, 1, 1) == 2018
      assert Ethiopic.extended_year(2018, 1, 1) == 2018
      assert Ethiopic.cyclic_year(2018, 1, 1) == 2018
      assert Ethiopic.month_of_year(2018, 5, 1) == 5
      assert Ethiopic.day_of_year(2018, 2, 1) == 31
      assert Ethiopic.months_in_year(2018) == 13
      assert Ethiopic.months_in_year() == 13
      assert Ethiopic.months_in_ordinary_year() == 13
      assert Ethiopic.months_in_leap_year() == 13
      assert Ethiopic.periods_in_year(2018) == 13
      assert Ethiopic.days_in_week() == 7
      assert Ethiopic.cldr_calendar_type() == :ethiopic
      assert Ethiopic.calendar_base() == :month
      assert Ethiopic.first_day_of_week() == 1
      assert Ethiopic.last_day_of_week() == 7
      assert Coptic.days_in_year(1742) == 365
      assert Coptic.days_in_year(1743) == 366
    end

    test "epoch values" do
      assert Ethiopic.epoch() == 3161
      assert Coptic.epoch() == 103_970
      assert Ethiopic.epoch_day_of_week() == 3
    end

    test "parsing via the Calendar behaviour" do
      assert Ethiopic.parse_date("2018-01-01") == {:ok, {2018, 1, 1}}

      assert Ethiopic.parse_naive_datetime("2018-01-01 10:00:00") ==
               {:ok, {2018, 1, 1, 10, 0, 0, {0, 0}}}

      assert Ethiopic.parse_utc_datetime("2018-01-01 10:00:00Z") ==
               {:ok, {2018, 1, 1, 10, 0, 0, {0, 0}}, 0}

      assert Ethiopic.parse_time("10:11:12") == {:ok, {10, 11, 12, {0, 0}}}
    end

    test "string and iso-day conversions" do
      assert Ethiopic.date_to_string(2018, 1, 1) == "2018-01-01"

      assert Ethiopic.naive_datetime_to_iso_days(2018, 1, 1, 12, 0, 0, {0, 0}) ==
               {739_870, {43_200_000_000, 86_400_000_000}}

      assert Ethiopic.naive_datetime_from_iso_days({739_870, {43_200_000_000, 86_400_000_000}}) ==
               {2018, 1, 1, 12, 0, 0, {0, 6}}

      assert Ethiopic.valid_time?(10, 0, 0, {0, 0})

      assert Ethiopic.iso_days_to_beginning_of_day({739_870, {43_200_000_000, 86_400_000_000}}) ==
               {739_870, {0, 86_400_000_000}}

      assert Ethiopic.iso_days_to_end_of_day({739_870, {0, 86_400_000_000}}) ==
               {739_870, {86_399_999_999, 86_400_000_000}}

      assert Ethiopic.day_rollover_relative_to_midnight_utc() == {0, 1}
      assert Ethiopic.time_to_string(1, 2, 3, {0, 0}) == "01:02:03"

      assert Ethiopic.naive_datetime_to_string(2018, 1, 1, 1, 2, 3, {0, 0}) ==
               "2018-01-01 01:02:03"

      assert Ethiopic.datetime_to_string(2018, 1, 1, 1, 2, 3, {0, 0}, "Etc/UTC", "UTC", 0, 0) ==
               "2018-01-01 01:02:03Z"

      assert Ethiopic.time_to_day_fraction(12, 0, 0, {0, 0}) == {43_200_000_000, 86_400_000_000}
      assert Ethiopic.time_from_day_fraction({1, 2}) == {12, 0, 0, {0, 6}}
      assert Coptic.date_from_iso_days(700_000) == {1632, 11, 8}
      assert Coptic.date_to_iso_days(1742, 1, 1) == 739_870
    end
  end

  describe "Julian calendar structure" do
    test "calendar identity" do
      assert Julian.calendar_base() == :month
      assert Julian.calendar_year(2025, 1, 1) == 2025
      assert Julian.extended_year(2025, 1, 1) == 2025
      assert Julian.cyclic_year(2025, 1, 1) == 2025
      assert Julian.periods_in_year(2025) == 12
      assert Julian.months_in_year(2025) == 12
      assert Julian.days_in_week() == 7
      assert Julian.weeks_in_year(2025) == {:error, :not_defined}
      assert Julian.week_of_year(2025, 1, 1) == {:error, :not_defined}
      assert Julian.day_rollover_relative_to_midnight_utc() == {0, 1}
    end

    test "valid_date? rejects month 13" do
      refute Julian.valid_date?(2025, 13, 1)
    end

    test "day_of_year counts from 1 January" do
      assert Julian.day_of_year(2025, 3, 1) == 60
      assert Julian.day_of_year(2024, 3, 1) == 61
    end

    test "days_in_month/1 resolves all months except February" do
      assert Enum.map(1..12, &Julian.days_in_month/1) == [
               31,
               {:error, :unresolved},
               31,
               30,
               31,
               30,
               31,
               31,
               30,
               31,
               30,
               31
             ]
    end

    test "leap_year? for negative years uses the mod-3 rule" do
      assert Julian.leap_year?(-1)
      refute Julian.leap_year?(-2)
    end
  end

  describe "Julian ranges" do
    test "year/1, quarter/2 and month/2 return Date.Range values" do
      range = Julian.year(2025)
      assert range.first == ~D[2025-01-01 Calendrical.Julian]
      assert range.last == ~D[2025-12-31 Calendrical.Julian]

      range = Julian.quarter(2025, 4)
      assert range.first == ~D[2025-10-01 Calendrical.Julian]
      assert range.last == ~D[2025-12-31 Calendrical.Julian]

      range = Julian.month(2024, 2)
      assert range.first == ~D[2024-02-01 Calendrical.Julian]
      assert range.last == ~D[2024-02-29 Calendrical.Julian]
    end

    test "week/2 is not defined" do
      assert Julian.week(2025, 1) == {:error, :not_defined}
    end
  end

  describe "Julian plus/6 arithmetic" do
    test "plus :years without coerce keeps the day" do
      assert Julian.plus(2024, 2, 29, :years, 1) == {2025, 2, 29}
    end

    test "plus :months with and without coerce" do
      assert Julian.plus(2025, 1, 31, :months, 1) == {2025, 2, 31}
      assert Julian.plus(2025, 1, 31, :months, 1, coerce: true) == {2025, 2, 28}
    end

    test "plus :years crossing year zero skips it" do
      assert Julian.plus(-1, 1, 1, :years, 1) == {1, 1, 1}
      assert Julian.plus(1, 1, 1, :years, -1) == {-1, 1, 1}
      assert Julian.plus(-1, 2, 3, :years, 2) == {2, 2, 3}
    end

    test "plus :months crossing year zero skips it" do
      assert Julian.plus(1, 1, 15, :months, -1) == {-1, 12, 15}
    end

    test "plus :quarters and :days" do
      assert Julian.plus(2025, 1, 1, :quarters, 1) == {2025, 4, 1}
      assert Julian.plus(2025, 10, 1, :quarters, -2) == {2025, 4, 1}
      assert Julian.plus(2025, 12, 25, :days, 10) == {2026, 1, 4}
    end
  end

  describe "Julian shift and datetime functions" do
    test "shift_time wraps across midnight" do
      assert Julian.shift_time(23, 30, 0, {0, 0}, Duration.new!(hour: 1)) == {0, 30, 0, {0, 0}}
    end

    test "shift_naive_datetime crosses a month boundary" do
      assert Julian.shift_naive_datetime(2025, 2, 28, 12, 0, 0, {0, 0}, Duration.new!(day: 1)) ==
               {2025, 3, 1, 12, 0, 0, {0, 0}}
    end

    test "naive datetime round trip through iso days" do
      iso_days = Julian.naive_datetime_to_iso_days(2025, 1, 1, 12, 0, 0, {0, 0})
      assert iso_days == {739_630, {43_200_000_000, 86_400_000_000}}
      assert Julian.naive_datetime_from_iso_days(iso_days) == {2025, 1, 1, 12, 0, 0, {0, 6}}
    end

    test "parsing via the Calendar behaviour" do
      assert Julian.parse_date("2025-01-01") == {:ok, {2025, 1, 1}}
      assert Julian.parse_time("10:11:12") == {:ok, {10, 11, 12, {0, 0}}}

      assert Julian.parse_utc_datetime("2025-01-01 10:00:00Z") ==
               {:ok, {2025, 1, 1, 10, 0, 0, {0, 0}}, 0}

      assert Julian.parse_naive_datetime("2025-01-01 10:00:00") ==
               {:ok, {2025, 1, 1, 10, 0, 0, {0, 0}}}
    end

    test "beginning and end of day" do
      assert Julian.iso_days_to_beginning_of_day({739_630, {43_200_000_000, 86_400_000_000}}) ==
               {739_630, {0, 86_400_000_000}}

      assert Julian.iso_days_to_end_of_day({739_630, {0, 86_400_000_000}}) ==
               {739_630, {86_399_999_999, 86_400_000_000}}
    end

    test "string conversions" do
      assert Julian.datetime_to_string(2025, 1, 1, 1, 2, 3, {0, 0}, "Etc/UTC", "UTC", 0, 0) ==
               "2025-01-01 01:02:03Z"

      assert Julian.datetime_to_string(
               2025,
               1,
               1,
               1,
               2,
               3,
               {0, 0},
               "Etc/UTC",
               "UTC",
               0,
               0,
               :extended
             ) == "2025-01-01 01:02:03Z"

      assert Julian.naive_datetime_to_string(2025, 1, 1, 1, 2, 3, {0, 0}) == "2025-01-01 01:02:03"
      assert Julian.time_to_string(1, 2, 3, {0, 0}) == "01:02:03"
      assert Julian.valid_time?(23, 59, 59, {0, 0})
    end

    test "day_of_era for a BCE date" do
      assert Julian.day_of_era(-1, 12, 31) == {1, 0}
    end
  end

  describe "Julian __using__ variants" do
    test "a runtime-defined variant maps pre-new-year dates to the prior year" do
      assert Calendrical.CoverageTest.JulianFeb1.date_to_iso_days(2025, 1, 15) ==
               Julian.date_to_iso_days(2026, 1, 15)

      assert Calendrical.CoverageTest.JulianFeb1.date_from_iso_days(740_000) == {2025, 1, 6}
    end
  end

  describe "Interval constructors from a date" do
    test "year/1 with a Calendar.ISO date coerces back to Calendar.ISO" do
      assert Interval.year(~D[2025-06-15]) == Date.range(~D[2025-01-01], ~D[2025-12-31])
    end

    test "year/1 with a Calendrical date uses that calendar" do
      assert Interval.year(~D[2025-06-15 Calendrical.Gregorian]) ==
               Date.range(
                 ~D[2025-01-01 Calendrical.Gregorian],
                 ~D[2025-12-31 Calendrical.Gregorian]
               )
    end

    test "year/2 defaults to the Gregorian calendar" do
      assert Interval.year(2025) ==
               Date.range(
                 ~D[2025-01-01 Calendrical.Gregorian],
                 ~D[2025-12-31 Calendrical.Gregorian]
               )
    end

    test "quarter/1 and quarter/3" do
      assert Interval.quarter(~D[2025-06-15]) == Date.range(~D[2025-04-01], ~D[2025-06-30])

      assert Interval.quarter(2025, 2) ==
               Date.range(
                 ~D[2025-04-01 Calendrical.Gregorian],
                 ~D[2025-06-30 Calendrical.Gregorian]
               )
    end

    test "month/1 with a Calendar.ISO date" do
      assert Interval.month(~D[2025-06-15]) == Date.range(~D[2025-06-01], ~D[2025-06-30])
    end

    test "week/1 with a Calendar.ISO date" do
      assert Interval.week(~D[2025-06-15]) == Date.range(~D[2025-06-09], ~D[2025-06-15])
    end

    test "week/3 defaults to the Gregorian calendar" do
      assert Interval.week(2019, 5) ==
               Date.range(
                 ~D[2019-01-28 Calendrical.Gregorian],
                 ~D[2019-02-03 Calendrical.Gregorian]
               )
    end

    test "week/3 on a week-based calendar" do
      assert Interval.week(2019, 5, Calendrical.NRF) ==
               Date.range(~D[2019-W05-1 Calendrical.NRF], ~D[2019-W05-7 Calendrical.NRF])
    end

    test "week/3 on a calendar without weeks returns an error" do
      assert Interval.week(2019, 5, Calendrical.Julian) == {:error, :not_defined}
    end

    test "day/1, day/3 and the invalid day error" do
      assert Interval.day(~D[2025-06-15]) == Date.range(~D[2025-06-15], ~D[2025-06-15])

      assert Interval.day(2025, 45) ==
               Date.range(
                 ~D[2025-02-14 Calendrical.Gregorian],
                 ~D[2025-02-14 Calendrical.Gregorian]
               )

      assert Interval.day(2019, 92, Calendrical.NRF) ==
               Date.range(~D[2019-W14-1 Calendrical.NRF], ~D[2019-W14-1 Calendrical.NRF])

      assert Interval.day(2025, 400) == {:error, :invalid_date}
    end

    test "to_iso_calendar converts both endpoints" do
      assert Interval.to_iso_calendar(Interval.month(2025, 2, Calendrical.Gregorian)) ==
               Date.range(~D[2025-02-01], ~D[2025-02-28])
    end
  end

  describe "Preference" do
    test "calendar_from_territory/2 with a requested calendar present in the preferences" do
      assert Preference.preferences_for_territory(:SA) ==
               {:ok, [:gregorian, :islamic_umalqura, :islamic, :islamic_rgsa]}

      assert Preference.calendar_from_territory(:SA, :islamic_umalqura) ==
               {:ok, Calendrical.Islamic.UmmAlQura}
    end

    test "calendar_from_territory/2 with a requested calendar absent from the preferences" do
      assert Preference.calendar_from_territory(:US, :coptic) == {:ok, Calendrical.US}
    end

    test "calendar_from_locale/0 uses the process locale" do
      assert {:ok, _calendar_module} = Preference.calendar_from_locale()
    end

    test "calendar_from_locale/1 falls back to the territory preference" do
      assert Preference.calendar_from_locale(:"en-GB") == {:ok, Calendrical.GB}
    end

    test "calendar_from_locale/1 with a U extension but no calendar or first day" do
      assert Preference.calendar_from_locale("en-GB-u-nu-latn") == {:ok, Calendrical.GB}
    end

    test "calendar_modules maps CLDR calendar types to Calendrical modules" do
      modules = Preference.calendar_modules()

      assert modules[:gregorian] == Calendrical.Gregorian
      assert modules[:iso8601] == Calendrical.ISOWeek
      assert modules[:islamic] == Calendrical.Islamic.Observational
      assert modules[:islamic_civil] == Calendrical.Islamic.Civil
      assert modules[:islamic_umalqura] == Calendrical.Islamic.UmmAlQura
      assert modules[:ethiopic_amete_alem] == Calendrical.Ethiopic.AmeteAlem
      assert modules[:dangi] == Calendrical.Korean
    end

    test "territory_preferences returns the CLDR preference map" do
      preferences = Preference.territory_preferences()

      assert is_map(preferences)
      assert preferences[:EG] == [:gregorian, :coptic, :islamic, :islamic_civil, :islamic_tbla]
    end

    test "calendar_module resolves known and unknown calendars" do
      assert Preference.calendar_module(:iso8601) == Calendrical.ISOWeek

      assert {:error, %Localize.UnknownCalendarError{calendar: :bogus}} =
               Preference.calendar_module(:bogus)
    end

    test "calendar_from_name returns the module for a loaded calendar" do
      assert Preference.calendar_from_name(:gregorian) == Calendrical.Gregorian
    end

    test "calendar_from_locale with an invalid locale term" do
      assert {:error, %Localize.InvalidLocaleError{}} = Preference.calendar_from_locale(123)
    end
  end

  describe "Era" do
    test "era_data for julian-dated calendars resolves era boundaries to iso days" do
      assert Era.era_data(:coptic).records == [
               %{code: :am, from: 103_970, era: 1, gregorian_year: 284}
             ]

      assert Era.era_data(:ethiopic).records == [
               %{code: :am, from: 3161, era: 1, gregorian_year: 8},
               %{code: :aa, from: -2_005_714, era: 0, gregorian_year: -5492}
             ]
    end

    test "era_data for the islamic calendar family" do
      for cldr_calendar_type <- [:islamic, :islamic_civil, :islamic_rgsa, :islamic_umalqura] do
        assert [%{code: :bh, to: 227_379, era: 1}, %{code: :ah, from: 227_380, era: 0}] =
                 Era.era_data(cldr_calendar_type).records
      end

      assert [%{code: :bh, to: 227_378, era: 1}, %{code: :ah, from: 227_379, era: 0}] =
               Era.era_data(:islamic_tbla).records
    end

    test "day_of_era for an end-dated (BCE-style) era record counts to the era end" do
      assert Era.day_of_era(:gregorian, Date.to_gregorian_days(~D[0000-01-01])) == {1, 0}
      assert Era.day_of_era(:gregorian, Date.to_gregorian_days(~D[0000-12-31])) == {366, 0}
    end

    test "gregorian_offset year_of_era clamps to year 1 before the era label year" do
      iso_days = Date.to_gregorian_days(~D[2019-05-01])

      assert Era.year_of_era(:japanese, iso_days, 2019) == {1, 236}
      assert Era.year_of_era(:japanese, iso_days, 2018) == {1, 236}
      assert Era.year_of_era(:japanese, iso_days, 2020) == {2, 236}
    end

    test "identity year_of_era without a before era keeps the year" do
      assert Era.year_of_era(:coptic, 0, -5) == {-5, 1}
    end

    test "era_data raises for an unknown calendar type" do
      assert_raise ArgumentError, ~r/unknown CLDR calendar type :bogus/, fn ->
        Era.era_data(:bogus)
      end
    end
  end
end
