defmodule Calendrical.CoverageParsingTest do
  use ExUnit.Case, async: true

  # Systematic coverage of the parser engines through their public
  # entry points: `Calendrical.parse/2`, `Calendrical.Date.parse/2`,
  # `Calendrical.Date.parse_range/2`, `Calendrical.Time.parse/2`, and
  # `Calendrical.DateTime.parse/2`, plus the ISO-8601 calendar
  # callbacks that route through `Calendrical.Parse`.
  #
  # Each documented lenient-parsing behavior from CHANGELOG 0.6.0
  # through 0.9.1 is exercised at least once, in a non-:en locale
  # where applicable.

  @reference_date ~D[2026-07-05]

  # ── Date: ISO 8601 escape hatches (accepted in every locale) ──

  describe "Date.parse/2 ISO 8601 forms" do
    test "extended format in :fr" do
      assert Calendrical.Date.parse("2026-05-23", locale: :fr) == {:ok, ~D[2026-05-23]}
    end

    test "basic format (YYYYMMDD) in :ja" do
      assert Calendrical.Date.parse("20260523", locale: :ja) == {:ok, ~D[2026-05-23]}
    end

    test "ordinal date (YYYY-DDD) in :ja" do
      assert Calendrical.Date.parse("2026-143", locale: :ja) == {:ok, ~D[2026-05-23]}
    end

    test "ISO week date (YYYY-Www-D) in :ja" do
      assert Calendrical.Date.parse("2026-W21-6", locale: :ja) == {:ok, ~D[2026-05-23]}
    end
  end

  # ── Date: documented lenient behaviors ──

  describe "Date.parse/2 lenient behaviors" do
    test "M<->d swap under :en (CLDR ships MMM d, y)" do
      assert Calendrical.Date.parse("23 May 2026", locale: :en) == {:ok, ~D[2026-05-23]}
      assert Calendrical.Date.parse("23 Feb 2013", locale: :en) == {:ok, ~D[2013-02-23]}
    end

    test "M<->d swap under :fr (CLDR ships d MMM y)" do
      assert Calendrical.Date.parse("mai 23", locale: :fr, reference_date: @reference_date) ==
               {:ok, ~D[2026-05-23]}
    end

    test "case-insensitive month names in :fr" do
      assert Calendrical.Date.parse("23 Mai", locale: :fr, reference_date: @reference_date) ==
               {:ok, ~D[2026-05-23]}

      assert Calendrical.Date.parse("23 mai 2026", locale: :fr) == {:ok, ~D[2026-05-23]}
    end

    test "abbreviated month with omitted period in :fr (CLDR ships janv.)" do
      assert Calendrical.Date.parse("5 janv 2026", locale: :fr) == {:ok, ~D[2026-01-05]}
    end

    test "abbreviated month with added period in :en (CLDR ships Jun)" do
      assert Calendrical.Date.parse("01/Jun./2018", locale: :en) == {:ok, ~D[2018-06-01]}
    end

    test "dash/slash/period-separated swap variants in :en" do
      assert Calendrical.Date.parse("01-Feb-18", locale: :en, reference_date: @reference_date) ==
               {:ok, ~D[2018-02-01]}

      assert Calendrical.Date.parse("01.Feb.2018", locale: :en) == {:ok, ~D[2018-02-01]}
    end

    test "comma omission in :en (CLDR ships MMM d, y)" do
      assert Calendrical.Date.parse("May 5 2026", locale: :en) == {:ok, ~D[2026-05-05]}
    end

    test "interior double whitespace is collapsed" do
      assert Calendrical.Date.parse("May  5,  2026", locale: :en) == {:ok, ~D[2026-05-05]}
    end

    test "weekday-prefix stripping in :en" do
      assert Calendrical.Date.parse("Sun, 01 January 2017", locale: :en) == {:ok, ~D[2017-01-01]}

      assert Calendrical.Date.parse("Tuesday, November 29, 2016", locale: :en) ==
               {:ok, ~D[2016-11-29]}
    end

    test "weekday-prefix stripping in :fr" do
      assert Calendrical.Date.parse("lundi, 1 janvier 2025", locale: :fr) == {:ok, ~D[2025-01-01]}
    end

    test "ordinal-suffix stripping in :en" do
      assert Calendrical.Date.parse("1st January 2026", locale: :en) == {:ok, ~D[2026-01-01]}
      assert Calendrical.Date.parse("3rd March 2023", locale: :en) == {:ok, ~D[2023-03-03]}
    end

    test "ordinal-suffix stripping in :fr" do
      assert Calendrical.Date.parse("1er janvier 2025", locale: :fr) == {:ok, ~D[2025-01-01]}
    end

    test "ordinal-prefix stripping in :ja (RBNF renders 第16)" do
      assert Calendrical.Date.parse("2026年5月第16日", locale: :ja) == {:ok, ~D[2026-05-16]}
    end

    test "locale-preferred numeric orders" do
      assert Calendrical.Date.parse("16.05.2026", locale: :de) == {:ok, ~D[2026-05-16]}
      assert Calendrical.Date.parse("16. Mai 2026", locale: :de) == {:ok, ~D[2026-05-16]}
      assert Calendrical.Date.parse("2026/05/16", locale: :ja) == {:ok, ~D[2026-05-16]}
      assert Calendrical.Date.parse("2026年5月16日", locale: :ja) == {:ok, ~D[2026-05-16]}
    end

    test "two-digit year pivots against the reference date" do
      assert Calendrical.Date.parse("5/16/26", locale: :en, reference_date: @reference_date) ==
               {:ok, ~D[2026-05-16]}
    end

    test "quarter and week skeletons in :en" do
      assert Calendrical.Date.parse("Q2 2026", locale: :en) == {:ok, ~D[2026-04-01]}
      assert Calendrical.Date.parse("2nd quarter 2026", locale: :en) == {:ok, ~D[2026-04-01]}
      assert Calendrical.Date.parse("week 20 of 2026", locale: :en) == {:ok, ~D[2026-05-11]}
    end

    test "trailing weekday name is validated against the date in :ja" do
      # 2026-05-16 is a Saturday; the CLDR :ja full pattern carries EEEE.
      assert Calendrical.Date.parse("2026年5月16日土曜日", locale: :ja) == {:ok, ~D[2026-05-16]}
    end

    test "mismatched trailing weekday name rejects the parse in :ja" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("2026年5月16日月曜日", locale: :ja)
    end
  end

  # ── Date: calendars ──

  describe "Date.parse/2 calendar handling" do
    test ":calendar as CLDR key returns a date in that calendar" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en, calendar: :hebrew) ==
               {:ok, ~D[5786-09-29 Calendrical.Hebrew]}
    end

    test ":calendar as module is coerced via cldr_calendar_type/0" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en, calendar: Calendrical.Hebrew) ==
               {:ok, ~D[5786-09-29 Calendrical.Hebrew]}
    end

    test "return_calendar: :iso forces Calendar.ISO" do
      assert Calendrical.Date.parse("2026-05-16",
               locale: :en,
               calendar: :hebrew,
               return_calendar: :iso
             ) == {:ok, ~D[2026-05-16]}
    end

    test "return_calendar as a module converts the result" do
      assert Calendrical.Date.parse("2026-05-16",
               locale: :en,
               return_calendar: Calendrical.Persian
             ) == {:ok, ~D[1405-02-26 Calendrical.Persian]}
    end

    test "unknown CLDR calendar key falls back to Calendar.ISO for the ISO path" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en, calendar: :bogus) ==
               {:ok, ~D[2026-05-16]}
    end

    test "Japanese imperial era year resolves to the calendar year" do
      assert Calendrical.Date.parse("令和8年5月16日", locale: :ja, calendar: :japanese) ==
               {:ok, ~D[2026-05-16 Calendrical.Japanese]}
    end

    test "chinese calendar parses ISO input (no CLDR eras exist for it)" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en, calendar: :chinese) ==
               {:ok, ~D[4663-03-30 Calendrical.Chinese]}
    end

    test "chinese calendar rejects a numeric pattern that builds no valid date" do
      assert {:error, %Calendrical.DateParseError{calendar: :chinese}} =
               Calendrical.Date.parse("4/10/4663", locale: :en, calendar: :chinese)
    end
  end

  # ── Date: as: :map ──

  describe "Date.parse/2 with as: :map" do
    test "partial month + day in :en" do
      assert Calendrical.Date.parse("May 5", locale: :en, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, month: 5, day: 5}}
    end

    test "year only in :en" do
      assert Calendrical.Date.parse("2026", locale: :en, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, year: 2026}}
    end

    test "month only in :fr" do
      assert Calendrical.Date.parse("mai", locale: :fr, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, month: 5}}
    end

    test "month + year in :de" do
      assert Calendrical.Date.parse("Mai 2026", locale: :de, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, month: 5, year: 2026}}
    end
  end

  # ── Date: error paths ──

  describe "Date.parse/2 error paths" do
    test "unparseable input returns a DateParseError with a rendered message" do
      assert {:error, %Calendrical.DateParseError{} = error} =
               Calendrical.Date.parse("not a date", locale: :en)

      assert error.input == "not a date"
      assert error.locale == :en
      assert error.calendar == :gregorian

      assert Exception.message(error) ==
               "could not parse \"not a date\" as a date in locale :en " <>
                 "(calendar :gregorian); ISO-8601 (YYYY-MM-DD) is always accepted as a fallback"
    end

    test "unparseable input in :de (locale without ordinal suffixes)" do
      assert {:error, %Calendrical.DateParseError{locale: :de}} =
               Calendrical.Date.parse("kauderwelsch", locale: :de)
    end

    test "unparseable input in :ru (bare-digit ordinal RBNF)" do
      assert {:error, %Calendrical.DateParseError{locale: :ru}} =
               Calendrical.Date.parse("абракадабра", locale: :ru)
    end

    test "week number out of range" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("week 99 of 2026", locale: :en)
    end

    test "day that does not exist in the month" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("February 31, 2026", locale: :en)
    end

    test "day of month out of range" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("May 45, 2026", locale: :en)
    end

    test "numeric month out of range" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("25/45/6789", locale: :en)
    end

    test "invalid day for a coptic month" do
      assert {:error, %Calendrical.DateParseError{calendar: :coptic}} =
               Calendrical.Date.parse("13/8/1742", locale: :en, calendar: :coptic)
    end
  end

  # ── Date ranges ──

  describe "Date.parse_range/2 lenient behaviors" do
    test "CLDR en-dash interval with year inheritance" do
      assert Calendrical.Date.parse_range("May 5 – May 10, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "ASCII hyphen where CLDR declares an en-dash" do
      assert Calendrical.Date.parse_range("May 23 - 25, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-23], ~D[2026-05-25])}
    end

    test "wide month where the pattern declares abbreviated" do
      assert Calendrical.Date.parse_range("May 5 – June 10, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-06-10])}

      assert Calendrical.Date.parse_range("May 5 – Jun 10, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-06-10])}
    end

    test "day-first cross-endpoint month shift" do
      assert Calendrical.Date.parse_range("23 - 25 May, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-23], ~D[2026-05-25])}
    end

    test "day-first per-endpoint month/day swap" do
      assert Calendrical.Date.parse_range("5 May – 10 June, 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-06-10])}
    end

    test "comma omission in a range" do
      assert Calendrical.Date.parse_range("23 – 25 May 2026", locale: :en) ==
               {:ok, Date.range(~D[2026-05-23], ~D[2026-05-25])}
    end

    test "two-digit years in both endpoints pivot" do
      assert Calendrical.Date.parse_range("5/5/26 – 5/10/26",
               locale: :en,
               reference_date: @reference_date
             ) == {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "range in :fr" do
      assert Calendrical.Date.parse_range("5 mai – 10 mai 2026", locale: :fr) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.Date.parse_range("5–10 mai 2026", locale: :fr) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "range in :de" do
      assert Calendrical.Date.parse_range("5.–10. Mai 2026", locale: :de) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.Date.parse_range("05.05.2026 – 10.05.2026", locale: :de) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "range in :ja with wave-dash separator" do
      assert Calendrical.Date.parse_range("2026年5月5日～5月10日", locale: :ja) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.Date.parse_range("2026/05/05～2026/05/10", locale: :ja) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "range in :es (patterns with quoted 'de' literals)" do
      assert {:ok, %Date.Range{}} =
               Calendrical.Date.parse_range("5 de mayo – 10 de mayo de 2026", locale: :es)
    end

    test "japanese-era range endpoints inherit the era year" do
      assert Calendrical.Date.parse_range("令和8年5月5日～5月10日", locale: :ja, calendar: :japanese) ==
               {:ok,
                Date.range(
                  ~D[2026-05-05 Calendrical.Japanese],
                  ~D[2026-05-10 Calendrical.Japanese]
                )}
    end

    test "endpoints are returned in the requested calendar" do
      assert Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"}, calendar: :buddhist) ==
               {:ok,
                Date.range(
                  ~D[2569-05-05 Calendrical.Buddhist],
                  ~D[2569-05-10 Calendrical.Buddhist]
                )}

      assert Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"},
               calendar: Calendrical.Hebrew
             ) ==
               {:ok,
                Date.range(~D[5786-09-18 Calendrical.Hebrew], ~D[5786-09-23 Calendrical.Hebrew])}
    end
  end

  describe "Date.parse_range/2 with as: :map" do
    test "year inheritance across endpoints" do
      assert Calendrical.Date.parse_range("May 5 – May 10, 2026", locale: :en, as: :map) ==
               {:ok,
                {%{calendar: Calendar.ISO, year: 2026, month: 5, day: 5},
                 %{calendar: Calendar.ISO, year: 2026, month: 5, day: 10}}}
    end

    test "month-only endpoints omit the day key" do
      assert Calendrical.Date.parse_range("May – June 2026", locale: :en, as: :map) ==
               {:ok,
                {%{calendar: Calendar.ISO, month: 5, year: 2026},
                 %{calendar: Calendar.ISO, month: 6, year: 2026}}}
    end

    test "pair form returns two maps" do
      assert Calendrical.Date.parse_range({"May 5, 2026", "May 10, 2026"},
               locale: :en,
               as: :map
             ) ==
               {:ok,
                {%{calendar: Calendar.ISO, year: 2026, month: 5, day: 5},
                 %{calendar: Calendar.ISO, year: 2026, month: 5, day: 10}}}
    end
  end

  describe "Date.parse_range/2 inverted ranges" do
    test "inverted single-string range is rejected by default" do
      assert {:error, %Calendrical.DateRangeParseError{} = error} =
               Calendrical.Date.parse_range("2026-05-10 – 2026-05-05", locale: :en)

      assert error.reason == :inverted
      assert error.from == ~D[2026-05-10]
      assert error.to == ~D[2026-05-05]

      assert Exception.message(error) ==
               "range end ~D[2026-05-05] is before start ~D[2026-05-10]; " <>
                 "pass `allow_inverted: true` to permit descending ranges"
    end

    test "inverted single-string range with allow_inverted: true descends" do
      assert Calendrical.Date.parse_range("2026-05-10 – 2026-05-05",
               locale: :en,
               allow_inverted: true
             ) == {:ok, Date.range(~D[2026-05-10], ~D[2026-05-05], -1)}
    end

    test "inverted pair form is rejected by default" do
      assert {:error, %Calendrical.DateRangeParseError{reason: :inverted}} =
               Calendrical.Date.parse_range({"2026-05-10", "2026-05-05"}, locale: :en)
    end

    test "inverted pair form with allow_inverted: true descends" do
      assert Calendrical.Date.parse_range({"2026-05-10", "2026-05-05"},
               locale: :en,
               allow_inverted: true
             ) == {:ok, Date.range(~D[2026-05-10], ~D[2026-05-05], -1)}
    end
  end

  describe "Date.parse_range/2 error paths" do
    test ":no_separator reason and message" do
      assert {:error, %Calendrical.DateRangeParseError{} = error} =
               Calendrical.Date.parse_range("gibberish", locale: :en)

      assert error.reason == :no_separator
      assert error.locale == :en
      assert Exception.message(error) =~ "could not find an interval separator in \"gibberish\""
    end

    test ":from_parse_failed carries the endpoint cause" do
      assert {:error, %Calendrical.DateRangeParseError{} = error} =
               Calendrical.Date.parse_range({"nonsense", "2026-05-10"}, locale: :en)

      assert error.reason == :from_parse_failed
      assert %Calendrical.DateParseError{input: "nonsense"} = error.cause

      assert Exception.message(error) =~
               "range from-endpoint \"nonsense\" could not be parsed: could not parse"
    end

    test ":to_parse_failed carries the endpoint cause" do
      assert {:error, %Calendrical.DateRangeParseError{} = error} =
               Calendrical.Date.parse_range({"2026-05-10", "nonsense"}, locale: :en)

      assert error.reason == :to_parse_failed
      assert %Calendrical.DateParseError{input: "nonsense"} = error.cause
    end

    test "endpoint failure after separator split" do
      assert {:error, %Calendrical.DateRangeParseError{reason: :from_parse_failed}} =
               Calendrical.Date.parse_range("25/45/2026 – 27/46/2026", locale: :en)
    end

    test "reason_atoms/0 enumerates the closed reason set" do
      assert Calendrical.DateRangeParseError.reason_atoms() ==
               [:no_separator, :inverted, :from_parse_failed, :to_parse_failed]
    end

    test "catch-all message for an exception without a reason" do
      error = Calendrical.DateRangeParseError.exception(input: "x")
      assert Exception.message(error) == "could not parse \"x\" as a date range"
    end
  end

  # ── Time ──

  describe "Time.parse/2" do
    test "ISO 8601 forms" do
      assert Calendrical.Time.parse("14:30:15", locale: :en) == {:ok, ~T[14:30:15]}
      assert Calendrical.Time.parse("14:30:15.5", locale: :en) == {:ok, ~T[14:30:15.5]}
    end

    test "12-hour clock with day-period marker in :en" do
      assert Calendrical.Time.parse("2:30 PM", locale: :en) == {:ok, ~T[14:30:00]}
      assert Calendrical.Time.parse("11 am", locale: :en) == {:ok, ~T[11:00:00]}
    end

    test "day-period boundaries: noon and midnight" do
      assert Calendrical.Time.parse("12 noon", locale: :en) == {:ok, ~T[12:00:00]}
      assert Calendrical.Time.parse("12 midnight", locale: :en) == {:ok, ~T[00:00:00]}
    end

    test "flexible day periods disambiguate AM/PM in :en" do
      assert Calendrical.Time.parse("10 in the morning", locale: :en) == {:ok, ~T[10:00:00]}
      assert Calendrical.Time.parse("4 in the afternoon", locale: :en) == {:ok, ~T[16:00:00]}
      assert Calendrical.Time.parse("10 at night", locale: :en) == {:ok, ~T[22:00:00]}
    end

    test "narrow day-period markers do not consume zone letters" do
      # Regression shape from 0.7.0: "P" must not match as day_period
      # leaving "ST" as the zone.
      assert Calendrical.Time.parse("11:30 PST", locale: :en) == {:ok, ~T[11:30:00]}
    end

    test "non-:en locales" do
      assert Calendrical.Time.parse("14:30", locale: :fr) == {:ok, ~T[14:30:00]}
      assert Calendrical.Time.parse("午前11:30", locale: :ja) == {:ok, ~T[11:30:00]}
    end

    test "as: :map returns only supplied fields" do
      assert Calendrical.Time.parse("11 am", locale: :en, as: :map) == {:ok, %{hour: 11}}

      assert Calendrical.Time.parse("14:30:15", locale: :en, as: :map) ==
               {:ok, %{hour: 14, minute: 30, second: 15}}

      assert Calendrical.Time.parse("14:30:15.25", locale: :en, as: :map) ==
               {:ok, %{hour: 14, minute: 30, second: 15, microsecond: {250_000, 2}}}
    end

    test "as: :map surfaces a captured zone" do
      assert Calendrical.Time.parse("11:30 PST", locale: :en, as: :map) ==
               {:ok, %{hour: 11, minute: 30, time_zone: "PST"}}
    end

    test "unparseable input returns a TimeParseError with a rendered message" do
      assert {:error, %Calendrical.TimeParseError{} = error} =
               Calendrical.Time.parse("not a time", locale: :en)

      assert error.input == "not a time"
      assert error.locale == :en

      assert Exception.message(error) ==
               "could not parse \"not a time\" as a time in locale :en; " <>
                 "ISO-8601 (HH:MM[:SS[.frac]]) is always accepted as a fallback"
    end
  end

  # ── DateTime ──

  describe "DateTime.parse/2" do
    test "ISO 8601 with T and with space separator" do
      assert Calendrical.DateTime.parse("2026-05-23T14:30:00", locale: :en) ==
               {:ok, ~N[2026-05-23 14:30:00]}

      assert Calendrical.DateTime.parse("2026-05-23 14:30:00", locale: :en) ==
               {:ok, ~N[2026-05-23 14:30:00]}
    end

    test "ISO 8601 with zone information returns a DateTime" do
      assert Calendrical.DateTime.parse("2026-05-23T14:30:00Z", locale: :en) ==
               {:ok, ~U[2026-05-23 14:30:00Z]}

      assert Calendrical.DateTime.parse("2026-05-23T14:30:00+05:00", locale: :en) ==
               {:ok, ~U[2026-05-23 09:30:00Z]}
    end

    test "universal fallback glue separators" do
      assert Calendrical.DateTime.parse("01/01/2018 14:44", locale: :en) ==
               {:ok, ~N[2018-01-01 14:44:00]}

      assert Calendrical.DateTime.parse("01/01/2018 - 17:06", locale: :en) ==
               {:ok, ~N[2018-01-01 17:06:00]}

      assert Calendrical.DateTime.parse("23-05-2019 @ 10:01", locale: :de) ==
               {:ok, ~N[2019-05-23 10:01:00]}
    end

    test "locale glue with and without the CLDR comma in :en" do
      assert Calendrical.DateTime.parse("May 16, 2026, 2:30 PM", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}

      assert Calendrical.DateTime.parse("May 16, 2026 2:30 PM", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "non-:en locales" do
      assert Calendrical.DateTime.parse("16/05/2026 14:30", locale: :fr) ==
               {:ok, ~N[2026-05-16 14:30:00]}

      assert Calendrical.DateTime.parse("16.05.2026, 14:30", locale: :de) ==
               {:ok, ~N[2026-05-16 14:30:00]}

      assert Calendrical.DateTime.parse("2026/05/16 14:30", locale: :ja) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "weekday prefix and ordinal suffix strip in a datetime" do
      assert Calendrical.DateTime.parse("Wednesday 3rd March 2023 3:45 PM", locale: :en) ==
               {:ok, ~N[2023-03-03 15:45:00]}
    end

    test "zone abbreviation resolves to a DateTime" do
      assert {:ok, %DateTime{time_zone: "America/Los_Angeles", hour: 14, minute: 30}} =
               Calendrical.DateTime.parse("May 16, 2026 2:30 PM PST", locale: :en)
    end

    test "IANA zone name resolves to a DateTime" do
      assert {:ok, %DateTime{time_zone: "Asia/Tokyo", hour: 14, minute: 30}} =
               Calendrical.DateTime.parse("May 16, 2026 2:30 PM Asia/Tokyo", locale: :en)
    end

    test "unresolvable zone abbreviation falls back to a NaiveDateTime" do
      assert Calendrical.DateTime.parse("May 16, 2026 2:30 PM XQZV", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "GMT-format offset resolves to a fixed-offset DateTime" do
      assert {:ok, %DateTime{utc_offset: offset, hour: 14, minute: 30}} =
               Calendrical.DateTime.parse("May 16, 2026 2:30 PM GMT+10:30", locale: :en)

      assert offset == 37_800
    end

    test "as: :map for the ISO path" do
      assert Calendrical.DateTime.parse("2026-05-23T14:30:00", locale: :en, as: :map) ==
               {:ok,
                %{
                  calendar: Calendar.ISO,
                  year: 2026,
                  month: 5,
                  day: 23,
                  hour: 14,
                  minute: 30,
                  second: 0
                }}
    end

    test "as: :map surfaces microseconds and zone fields" do
      assert Calendrical.DateTime.parse("2026-05-23T14:30:00.5Z", locale: :en, as: :map) ==
               {:ok,
                %{
                  calendar: Calendar.ISO,
                  year: 2026,
                  month: 5,
                  day: 23,
                  hour: 14,
                  minute: 30,
                  second: 0,
                  microsecond: {500_000, 1},
                  time_zone: "Etc/UTC",
                  zone_abbr: "UTC",
                  utc_offset: 0,
                  std_offset: 0
                }}
    end

    test "as: :map for the locale-glue path" do
      assert Calendrical.DateTime.parse("May 16, 2026 2:30 PM", locale: :en, as: :map) ==
               {:ok,
                %{calendar: Calendar.ISO, year: 2026, month: 5, day: 16, hour: 14, minute: 30}}
    end

    test "ISO-shaped input with an invalid time falls through to an error" do
      assert {:error, %Calendrical.DateTimeParseError{}} =
               Calendrical.DateTime.parse("2026-05-16 14:30:99", locale: :en)
    end

    test "unparseable input returns a DateTimeParseError with a rendered message" do
      assert {:error, %Calendrical.DateTimeParseError{} = error} =
               Calendrical.DateTime.parse("utterly wrong", locale: :en)

      assert error.input == "utterly wrong"
      assert error.locale == :en

      assert Exception.message(error) ==
               "could not parse \"utterly wrong\" as a datetime in locale :en; " <>
                 "ISO-8601 (YYYY-MM-DDTHH:MM:SS[Z|±HH:MM]) is always accepted as a fallback"
    end
  end

  # ── Unified Calendrical.parse/2 ──

  describe "Calendrical.parse/2" do
    test "dispatches to the date parser" do
      assert Calendrical.parse("2026-05-16", locale: :en) == {:ok, ~D[2026-05-16]}
    end

    test "dispatches to the time parser" do
      assert Calendrical.parse("14:30", locale: :en) == {:ok, ~T[14:30:00]}
    end

    test "dispatches to the datetime parser" do
      assert Calendrical.parse("2026-05-16T14:30:00", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}

      assert Calendrical.parse("May 16, 2026 2:30 PM", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "dispatches to the interval parser" do
      assert Calendrical.parse("2026-05-05 – 2026-05-10", locale: :en) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "as: :map is forwarded to the winning sub-parser" do
      assert Calendrical.parse("May 5", locale: :en, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, month: 5, day: 5}}

      assert Calendrical.parse("11 am", locale: :en, as: :map) == {:ok, %{hour: 11}}
    end

    test "failure returns a ParseError recording every attempt" do
      assert {:error, %Calendrical.ParseError{} = error} = Calendrical.parse("xyzzy", locale: :en)

      assert [
               {:date, %Calendrical.DateParseError{}},
               {:time, %Calendrical.TimeParseError{}},
               {:datetime, %Calendrical.DateTimeParseError{}}
             ] = error.attempts

      assert Exception.message(error) ==
               "could not parse \"xyzzy\" as a date, time, datetime, or " <>
                 "interval in locale :en"
    end

    test "interval-shaped failure records the interval attempt first" do
      assert {:error, %Calendrical.ParseError{} = error} =
               Calendrical.parse("foo – bar", locale: :en)

      assert [
               {:interval, %Calendrical.DateRangeParseError{}},
               {:date, %Calendrical.DateParseError{}},
               {:time, %Calendrical.TimeParseError{}},
               {:datetime, %Calendrical.DateTimeParseError{}}
             ] = error.attempts
    end
  end

  # ── Calendrical.Parse via ISO-8601 calendar callbacks ──

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

  # ── Locale data variety ──
  #
  # These locales carry CLDR data shapes the mainstream locales do
  # not: :"en-CA" ships variant/standard pattern pairs, :nnh ships
  # patterns with unbalanced quote characters, :ee declares a
  # time-first `{0} {1}` datetime glue, :bal declares a nonstandard
  # interval fallback shape, :cy ships numeric quarter skeletons,
  # :aa has no flexible day periods, and the :buddhist calendar
  # ships standalone weekday-name (cccc) patterns.

  describe "locale data variety" do
    test "variant/standard pattern pairs in :en-CA" do
      assert Calendrical.Date.parse("May 5, 2026", locale: :"en-CA") == {:ok, ~D[2026-05-05]}
      assert Calendrical.Time.parse("2:30 PM", locale: :"en-CA") == {:ok, ~T[14:30:00]}
    end

    test "patterns with unbalanced quotes in :nnh do not crash the parsers" do
      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("blah blah", locale: :nnh)

      assert {:error, %Calendrical.TimeParseError{}} =
               Calendrical.Time.parse("blah", locale: :nnh)

      assert Calendrical.Time.parse("14:30", locale: :nnh) == {:ok, ~T[14:30:00]}
    end

    test "time-first datetime glue in :ee falls back to universal separators" do
      assert Calendrical.DateTime.parse("5/16/2026 14:30", locale: :ee) ==
               {:ok, ~N[2026-05-16 14:30:00]}

      assert {:error, %Calendrical.DateTimeParseError{}} =
               Calendrical.DateTime.parse("no such thing", locale: :ee)
    end

    test "nonstandard interval fallback shape in :bal still splits ranges" do
      assert Calendrical.Date.parse_range("2026-05-05 – 2026-05-10", locale: :bal) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.parse("2026-05-05 – 2026-05-10", locale: :bal) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "numeric quarter skeleton in :cy" do
      assert Calendrical.Date.parse("Ch2 2026", locale: :cy) == {:ok, ~D[2026-04-01]}
      assert Calendrical.Date.parse("2 2026", locale: :cy) == {:ok, ~D[2026-04-01]}

      assert {:error, %Calendrical.DateParseError{}} =
               Calendrical.Date.parse("0 2026", locale: :cy)
    end

    test "day-period name without flex-period data in :aa" do
      assert Calendrical.Time.parse("11:30 saaku", locale: :aa) == {:ok, ~T[11:30:00]}

      assert {:error, %Calendrical.TimeParseError{}} =
               Calendrical.Time.parse("qqq", locale: :aa)
    end

    test "buddhist-calendar patterns (with cccc weekday names) compile" do
      assert {:error, %Calendrical.DateParseError{calendar: :buddhist}} =
               Calendrical.Date.parse("blah", locale: :en, calendar: :buddhist)
    end

    test ":calendar accepts a string CLDR key" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en, calendar: "gregorian") ==
               {:ok, ~D[2026-05-16 Calendrical.Gregorian]}
    end

    test "split fallback in :bal when interval patterns do not match" do
      assert {:error, %Calendrical.DateRangeParseError{reason: :from_parse_failed}} =
               Calendrical.Date.parse_range("gibberish – 2026-05-10", locale: :bal)
    end

    test "range in :da (interval patterns with dot literals)" do
      assert Calendrical.Date.parse_range("5.–10. maj 2026", locale: :da) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.Date.parse_range("5. maj – 10. maj 2026", locale: :da) ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}
    end

    test "hebrew day out of range for the month is rejected" do
      assert {:error, %Calendrical.DateParseError{calendar: :hebrew}} =
               Calendrical.Date.parse("2/30/5787", locale: :en, calendar: :hebrew)
    end

    test "buddhist calendar day-first numeric pattern in :th" do
      assert Calendrical.Date.parse("16/5/2569", locale: :th, calendar: :buddhist) ==
               {:ok, ~D[2569-05-16 Calendrical.Buddhist]}

      assert {:error, %Calendrical.DateParseError{calendar: :buddhist}} =
               Calendrical.Date.parse("30/2/2570", locale: :th, calendar: :buddhist)
    end

    test "locale can be a string or a LanguageTag" do
      assert Calendrical.Date.parse("May 5, 2026", locale: "en") == {:ok, ~D[2026-05-05]}
      assert Calendrical.Time.parse("2:30 PM", locale: "en") == {:ok, ~T[14:30:00]}

      tag = Localize.LanguageTag.new!("en")
      assert Calendrical.Date.parse("May 5, 2026", locale: tag) == {:ok, ~D[2026-05-05]}
      assert Calendrical.Time.parse("2:30 PM", locale: tag) == {:ok, ~T[14:30:00]}
    end

    test "chinese-calendar range endpoints convert from ISO input" do
      assert Calendrical.Date.parse_range("2026-05-05 – 2026-05-10",
               locale: :en,
               calendar: :chinese
             ) ==
               {:ok,
                Date.range(~D[4663-03-19 Calendrical.Chinese], ~D[4663-03-24 Calendrical.Chinese])}
    end

    test "as: :map surfaces the zone captured through the locale glue" do
      assert Calendrical.DateTime.parse("May 16, 2026 2:30 PM PST", locale: :en, as: :map) ==
               {:ok,
                %{
                  calendar: Calendar.ISO,
                  year: 2026,
                  month: 5,
                  day: 16,
                  hour: 14,
                  minute: 30,
                  time_zone: "PST"
                }}
    end
  end

  # ── Default-options entry points ──

  describe "single-argument entry points" do
    test "each parser accepts input without options" do
      assert Calendrical.Date.Parser.parse("2026-05-16") == {:ok, ~D[2026-05-16]}

      assert Calendrical.Date.Parser.parse_range("2026-05-05 – 2026-05-10") ==
               {:ok, Date.range(~D[2026-05-05], ~D[2026-05-10])}

      assert Calendrical.Time.Parser.parse("14:30:15") == {:ok, ~T[14:30:15]}
      assert Calendrical.Time.Parser.parse_with_zone("14:30:15") == {:ok, ~T[14:30:15], nil}

      assert Calendrical.DateTime.Parser.parse("2026-05-23T14:30:00") ==
               {:ok, ~N[2026-05-23 14:30:00]}

      assert Calendrical.Parser.parse("2026-05-16") == {:ok, ~D[2026-05-16]}
    end
  end

  describe "regression: glue, day periods and interval determinism" do
    test "fr atTime glue separator parses" do
      assert Calendrical.DateTime.parse("16 mai 2026 à 14:30", locale: :fr) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "es day periods accept ASCII spaces for the shipped NBSP names" do
      assert Calendrical.Time.parse("3:30 a. m.", locale: :es) == {:ok, ~T[03:30:00]}
      assert Calendrical.Time.parse("3:30 p. m.", locale: :es) == {:ok, ~T[15:30:00]}
    end

    test "locale day-period names resolve AM/PM" do
      assert Calendrical.Time.parse("午後2:30", locale: :ja) == {:ok, ~T[14:30:00]}
      assert Calendrical.Time.parse("午前2:30", locale: :ja) == {:ok, ~T[02:30:00]}
    end

    test "map-mode ranges prefer day-bearing interval patterns deterministically" do
      assert Calendrical.Date.parse_range("May 5 – May 10", locale: :en, as: :map) ==
               {:ok,
                {%{calendar: Calendar.ISO, month: 5, day: 5},
                 %{calendar: Calendar.ISO, month: 5, day: 10}}}
    end
  end
end
