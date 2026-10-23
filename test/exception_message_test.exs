defmodule Calendrical.ExceptionMessageTest do
  @moduledoc """
  Exercises `Exception.message/1` for every Calendrical exception.

  The rendered message is part of the public surface: it is what
  users see in logs and crash reports. Each message is written in
  MessageFormat 2 and interpolated by Localize through
  `Calendrical.Gettext`, and every exception must render it from its
  fields without raising, whatever the fields hold.

  The sentences expected here are written out by hand.

  """

  use ExUnit.Case, async: true

  # {exception, its fields, its message context, its message, the sentence}
  @messages [
    {Calendrical.IncompatibleCalendarError, [from: Calendar.ISO, to: Calendrical.Hebrew],
     "calendar", "The two values must be in the same calendar. Found {$from} and {$to}",
     "The two values must be in the same calendar. Found Calendar.ISO and Calendrical.Hebrew"},
    {Calendrical.IncompatibleTimeZoneError,
     [from: ~U[2026-01-01 00:00:00Z], to: "Australia/Sydney"], "date",
     "The two values must be in the same time zone. Found {$from} and {$to}",
     "The two values must be in the same time zone. " <>
       "Found ~U[2026-01-01 00:00:00Z] and \"Australia/Sydney\""},
    {Calendrical.InvalidCalendarModuleError, [module: NotACalendar], "calendar",
     "{$module} is not a calendar module.", "NotACalendar is not a calendar module."},
    {Calendrical.InvalidOptionValueError, [option: :day_start, value: :bogus], "option",
     "The option {$option} cannot take the value {$value}",
     "The option :day_start cannot take the value :bogus"},
    {Calendrical.InvalidSolarTermError, [index: 25], "calendar",
     "The solar term {$index} is not known. Solar terms are numbered 1 to 24",
     "The solar term 25 is not known. Solar terms are numbered 1 to 24"},
    {Calendrical.NoDuskError,
     [
       day_start: :sunset,
       location: %Geo.Point{coordinates: {18.9553, 69.6492}},
       date: ~D[2024-06-21]
     ], "date", "The sun does not set at {$location} on {$date}",
     "The sun does not set at {18.9553, 69.6492} on ~D[2024-06-21]"},
    {Calendrical.NoDuskError,
     [
       day_start: :nightfall,
       location: %Geo.Point{coordinates: {18.9553, 69.6492}},
       date: ~D[2024-06-21]
     ], "date", "Nightfall does not occur at {$location} on {$date}",
     "Nightfall does not occur at {18.9553, 69.6492} on ~D[2024-06-21]"},
    {Calendrical.UnknownOptionError,
     [maker: Calendrical.Calendar.Weeks, options: [:bogus], known_options: [:pattern]], "option",
     "{$maker} does not read the options {$options}. The options are {$known_options}",
     "Calendrical.Calendar.Weeks does not read the options [:bogus]. The options are [:pattern]"},
    {Calendrical.RemovedOptionError, [option: :return_calendar], "option",
     "The option {$option} was removed in Calendrical 2.0",
     "The option :return_calendar was removed in Calendrical 2.0"},
    {Calendrical.InvalidCompositeError, [reason: :no_calendars_configured], "calendar",
     "A composite calendar needs :calendars, the first day of each calendar that takes effect",
     "A composite calendar needs :calendars, the first day of each calendar that takes effect"},
    {Calendrical.InvalidCompositeError, [reason: :must_be_a_list_of_dates, value: [:nope]],
     "calendar",
     ":calendars must be dates, each in the calendar that takes effect on it. Found {$value}",
     ":calendars must be dates, each in the calendar that takes effect on it. Found [:nope]"},
    {Calendrical.InvalidCompositeError, [reason: :invalid_date, value: :nope], "calendar",
     "Each of :calendars must be a date of its own calendar. Found {$value}",
     "Each of :calendars must be a date of its own calendar. Found :nope"},
    {Calendrical.InvalidCompositeError,
     [reason: :must_not_be_composite_calendars, value: Calendrical.Reform.England], "calendar",
     "The calendars of a composite calendar must not be composite calendars. Found {$value}",
     "The calendars of a composite calendar must not be composite calendars. Found Calendrical.Reform.England"},
    {Calendrical.InvalidCompositeError,
     [reason: :must_not_be_week_calendars, value: Calendrical.ISOWeek], "calendar",
     "The calendars of a composite calendar must not be calendars of weeks. Found {$value}",
     "The calendars of a composite calendar must not be calendars of weeks. Found Calendrical.ISOWeek"},
    {Calendrical.InvalidCompositeError,
     [reason: :must_take_effect_on_different_days, value: ~D[1752-09-14]], "calendar",
     "Each of :calendars must take effect on a day of its own. Found {$value}",
     "Each of :calendars must take effect on a day of its own. Found ~D[1752-09-14]"},
    {Calendrical.InvalidCompositeError, [reason: :years_must_not_go_back, value: ~D[1900-01-01]],
     "calendar",
     "A calendar must not number its first year before the last year of the calendar before it. Found {$value}",
     "A calendar must not number its first year before the last year of the calendar before it. Found ~D[1900-01-01]"},
    {Calendrical.InvalidCompositeError, [reason: :other, value: 1], "calendar",
     "The composite calendar cannot be made: {$reason}. Found {$value}",
     "The composite calendar cannot be made: :other. Found 1"},
    {Calendrical.InvalidOptionValueError,
     [option: :weeks, value: 1, maker: Calendrical.Calendar.Weeks], "option",
     ":weeks must be a keyword list or :from_first_day. Found {$value}",
     ":weeks must be a keyword list or :from_first_day. Found 1"},
    {Calendrical.InvalidOptionValueError,
     [option: :months_in_year, value: 0, maker: Calendrical.Calendar], "option",
     ":months_in_year must be a count, or {$form}. Found {$value}",
     ":months_in_year must be a count, or {fewest, most}. Found 0"},
    {Calendrical.InvalidOptionValueError,
     [option: :year_begins, value: 1, maker: Calendrical.Calendar.Weeks], "option",
     ":year_begins must be {$form} with the day 1 to 7, or {$nearest}. Found {$value}",
     ":year_begins must be {weekday, :on_or_before, {month, day}} with the day 1 to 7, or {weekday, :nearest, {month, 4}}. Found 1"},
    {Calendrical.InvalidOptionValueError,
     [option: :year_begins, value: 1, maker: Calendrical.Calendar.Shifted], "option",
     ":year_begins must be {$form} of the base calendar. Found {$value}",
     ":year_begins must be {month, day} of the base calendar. Found 1"},
    {Calendrical.InvalidOptionValueError,
     [option: :year_ends, value: 1, maker: Calendrical.Calendar.Weeks], "option",
     ":year_ends must be {$form} with the day in the month's last seven, or {$nearest}. Found {$value}",
     ":year_ends must be {weekday, :on_or_after, {month, day}} with the day in the month's last seven, or {weekday, :nearest, {month, last_day}}. Found 1"},
    {Calendrical.InvalidOptionValueError,
     [option: [:year_begins, :year_ends], maker: Calendrical.Calendar.Weeks], "option",
     "A calendar of weeks takes :year_begins or :year_ends, not both",
     "A calendar of weeks takes :year_begins or :year_ends, not both"},
    {Calendrical.InvalidOptionValueError,
     [option: :pattern, value: [1, 2, 3], maker: Calendrical.Calendar.Weeks], "option",
     ":pattern must be [4, 4, 5], [4, 5, 4] or [5, 4, 4]. Found {$value}",
     ":pattern must be [4, 4, 5], [4, 5, 4] or [5, 4, 4]. Found [1, 2, 3]"},
    {Calendrical.InvalidOptionValueError,
     [option: :year_number, value: :bogus, maker: Calendrical.Calendar.Weeks], "option",
     ":year_number must be :beginning, :ending or :majority. Found {$value}",
     ":year_number must be :beginning, :ending or :majority. Found :bogus"},
    {Calendrical.InvalidOptionValueError,
     [option: :written_year, value: :bogus, maker: Calendrical.Calendar.Shifted], "option",
     ":written_year must be :base or :label. Found {$value}",
     ":written_year must be :base or :label. Found :bogus"},
    {Calendrical.InvalidOptionValueError,
     [option: :cldr_calendar_type, value: :hebrew, maker: Calendrical.Calendar.Weeks], "option",
     ":cldr_calendar_type must be :gregorian or :japanese. Found {$value}",
     ":cldr_calendar_type must be :gregorian or :japanese. Found :hebrew"},
    {Calendrical.InvalidOptionValueError,
     [option: :base, value: Calendrical.Hebrew, maker: Calendrical.Calendar.Shifted], "option",
     "The base calendar {$value} has a different number of months in different years. A shifted year needs a base with as many months in every year",
     "The base calendar Calendrical.Hebrew has a different number of months in different years. A shifted year needs a base with as many months in every year"},
    {Calendrical.InvalidOptionValueError, [option: :options, value: [1, 2]], "option",
     "The options must be a keyword list. Found {$value}",
     "The options must be a keyword list. Found [1, 2]"},
    {Calendrical.InvalidMonthError, [calendar: Calendrical.Gregorian, month: 14], "calendar",
     "The {$calendar} calendar has no month {$month}",
     "The Calendrical.Gregorian calendar has no month 14"},
    {Calendrical.InvalidMonthError, [calendar: Calendrical.Reform.England, year: 1751, month: 1],
     "calendar", "The {$calendar} calendar has no month {$month} in the year {$year}",
     "The Calendrical.Reform.England calendar has no month 1 in the year 1751"},
    {Calendrical.InvalidDateOrderError, [from: ~D[2026-06-01], to: ~D[2026-01-01]], "date",
     "The values must be ordered from earlier to later. Found {$from} and {$to}",
     "The values must be ordered from earlier to later. Found ~D[2026-06-01] and ~D[2026-01-01]"},
    {Calendrical.InvalidStyleError, [style: :bogus, valid_styles: [:short, :long]], "style",
     "The date style {$style} is not known. Valid styles are {$valid_styles}",
     "The date style :bogus is not known. Valid styles are [:short, :long]"},
    {Calendrical.InvalidPartError, [part: :bogus, valid_parts: [:year, :month]], "format",
     "The date part {$part} is not known. Valid date parts are {$valid_parts}",
     "The date part :bogus is not known. Valid date parts are [:year, :month]"},
    {Calendrical.InvalidTypeError, [type: :bogus, valid_types: [:date, :time]], "format",
     "The date format type {$type} is not known. Valid format types are {$valid_types}",
     "The date format type :bogus is not known. Valid format types are [:date, :time]"},
    {Calendrical.IslamicYearOutOfRangeError, [year: 5000, min_year: 1318, max_year: 1650],
     "calendar",
     "Hijri year {$year} is outside the supported Umm al-Qura range {$min_year}..{$max_year}",
     "Hijri year 5000 is outside the supported Umm al-Qura range 1318..1650"},
    {Calendrical.MissingFieldsError,
     [function: "localize", fields: [year: 2026, month: nil, day: nil]], "date",
     "{$function} requires at least {$required}. Found {$found}",
     "localize requires at least year, month, day. Found year: 2026, month: nil, day: nil"},
    {Calendrical.UnsupportedDateRangeError,
     [
       calendar: Calendrical.Persian,
       value: ~D[0900-06-01],
       range: "Gregorian years 1001 to 3000"
     ], "date", "The {$calendar} calendar supports dates in {$range}. Found {$value}",
     "The Calendrical.Persian calendar supports dates in Gregorian years 1001 to 3000. " <>
       "Found ~D[0900-06-01]"},
    {Calendrical.UnsupportedDateRangeError, [value: ~D[0500-06-01], range: 1..1500], "date",
     "The date {$value} is outside the supported range of {$range}",
     "The date ~D[0500-06-01] is outside the supported range of 1..1500"},
    {Calendrical.UnsupportedDateRangeError, [value: ~D[0500-06-01], range: :jpl_ephemeris],
     "date", "The date {$value} is outside the dates the installed JPL ephemeris covers",
     "The date ~D[0500-06-01] is outside the dates the installed JPL ephemeris covers"},
    {Calendrical.UnsupportedDateRangeError,
     [
       calendar: Calendrical.Islamic.Observational,
       value: ~D[0500-06-01],
       range: :jpl_ephemeris
     ], "date",
     "The {$calendar} calendar supports only the dates the installed JPL ephemeris covers. Found {$value}",
     "The Calendrical.Islamic.Observational calendar supports only the dates the installed " <>
       "JPL ephemeris covers. Found ~D[0500-06-01]"},
    {Calendrical.Formatter.InvalidDateError, [date: "not a date"], "format",
     "Invalid date {$date}", "Invalid date \"not a date\""},
    {Calendrical.Formatter.InvalidOptionError, [option: :bogus, value: 42], "option",
     "Invalid option or option value. Found option {$option} with value {$value}",
     "Invalid option or option value. Found option :bogus with value 42"},
    {Calendrical.Formatter.UnknownFormatterError, [formatter: NotAFormatter], "format",
     "Invalid formatter {$formatter}", "Invalid formatter NotAFormatter"},
    {Calendrical.InvalidDateError, [calendar: Calendrical.Gregorian, value: {2026, 2, 30}],
     "date", "{$value} is not a date of the {$calendar} calendar",
     "{2026, 2, 30} is not a date of the Calendrical.Gregorian calendar"},
    {Calendrical.InvalidDateError, [value: {4660, 1, 31}], "date", "{$value} is not a date",
     "{4660, 1, 31} is not a date"},
    {Calendrical.NotDefinedError, [calendar: Calendrical.Chinese, question: :years_in_cycle],
     "calendar", "The {$calendar} calendar does not define {$question}",
     "The Calendrical.Chinese calendar does not define :years_in_cycle"},
    {Calendrical.NotDefinedError,
     [calendar: Calendrical.Gregorian, question: :days_in_month, value: 14], "calendar",
     "The {$calendar} calendar does not define {$question} for {$value}",
     "The Calendrical.Gregorian calendar does not define :days_in_month for 14"},
    {Calendrical.UnknownReformError, [territory: :XX], "calendar",
     "No calendar reform is known for the territory {$territory}",
     "No calendar reform is known for the territory :XX"},
    {Calendrical.UnknownFiscalYearError, [territory: :AF], "calendar",
     "No fiscal year is known for the territory {$territory}",
     "No fiscal year is known for the territory :AF"},
    {Calendrical.AstronomyError, [calendar: Calendrical.Persian, value: 2026, reason: :no_time],
     "date",
     "{$calendar} cannot make its astronomical calculation for {$value}. Astro answered {$reason}",
     "Calendrical.Persian cannot make its astronomical calculation for 2026. Astro answered :no_time"},
    {Calendrical.IncompatibleCalendarError,
     [from: Calendrical.Hebrew, to: Calendrical.Gregorian, reason: :day_rollover], "calendar",
     "A date cannot be converted from {$from} to {$to}: their days begin at different times",
     "A date cannot be converted from Calendrical.Hebrew to Calendrical.Gregorian: " <>
       "their days begin at different times"},
    {Calendrical.UnsupportedDateRangeError,
     [
       calendar: Calendrical.Islamic.UmmAlQura.Astronomical,
       value: 1391,
       range: {:from, 1392}
     ], "date", "The {$calendar} calendar supports the years from {$first}. Found {$value}",
     "The Calendrical.Islamic.UmmAlQura.Astronomical calendar supports the years from 1392. " <>
       "Found 1391"}
  ]

  # What Exception.message/1 says when a message/1 callback raises.
  @raised "while retrieving Exception.message/1"

  describe "every exception" do
    for {module, fields, _context, _msgid, sentence} <- @messages do
      test "#{inspect(module)} says #{inspect(sentence)}" do
        exception = unquote(module).exception(unquote(Macro.escape(fields)))

        assert Exception.message(exception) == unquote(sentence)
      end
    end

    test "is covered" do
      {:ok, modules} = :application.get_key(:calendrical, :modules)

      exceptions =
        for module <- modules,
            Code.ensure_loaded?(module),
            function_exported?(module, :exception, 1),
            do: module

      assert Enum.sort(exceptions) ==
               @messages |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
    end
  end

  describe "a message" do
    test "writes a value as it is given, whatever characters it has" do
      exception =
        Calendrical.Formatter.InvalidOptionError.exception(
          option: :braces,
          value: %{a: "{$x} %{y} \\ }"}
        )

      assert Exception.message(exception) ==
               "Invalid option or option value. Found option :braces " <>
                 "with value %{a: \"{$x} %{y} \\\\ }\"}"
    end

    # A number put to a MessageFormat 2 message is formatted for the
    # locale, with a grouping separator: a year is written as it is.
    test "writes a year without a grouping separator" do
      exception =
        Calendrical.IslamicYearOutOfRangeError.exception(
          year: 12_345,
          min_year: 1,
          max_year: 1500
        )

      assert Exception.message(exception) ==
               "Hijri year 12345 is outside the supported Umm al-Qura range 1..1500"
    end

    test "never raises, whatever its fields hold" do
      for {module, fields, sentence} <- [
            {Calendrical.MissingFieldsError, [function: "localize/3", fields: [:year, :month]],
             "localize/3 requires at least :year, :month. Found :year, :month"},
            {Calendrical.MissingFieldsError, [function: :week_of_year, fields: [year: nil]],
             "week_of_year requires at least year. Found year: nil"},
            {Calendrical.MissingFieldsError, [], "nil requires at least nil. Found nil"},
            {Calendrical.MissingFieldsError, [function: {:a, 1}, fields: %{year: 1}],
             "{:a, 1} requires at least %{year: 1}. Found %{year: 1}"},
            {Calendrical.MissingFieldsError, [function: "f", fields: [:year | :month]],
             "f requires at least [:year | :month]. Found [:year | :month]"},
            {Calendrical.MissingFieldsError, [function: "f", fields: [{"year", 2026}]],
             "f requires at least {\"year\", 2026}. Found {\"year\", 2026}"},
            {Calendrical.UnsupportedDateRangeError, [value: ~D[0500-06-01], range: 1..5],
             "The date ~D[0500-06-01] is outside the supported range of 1..5"},
            {Calendrical.UnsupportedDateRangeError, [],
             "The date nil is outside the supported range of nil"}
          ] do
        message = Exception.message(module.exception(fields))

        refute message =~ @raised
        assert message == sentence
      end

      for {module, _fields, _context, _msgid, _sentence} <- @messages do
        message = Exception.message(module.exception([]))

        assert message != "", inspect(module)
        refute message =~ @raised, inspect(module)
      end
    end
  end

  describe "the Gettext backend" do
    test "interpolates with Localize's MessageFormat 2" do
      assert Calendrical.Gettext.__gettext__(:interpolation) == Localize.Gettext.Interpolation

      assert Gettext.dpgettext(
               Calendrical.Gettext,
               "calendrical",
               "calendar",
               "{$module} is not a calendar module.",
               module: "Sundial"
             ) == "Sundial is not a calendar module."
    end

    # The template is what `mix gettext.extract` writes from the messages
    # in the source: each is MessageFormat 2, marked for the interpolator
    # that reads it, and in the context its exception gives it.
    test "has a template of the messages, each in MessageFormat 2" do
      template = Expo.PO.parse_file!("priv/gettext/calendrical.pot")

      extracted =
        for message <- template.messages do
          msgid = IO.iodata_to_binary(message.msgid)

          assert Localize.Message.canonical_message(msgid, pretty: false) == {:ok, msgid}
          refute msgid =~ "%{"
          assert ["elixir-autogen", "icu-format"] -- List.flatten(message.flags) == []

          {message.msgctxt |> List.wrap() |> IO.iodata_to_binary(), msgid}
        end

      expected =
        for {_module, _fields, context, msgid, _sentence} <- @messages, do: {context, msgid}

      assert Enum.sort(extracted) == Enum.sort(expected)
    end
  end
end
