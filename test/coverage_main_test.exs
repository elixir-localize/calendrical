defmodule Calendrical.CoverageMainTest do
  use ExUnit.Case, async: true

  # Additional coverage for the Calendrical module surface:
  # localize/3 and localize/6 clauses, strftime, intervals,
  # calendar data delegation, date constructors and error branches.

  describe "localize/3 date parts" do
    test "month in all formats and types" do
      date = ~D[2026-07-05]

      assert Calendrical.localize(date, :month, locale: :en) == "Jul"
      assert Calendrical.localize(date, :month, locale: :en, style: :wide) == "July"
      assert Calendrical.localize(date, :month, locale: :en, style: :narrow) == "J"

      assert Calendrical.localize(date, :month,
               locale: :en,
               type: :stand_alone,
               style: :wide
             ) == "July"
    end

    test "quarter in all formats and types" do
      date = ~D[2026-07-05]

      assert Calendrical.localize(date, :quarter, locale: :en) == "Q3"
      assert Calendrical.localize(date, :quarter, locale: :en, style: :wide) == "3rd quarter"
      assert Calendrical.localize(date, :quarter, locale: :en, style: :narrow) == "3"

      assert Calendrical.localize(date, :quarter,
               locale: :en,
               type: :stand_alone,
               style: :wide
             ) == "3rd quarter"
    end

    test "era with and without variant" do
      assert Calendrical.localize(~D[2026-07-05], :era, locale: :en) == "AD"
      assert Calendrical.localize(~D[2026-07-05], :era, locale: :en, era: :variant) == "CE"
    end

    test "day_of_week in all widths" do
      date = ~D[2026-07-05]

      assert Calendrical.localize(date, :day_of_week, locale: :en) == "Sun"
      assert Calendrical.localize(date, :day_of_week, locale: :en, style: :wide) == "Sunday"
      assert Calendrical.localize(date, :day_of_week, locale: :en, style: :narrow) == "S"
    end

    test "days_of_week in abbreviated and wide widths" do
      date = ~D[2026-07-05]

      assert Calendrical.localize(date, :days_of_week, locale: :en) ==
               [
                 {1, "Mon"},
                 {2, "Tue"},
                 {3, "Wed"},
                 {4, "Thu"},
                 {5, "Fri"},
                 {6, "Sat"},
                 {7, "Sun"}
               ]

      assert Calendrical.localize(date, :days_of_week, locale: :en, style: :wide) ==
               [
                 {1, "Monday"},
                 {2, "Tuesday"},
                 {3, "Wednesday"},
                 {4, "Thursday"},
                 {5, "Friday"},
                 {6, "Saturday"},
                 {7, "Sunday"}
               ]
    end

    test "am_pm variants and format options" do
      assert Calendrical.localize(~T[10:15:00], :day_period, locale: :en) == "AM"
      assert Calendrical.localize(~T[22:15:00], :day_period, locale: :en) == "PM"

      assert Calendrical.localize(~T[10:15:00], :day_period, locale: :en, day_period: :variant) ==
               "am"

      assert Calendrical.localize(~T[10:15:00], :day_period, locale: :en, day_period: :variant) ==
               "am"

      assert Calendrical.localize(~T[10:15:00], :day_period, locale: :en, style: :wide) == "AM"
    end

    test "day_periods localization" do
      assert Calendrical.localize(:morning1, :day_periods, locale: :en) == "in the morning"
      assert Calendrical.localize(:noon, :day_periods, locale: :en, style: :wide) == "noon"

      assert Calendrical.localize(:night1, :day_periods,
               locale: :en,
               type: :stand_alone,
               style: :wide
             ) == "night"
    end

    test "cyclic_year for the Chinese calendar and numeric fallback" do
      {:ok, chinese_date} = Date.convert(~D[2026-07-05], Calendrical.Chinese)

      assert Calendrical.localize(chinese_date, :cyclic_year, locale: :en) == "bing-wu"

      assert Calendrical.localize(chinese_date, :cyclic_year, locale: :en, style: :wide) ==
               "bing-wu"

      # Gregorian has no cyclic year data so the year is returned as a string.
      assert Calendrical.localize(~D[2026-07-05], :cyclic_year, locale: :en) == "2026"
    end
  end

  describe "localize/3 error branches" do
    test "invalid part" do
      assert {:error, %Calendrical.InvalidPartError{part: :bogus_part}} =
               Calendrical.localize(~D[2026-07-05], :bogus_part, locale: :en)
    end

    test "invalid type" do
      assert {:error, %Calendrical.InvalidTypeError{type: :bogus}} =
               Calendrical.localize(~D[2026-07-05], :month, locale: :en, type: :bogus)
    end

    test "invalid format" do
      assert {:error, %Calendrical.InvalidStyleError{style: :bogus}} =
               Calendrical.localize(~D[2026-07-05], :month, locale: :en, style: :bogus)
    end

    test "invalid locale" do
      assert {:error, %Localize.InvalidLocaleError{}} =
               Calendrical.localize(~D[2026-07-05], :month, locale: :zz_invalid)
    end
  end

  describe "localize/6 clauses" do
    setup do
      {:ok, locale} = Localize.validate_locale(:en)
      %{locale: locale}
    end

    test "five-argument era call uses the default options", %{locale: locale} do
      assert Calendrical.localize(
               ~D[2026-07-05 Calendrical.Gregorian],
               :era,
               :format,
               :abbreviated,
               locale
             ) == "AD"
    end

    test "numeric month for a plain and a leap month", %{locale: locale} do
      assert Calendrical.localize(
               ~D[2026-07-05 Calendrical.Gregorian],
               :month,
               :numeric,
               :abbreviated,
               locale
             ) == 7

      {:ok, leap_date} = Date.convert(~D[2023-04-15], Calendrical.Chinese)
      assert Calendrical.month_of_year(leap_date) == {2, :leap}

      assert Calendrical.localize(leap_date, :month, :numeric, :abbreviated, locale) == "2bis"
    end

    test "numeric leap month without month patterns falls back to the number",
         %{locale: locale} do
      # Hebrew has no month_patterns data, so the numeric leap month
      # falls back to the plain month number.
      {:ok, adar_ii} = Date.convert(~D[2024-03-20], Calendrical.Hebrew)
      assert Calendrical.month_of_year(adar_ii) == {7, :leap}

      assert Calendrical.localize(adar_ii, :month, :numeric, :abbreviated, locale) == "7"
    end

    test "named leap month with substitution pattern (Chinese)" do
      {:ok, leap_date} = Date.convert(~D[2023-04-15], Calendrical.Chinese)

      assert Calendrical.localize(leap_date, :month, locale: :en) == "Mo2bis"

      assert Calendrical.localize(leap_date, :month, locale: :en, style: :wide) ==
               "Second Monthbis"
    end

    test "named leap month with a _yeartype_leap variant (Hebrew)" do
      {:ok, adar_i} = Date.convert(~D[2024-02-15], Calendrical.Hebrew)
      {:ok, adar_ii} = Date.convert(~D[2024-03-20], Calendrical.Hebrew)

      assert Calendrical.localize(adar_i, :month, locale: :en) == "Adar I"
      assert Calendrical.localize(adar_ii, :month, locale: :en) == "Adar II"

      # Narrow month names have no leap variant and Hebrew has no
      # month patterns, so the month falls back to the base name.
      assert Calendrical.localize(adar_ii, :month, locale: :en, style: :narrow) == "7"
    end

    test "partial maps produce missing-field errors", %{locale: locale} do
      gregorian = Calendrical.Gregorian

      assert {:error, %Calendrical.MissingFieldsError{function: "cyclic_year"}} =
               Calendrical.localize(
                 %{month: 1, day: 1, calendar: gregorian},
                 :cyclic_year,
                 :format,
                 :abbreviated,
                 locale
               )

      assert {:error, %Calendrical.MissingFieldsError{function: "quarter_of_year"}} =
               Calendrical.localize(
                 %{year: 2026, day: 1, calendar: gregorian},
                 :quarter,
                 :format,
                 :abbreviated,
                 locale
               )

      assert {:error, %Calendrical.MissingFieldsError{function: "month_of_year"}} =
               Calendrical.localize(
                 %{year: 2026, calendar: gregorian},
                 :month,
                 :format,
                 :abbreviated,
                 locale
               )

      assert {:error, %Calendrical.MissingFieldsError{function: "month_of_year"}} =
               Calendrical.localize(
                 %{year: 2026, calendar: gregorian},
                 :month,
                 :numeric,
                 :abbreviated,
                 locale
               )

      assert {:error, %Calendrical.MissingFieldsError{function: "localize"}} =
               Calendrical.localize(
                 %{year: 2026, month: 7},
                 :day_of_week,
                 :format,
                 :abbreviated,
                 locale
               )
    end
  end

  describe "localize/1 and localize/2 calendar conversion" do
    test "localize/2 converts to the locale's calendar" do
      assert {:ok, %Date{calendar: Calendrical.FR} = date} =
               Calendrical.localize(~D[2022-06-09], locale: "fr")

      assert date.year == 2022 and date.month == 6 and date.day == 9
    end

    test "localize/1 converts using the current locale" do
      assert {:ok, %Date{year: 2022, month: 6, day: 9}} = Calendrical.localize(~D[2022-06-09])
    end

    test "localize/2 with an invalid locale returns an error" do
      assert {:error, %Localize.InvalidLocaleError{}} =
               Calendrical.localize(~D[2022-06-09], locale: :zz_invalid)
    end
  end

  describe "strftime/2,3 and strftime_options!/0,1" do
    test "strftime formats dates, times and naive datetimes" do
      assert Calendrical.strftime(~D[2026-07-05], "%a %B %Y", locale: :en) == "Sun July 2026"
      assert Calendrical.strftime(~D[2026-07-05], "%a", locale: :fr) == "dim."
      assert Calendrical.strftime(~T[14:30:00], "%H:%M", locale: :en) == "14:30"
      assert Calendrical.strftime(~N[2026-07-05 14:30:00], "%y %p", locale: :en) == "26 PM"
    end

    test "strftime with default options" do
      assert Calendrical.strftime(~D[2026-07-05], "%d/%m/%Y") == "05/07/2026"
    end

    test "strftime localizes a week calendar date" do
      assert Calendrical.strftime(~D[2025-01-26 Calendrical.IL], "%a", locale: :he) == "יום ב׳"
    end

    test "strftime_options! returns localization callback options" do
      options = Calendrical.strftime_options!(locale: :en)

      assert Keyword.keys(options) == [
               :am_pm_names,
               :month_names,
               :abbreviated_month_names,
               :day_of_week_names,
               :abbreviated_day_of_week_names
             ]

      assert options[:am_pm_names].(:am) == "AM"
      assert options[:month_names].(7) == "July"
      assert options[:abbreviated_month_names].(7) == "Jul"
      assert options[:day_of_week_names].(7) == "Sunday"
      assert options[:abbreviated_day_of_week_names].(7) == "Sun"
    end

    test "strftime_options! with a calendar without cldr_calendar_type/0" do
      options = Calendrical.strftime_options!(calendar: Calendar.ISO, locale: :en)
      assert options[:month_names].(1) == "January"
    end

    test "strftime_options! with defaults is usable by Calendar.strftime" do
      options = Calendrical.strftime_options!()
      assert is_list(options)
      assert is_binary(options[:month_names].(1))
    end

    test "strftime_options! raises on an invalid locale" do
      assert_raise Localize.InvalidLocaleError, fn ->
        Calendrical.strftime_options!(locale: :zz_invalid)
      end
    end
  end

  describe "interval/3 and interval_stream/3" do
    test "interval with a count for each precision" do
      assert Calendrical.interval(~D[2019-01-31], 3, :months) ==
               [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31]]

      assert Calendrical.interval(~D[2019-01-01], 3, :years) ==
               [~D[2019-01-01], ~D[2020-01-01], ~D[2021-01-01]]

      assert Calendrical.interval(~D[2019-01-01], 3, :quarters) ==
               [~D[2019-01-01], ~D[2019-04-01], ~D[2019-07-01]]

      assert Calendrical.interval(~D[2019-01-01], 3, :weeks) ==
               [~D[2019-01-01], ~D[2019-01-08], ~D[2019-01-15]]

      assert Calendrical.interval(~D[2019-01-01], 3, :days) ==
               [~D[2019-01-01], ~D[2019-01-02], ~D[2019-01-03]]
    end

    test "interval between two dates in both directions" do
      assert Calendrical.interval(~D[2019-01-31], ~D[2019-05-31], :months) ==
               [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31], ~D[2019-04-30], ~D[2019-05-31]]

      assert Calendrical.interval(~D[2019-05-31], ~D[2019-01-31], :months) ==
               [~D[2019-05-31], ~D[2019-04-30], ~D[2019-03-31], ~D[2019-02-28], ~D[2019-01-31]]
    end

    test "interval_stream with a count" do
      assert Calendrical.interval_stream(~D[2019-01-31], 3, :months) |> Enum.to_list() ==
               [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31]]
    end

    test "interval_stream between two dates in both directions" do
      assert Calendrical.interval_stream(~D[2019-01-31], ~D[2019-05-31], :months)
             |> Enum.to_list() ==
               [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31], ~D[2019-04-30], ~D[2019-05-31]]

      assert Calendrical.interval_stream(~D[2019-05-31], ~D[2019-01-31], :months)
             |> Enum.to_list() ==
               [~D[2019-05-31], ~D[2019-04-30], ~D[2019-03-31], ~D[2019-02-28], ~D[2019-01-31]]
    end
  end

  describe "month_names/2" do
    test "Calendar.ISO delegates to the Gregorian calendar" do
      names = Calendrical.month_names(Calendar.ISO, locale: :en)
      assert names[1] == "Jan"
      assert names[7] == "Jul"
      assert map_size(names) == 12
    end

    test "with default options" do
      assert Calendrical.month_names(Calendrical.Gregorian)[7] == "Jul"
    end

    test "narrow format in French" do
      names = Calendrical.month_names(Calendrical.Gregorian, locale: :fr, style: :narrow)
      assert names[1] == "J"
      assert names[12] == "D"
    end

    test "for a non-Gregorian calendar" do
      names = Calendrical.month_names(Calendrical.Hebrew, locale: :en, style: :wide)
      assert names[1] == "Tishri"
      assert names[7] == "Adar"
    end

    test "a module without cldr_calendar_type/0 falls back to Gregorian data" do
      assert Calendrical.month_names(Enum, locale: :en)[7] == "Jul"
    end

    test "error branches" do
      assert {:error, %Calendrical.InvalidStyleError{}} =
               Calendrical.month_names(Calendrical.Gregorian, locale: :en, style: :bogus)

      assert {:error, %Calendrical.InvalidTypeError{}} =
               Calendrical.month_names(Calendrical.Gregorian, locale: :en, type: :bogus)

      assert {:error, %Localize.InvalidLocaleError{}} =
               Calendrical.month_names(Calendrical.Gregorian, locale: :zz_invalid)
    end
  end

  describe "calendar data delegation" do
    test "eras/2" do
      assert {:ok, eras} = Calendrical.eras(:en, :gregorian)
      assert get_in(eras, [:abbreviated, 1]) == "AD"
      assert {:ok, _} = Calendrical.eras()
    end

    test "months/2" do
      assert {:ok, months} = Calendrical.months(:en, :gregorian)
      assert get_in(months, [:format, :abbreviated, 7]) == "Jul"
      assert {:ok, _} = Calendrical.months()
    end

    test "days/2" do
      assert {:ok, days} = Calendrical.days(:en, :gregorian)
      assert get_in(days, [:format, :abbreviated, 7]) == "Sun"
      assert {:ok, _} = Calendrical.days()
    end

    test "quarters/2" do
      assert {:ok, quarters} = Calendrical.quarters(:en, :gregorian)
      assert get_in(quarters, [:format, :abbreviated, 3]) == "Q3"
      assert {:ok, _} = Calendrical.quarters()
    end

    test "day_periods/2" do
      assert {:ok, day_periods} = Calendrical.day_periods(:en, :gregorian)

      assert get_in(day_periods, [:format, :abbreviated, :am]) ==
               %{default: "AM", variant: "am"}

      assert {:ok, _} = Calendrical.day_periods()
    end

    test "cyclic_years/2" do
      assert {:ok, cyclic_years} = Calendrical.cyclic_years(:en, :chinese)
      assert get_in(cyclic_years, [:years, :format, :abbreviated, 43]) == "bing-wu"

      assert {:error, %Localize.ItemNotFoundError{}} =
               Calendrical.cyclic_years(:en, :gregorian)

      # The default calendar is :gregorian which has no cyclic year data.
      assert {:error, %Localize.ItemNotFoundError{}} = Calendrical.cyclic_years()
    end

    test "month_patterns/2" do
      assert {:ok, patterns} = Calendrical.month_patterns(:en, :chinese)
      assert get_in(patterns, [:format, :wide, :leap]) == [0, "bis"]

      assert {:error, %Localize.ItemNotFoundError{}} =
               Calendrical.month_patterns(:en, :gregorian)

      # The default calendar is :gregorian which has no month patterns.
      assert {:error, %Localize.ItemNotFoundError{}} = Calendrical.month_patterns()
    end
  end

  describe "date constructors" do
    test "date_from_tuple/1,2" do
      assert Calendrical.date_from_tuple({2019, 3, 25}) ==
               %Date{calendar: Calendrical.Gregorian, year: 2019, month: 3, day: 25}

      assert Calendrical.date_from_tuple({2019, 2, 29}) == {:error, :invalid_date}
    end

    test "date_from_list/1,2" do
      assert Calendrical.date_from_list(year: 2019, month: 3, day: 25) ==
               %Date{calendar: Calendrical.Gregorian, year: 2019, month: 3, day: 25}

      assert Calendrical.date_from_list(year: 2019, month: 2, day: 29) ==
               {:error, :invalid_date}

      assert Calendrical.date_from_list(month: 2, day: 28) == {:error, :invalid_date}
    end

    test "date_from_day_of_year/2,3" do
      assert Calendrical.date_from_day_of_year(2019, 32) ==
               %Date{calendar: Calendrical.Gregorian, year: 2019, month: 2, day: 1}

      assert Calendrical.date_from_day_of_year(2019, 366) == {:error, :invalid_date}
      assert Calendrical.date_from_day_of_year(2019, 0) == {:error, :invalid_date}
    end

    test "date_from_iso_days/2 with a tuple and an integer" do
      expected = %Date{calendar: Calendrical.Gregorian, year: 2019, month: 1, day: 1}

      assert Calendrical.date_from_iso_days({737_425, {0, 86_400_000_000}}, Calendrical.Gregorian) ==
               expected

      assert Calendrical.date_from_iso_days(737_425, Calendrical.Gregorian) == expected
    end

    test "iso_days_to_day_of_week/1 with a tuple" do
      assert Calendrical.iso_days_to_day_of_week({737_425, {0, 86_400_000_000}}) == 2
    end
  end

  describe "offset and zone formatting" do
    test "offset_to_string/3,4" do
      assert Calendrical.offset_to_string(0, 0, "Etc/UTC") == "Z"
      assert Calendrical.offset_to_string(3600, 0, "Europe/Paris") == "+01:00"
      assert Calendrical.offset_to_string(-18_000, 3600, "America/New_York") == "-04:00"
      assert Calendrical.offset_to_string(3600, 0, "Europe/Paris", :basic) == "+0100"
    end

    test "zone_to_string/4" do
      assert Calendrical.zone_to_string(0, 0, "UTC", "Etc/UTC") == ""
      assert Calendrical.zone_to_string(3600, 0, "CET", "Europe/Paris") == " CET Europe/Paris"
    end

    test "sign/1 and zero_pad/2" do
      assert Calendrical.sign(-1) == "-"
      assert Calendrical.sign(1) == "+"
      assert Calendrical.zero_pad(5, 2) == "05"
      assert Calendrical.zero_pad(-5, 2) == "-05"
    end
  end

  describe "coerce_iso_calendar/1" do
    test "passes errors through" do
      assert Calendrical.coerce_iso_calendar({:error, :invalid_date}) ==
               {:error, :invalid_date}
    end

    test "relabels a date" do
      assert Calendrical.coerce_iso_calendar(~D[2026-07-05 Calendrical.Gregorian]) ==
               ~D[2026-07-05]
    end

    test "relabels a range" do
      range =
        Date.range(~D[2026-07-01 Calendrical.Gregorian], ~D[2026-07-05 Calendrical.Gregorian])

      assert Calendrical.coerce_iso_calendar(range) ==
               Date.range(~D[2026-07-01], ~D[2026-07-05])
    end
  end

  describe "convert/2" do
    test "converts a date" do
      assert Calendrical.convert(~D[2026-07-05], Calendrical.Buddhist) ==
               {:ok, ~D[2569-07-05 Calendrical.Buddhist]}
    end

    test "converts a range" do
      range = Date.range(~D[2026-07-01], ~D[2026-07-05])

      assert Calendrical.convert(range, Calendrical.Buddhist) ==
               {:ok,
                Date.range(
                  ~D[2569-07-01 Calendrical.Buddhist],
                  ~D[2569-07-05 Calendrical.Buddhist]
                )}
    end
  end

  describe "first and last day of year map clauses" do
    test "plain maps with and without a calendar key" do
      map = %{year: 2026, month: 7, day: 5, calendar: Calendrical.Gregorian}

      assert Calendrical.first_day_of_year(map) == ~D[2026-01-01 Calendrical.Gregorian]
      assert Calendrical.last_day_of_year(map) == ~D[2026-12-31 Calendrical.Gregorian]
      assert Calendrical.first_gregorian_day_of_year(map) == ~D[2026-01-01 Calendrical.Gregorian]
      assert Calendrical.last_gregorian_day_of_year(map) == ~D[2026-12-31 Calendrical.Gregorian]

      assert Calendrical.first_day_of_year(%{year: 2026, month: 7, day: 5}) ==
               ~D[2026-01-01 Calendrical.Gregorian]
    end
  end

  describe "territory week data fallbacks" do
    test "string territories are validated then resolved" do
      assert Calendrical.first_day_for_territory("us") == 7
      assert Calendrical.min_days_for_territory("us") == 1
      assert Calendrical.weekend("sa") == [5, 6]
    end

    test "unknown territories return errors" do
      assert {:error, %Localize.UnknownTerritoryError{}} =
               Calendrical.first_day_for_territory(:ZZZZ)

      assert {:error, %Localize.UnknownTerritoryError{}} =
               Calendrical.min_days_for_territory(:ZZZZ)

      assert {:error, %Localize.UnknownTerritoryError{}} = Calendrical.weekend(:ZZZZ)
      assert {:error, %Localize.UnknownTerritoryError{}} = Calendrical.weekdays(:ZZZZ)
    end

    test "valid territories without CLDR data use the world defaults" do
      assert Calendrical.first_day_for_territory(:XX) == 1
      assert Calendrical.min_days_for_territory(:XX) == 1
      assert Calendrical.weekend(:XX) == [6, 7]
      assert Calendrical.weekdays(:XX) == [1, 2, 3, 4, 5]
    end
  end

  describe "current/2, next/2,3 and previous/2,3 with ranges" do
    setup do
      %{week: Calendrical.Interval.week(~D[2026-07-05 Calendrical.Gregorian])}
    end

    test "current for each period", %{week: week} do
      assert week ==
               Date.range(
                 ~D[2026-06-29 Calendrical.Gregorian],
                 ~D[2026-07-05 Calendrical.Gregorian]
               )

      assert Calendrical.current(week, :year) ==
               Date.range(
                 ~D[2026-01-01 Calendrical.Gregorian],
                 ~D[2026-12-31 Calendrical.Gregorian]
               )

      assert Calendrical.current(week, :quarter) ==
               Date.range(
                 ~D[2026-04-01 Calendrical.Gregorian],
                 ~D[2026-06-30 Calendrical.Gregorian]
               )

      assert Calendrical.current(week, :month) ==
               Date.range(
                 ~D[2026-06-01 Calendrical.Gregorian],
                 ~D[2026-06-30 Calendrical.Gregorian]
               )

      assert Calendrical.current(week, :week) == week

      assert Calendrical.current(week, :day) ==
               Date.range(
                 ~D[2026-06-29 Calendrical.Gregorian],
                 ~D[2026-06-29 Calendrical.Gregorian]
               )

      assert Calendrical.current(~D[2026-07-05], :quarter) == ~D[2026-07-05]
    end

    test "next for ranges and dates", %{week: week} do
      assert Calendrical.next(week, :year) ==
               Date.range(
                 ~D[2027-01-01 Calendrical.Gregorian],
                 ~D[2027-12-31 Calendrical.Gregorian]
               )

      assert Calendrical.next(week, :week) ==
               Date.range(
                 ~D[2026-07-06 Calendrical.Gregorian],
                 ~D[2026-07-12 Calendrical.Gregorian]
               )

      assert Calendrical.next(week, :day) ==
               Date.range(
                 ~D[2026-07-06 Calendrical.Gregorian],
                 ~D[2026-07-06 Calendrical.Gregorian]
               )

      assert Calendrical.next(~D[2026-07-05], :year) == ~D[2027-07-05]
    end

    test "previous for ranges and dates", %{week: week} do
      assert Calendrical.previous(week, :year) ==
               Date.range(
                 ~D[2025-01-01 Calendrical.Gregorian],
                 ~D[2025-12-31 Calendrical.Gregorian]
               )

      assert Calendrical.previous(week, :quarter) ==
               Date.range(
                 ~D[2026-04-01 Calendrical.Gregorian],
                 ~D[2026-06-30 Calendrical.Gregorian]
               )

      assert Calendrical.previous(week, :month) ==
               Date.range(
                 ~D[2026-06-01 Calendrical.Gregorian],
                 ~D[2026-06-30 Calendrical.Gregorian]
               )

      assert Calendrical.previous(week, :week) ==
               Date.range(
                 ~D[2026-06-22 Calendrical.Gregorian],
                 ~D[2026-06-28 Calendrical.Gregorian]
               )

      assert Calendrical.previous(week, :day) ==
               Date.range(
                 ~D[2026-06-28 Calendrical.Gregorian],
                 ~D[2026-06-28 Calendrical.Gregorian]
               )

      assert Calendrical.previous(~D[2026-07-05], :year) == ~D[2025-07-05]
    end
  end

  describe "defaults and module introspection" do
    test "default calendar accessors" do
      assert Calendrical.default_calendar() == Calendrical.Gregorian
      assert Calendrical.default_coercion() == true
      assert Calendrical.default_cldr_calendar() == :gregorian
      assert Calendrical.cldr_backend_provider(nil) == nil
    end

    test "calendar_module?/1" do
      assert Calendrical.calendar_module?(Calendrical.Gregorian)
      refute Calendrical.calendar_module?(Enum)
    end

    test "calendar_name/1 and calendars/0" do
      assert Calendrical.calendar_name(Calendrical.Gregorian) == "Calendrical.Gregorian"
      assert Calendrical.calendars()[:gregorian]
    end

    test "supported_cldr_calendar_types/0" do
      types = Calendrical.supported_cldr_calendar_types()
      assert :gregorian in types
      assert :chinese in types
    end
  end

  describe "inspect/1,2" do
    test "with default options" do
      assert Calendrical.inspect(~D[2026-07-05]) == "~D[2026-07-05]"
    end

    test "with Inspect.Opts" do
      assert Calendrical.inspect(~D[2026-07-05], %Inspect.Opts{}) == "~D[2026-07-05]"
    end
  end

  describe "validate_calendar/1 and calendar_from_cldr_calendar_type/1" do
    test "validate_calendar" do
      assert Calendrical.validate_calendar(Calendar.ISO) == {:ok, Calendrical.Gregorian}
      assert Calendrical.validate_calendar(Calendrical.Gregorian) == {:ok, Calendrical.Gregorian}

      assert Calendrical.validate_calendar(Enum) ==
               {:error, %Calendrical.InvalidCalendarModuleError{module: Enum}}

      assert Calendrical.validate_calendar("nope") ==
               {:error, %Calendrical.InvalidCalendarModuleError{module: "nope"}}
    end

    test "calendar_from_cldr_calendar_type" do
      assert Calendrical.calendar_from_cldr_calendar_type(:gregorian) ==
               {:ok, Calendrical.Gregorian}

      assert Calendrical.calendar_from_cldr_calendar_type(:nope) ==
               {:error, %Localize.UnknownCalendarError{calendar: :nope}}
    end
  end

  describe "cardinal_month/3 and cardinal_day_of_week/2" do
    test "cardinal_month for January-start and offset calendars" do
      Code.ensure_loaded!(Calendrical.Gregorian)
      Code.ensure_loaded!(Calendrical.Test.Calendars.Sunday)

      assert Calendrical.cardinal_month(5, Calendrical.Gregorian, 12) == 5
      assert Calendrical.cardinal_month(5, Calendrical.Test.Calendars.Sunday, 12) == 8
      # A module without __config__/0 returns the month unchanged.
      assert Calendrical.cardinal_month(5, Enum, 12) == 5
    end

    test "cardinal_day_of_week for Monday-start and other calendars" do
      Code.ensure_loaded!(Calendrical.ISOWeek)
      Code.ensure_loaded!(Calendrical.NRF)
      Code.ensure_loaded!(Calendrical.Test.Calendars.Sunday)

      assert Calendrical.cardinal_day_of_week(2, Calendrical.ISOWeek) == 2
      assert Calendrical.cardinal_day_of_week(1, Calendrical.NRF) == 6
      assert Calendrical.cardinal_day_of_week(1, Calendrical.Test.Calendars.Sunday) == 7
      # A module without __config__/0 returns the day unchanged.
      assert Calendrical.cardinal_day_of_week(3, Enum) == 3
    end
  end

  describe "month_day/5 and start_end_gregorian_years/2" do
    test "month_day with and without coercion" do
      assert Calendrical.month_day(2026, 2, 31, Calendrical.Gregorian, false) == {2, 31}
      assert Calendrical.month_day(2026, 14, 31, Calendrical.Gregorian, true) == {12, 28}
    end

    test "start_end_gregorian_years for January-first and December-last" do
      first = %Calendrical.Config{first_or_last: :first, month_of_year: 1}
      last = %Calendrical.Config{first_or_last: :last, month_of_year: 12}

      assert Calendrical.start_end_gregorian_years(2026, first) == {2026, 2026}
      assert Calendrical.start_end_gregorian_years(2026, last) == {2026, 2026}
    end
  end

  describe "shift arithmetic on Calendrical calendars" do
    test "Date.shift with year, month, week and day durations" do
      date = Date.convert!(~D[2026-01-31], Calendrical.Gregorian)

      assert Date.shift(date, month: 1) == ~D[2026-02-28 Calendrical.Gregorian]
      assert Date.shift(date, year: 1, week: 1, day: 1) == ~D[2027-02-08 Calendrical.Gregorian]
    end

    test "NaiveDateTime.shift with date and time durations" do
      naive = NaiveDateTime.convert!(~N[2026-01-31 10:00:00], Calendrical.Gregorian)

      assert NaiveDateTime.shift(naive, year: 1, month: 1) ==
               NaiveDateTime.convert!(~N[2027-02-28 10:00:00], Calendrical.Gregorian)

      assert NaiveDateTime.shift(naive, hour: 2, minute: 30) ==
               NaiveDateTime.convert!(~N[2026-01-31 12:30:00], Calendrical.Gregorian)

      assert NaiveDateTime.shift(naive, microsecond: {500_000, 6}) ==
               NaiveDateTime.convert!(~N[2026-01-31 10:00:00.500000], Calendrical.Gregorian)
    end
  end

  describe "parse/1,2" do
    test "parses dates and times" do
      assert Calendrical.parse("2026-05-16") == {:ok, ~D[2026-05-16]}
      assert Calendrical.parse("2026-05-16", locale: :en) == {:ok, ~D[2026-05-16]}
      assert Calendrical.parse("14:30", locale: :en) == {:ok, ~T[14:30:00]}
    end

    test "returns a combined error when nothing matches" do
      assert {:error, %Calendrical.ParseError{attempts: attempts}} =
               Calendrical.parse("zzz9!!", locale: :en)

      assert {:date, %Calendrical.DateParseError{}} = List.keyfind(attempts, :date, 0)
      assert {:time, %Calendrical.TimeParseError{}} = List.keyfind(attempts, :time, 0)
      assert {:datetime, %Calendrical.DateTimeParseError{}} = List.keyfind(attempts, :datetime, 0)
    end
  end

  describe "error constructors" do
    test "calendar and territory errors" do
      assert Calendrical.calendar_error(:foo) ==
               %Localize.UnknownCalendarError{calendar: :foo}

      assert Calendrical.unknown_calendar_error(:foo) ==
               %Localize.UnknownCalendarError{calendar: :foo}

      assert Calendrical.unknown_territory_error(:foo) ==
               %Localize.UnknownTerritoryError{territory: :foo}

      assert Calendrical.invalid_calendar_error(Enum) ==
               %Calendrical.InvalidCalendarModuleError{module: Enum}
    end

    test "missing field errors" do
      assert Calendrical.missing_date_error("f", 1, nil, nil) ==
               %Calendrical.MissingFieldsError{
                 function: "f",
                 fields: [year: 1, month: nil, day: nil]
               }

      assert Calendrical.missing_year_month_error("f", nil, 2) ==
               %Calendrical.MissingFieldsError{function: "f", fields: [year: nil, month: 2]}

      assert Calendrical.missing_year_error("f", nil) ==
               %Calendrical.MissingFieldsError{function: "f", fields: [year: nil]}

      assert Calendrical.missing_month_error("f", nil) ==
               %Calendrical.MissingFieldsError{function: "f", fields: [month: nil]}

      assert Calendrical.missing_day_error("f", nil) ==
               %Calendrical.MissingFieldsError{function: "f", fields: [day: nil]}
    end
  end

  describe "quoted pattern helpers" do
    test "return quoted map patterns" do
      assert {:%{}, _, fields} = Calendrical.datetime()
      assert Keyword.has_key?(fields, :time_zone)

      assert {:%{}, _, fields} = Calendrical.naivedatetime()
      assert Keyword.has_key?(fields, :microsecond)

      assert {:%{}, _, fields} = Calendrical.date()
      assert Keyword.has_key?(fields, :year)

      assert {:%{}, _, fields} = Calendrical.time()
      assert Keyword.has_key?(fields, :hour)
    end
  end
end
