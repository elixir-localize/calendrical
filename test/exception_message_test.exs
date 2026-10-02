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
    {Calendrical.UnsupportedDateRangeError,
     [value: ~D[0500-06-01], range: "dates covered by the installed JPL ephemeris"], "date",
     "The date {$value} is outside the supported range of {$range}",
     "The date ~D[0500-06-01] is outside the supported range of " <>
       "dates covered by the installed JPL ephemeris"},
    {Calendrical.Formatter.InvalidDateError, [date: "not a date"], "format",
     "Invalid date {$date}", "Invalid date \"not a date\""},
    {Calendrical.Formatter.InvalidOptionError, [option: :bogus, value: 42], "option",
     "Invalid option or option value. Found option {$option} with value {$value}",
     "Invalid option or option value. Found option :bogus with value 42"},
    {Calendrical.Formatter.UnknownFormatterError, [formatter: NotAFormatter], "format",
     "Invalid formatter {$formatter}", "Invalid formatter NotAFormatter"}
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
