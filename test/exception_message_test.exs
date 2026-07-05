defmodule Calendrical.ExceptionMessageTest do
  @moduledoc """
  Exercises `Exception.message/1` for every Calendrical exception.

  The rendered message is part of the public surface: it is what
  users see in logs and crash reports. Every exception must render
  a non-empty message from its semantic fields without raising.

  """

  use ExUnit.Case, async: true

  @exceptions [
    {Calendrical.DateParseError,
     [input: "May 35 2026", locale: :en, calendar: Calendrical.Gregorian]},
    {Calendrical.DateTimeParseError, [input: "not a datetime", locale: :en]},
    {Calendrical.TimeParseError, [input: "25:99", locale: :en]},
    {Calendrical.ParseError, [input: "gibberish", locale: :en, attempts: []]},
    {Calendrical.IncompatibleCalendarError, [from: Calendar.ISO, to: Calendrical.Hebrew]},
    {Calendrical.IncompatibleTimeZoneError,
     [from: ~U[2026-01-01 00:00:00Z], to: "Australia/Sydney"]},
    {Calendrical.InvalidCalendarModuleError, [module: NotACalendar]},
    {Calendrical.InvalidDateOrderError, [from: ~D[2026-06-01], to: ~D[2026-01-01]]},
    {Calendrical.InvalidFormatError, [format: :bogus, valid_formats: [:short, :long]]},
    {Calendrical.InvalidPartError, [part: :bogus, valid_parts: [:year, :month]]},
    {Calendrical.InvalidTypeError, [type: :bogus, valid_types: [:date, :time]]},
    {Calendrical.IslamicYearOutOfRangeError, [year: 5000, min_year: 1318, max_year: 1650]},
    {Calendrical.MissingFieldsError, [function: "localize/3", fields: [:year, :month]]},
    {Calendrical.UnsupportedDateRangeError,
     [calendar: Calendrical.Persian, value: ~D[0900-06-01], range: "Gregorian years 1001 to 3000"]},
    {Calendrical.Formatter.InvalidDateError, [date: "not a date"]},
    {Calendrical.Formatter.InvalidOptionError, [option: :bogus, value: 42]},
    {Calendrical.Formatter.UnknownFormatterError, [formatter: NotAFormatter]}
  ]

  for {module, fields} <- @exceptions do
    test "#{inspect(module)} renders a message from its fields" do
      exception = unquote(module).exception(unquote(Macro.escape(fields)))
      message = Exception.message(exception)

      assert is_binary(message)
      assert message != ""
      refute message =~ "got the exception"
    end
  end

  describe "Calendrical.DateRangeParseError" do
    test "renders a message for every declared reason" do
      for reason <- Calendrical.DateRangeParseError.reason_atoms() do
        exception =
          Calendrical.DateRangeParseError.exception(
            input: "May 5 – May 1, 2026",
            reason: reason,
            locale: :en,
            from: ~D[2026-05-05],
            to: ~D[2026-05-01],
            cause: nil
          )

        message = Exception.message(exception)
        assert is_binary(message)
        assert message != "", "empty message for reason #{inspect(reason)}"
      end
    end

    test "the inverted reason names both endpoints" do
      exception =
        Calendrical.DateRangeParseError.exception(
          reason: :inverted,
          from: ~D[2026-05-05],
          to: ~D[2026-05-01]
        )

      message = Exception.message(exception)
      assert message =~ "2026-05-05"
      assert message =~ "2026-05-01"
    end
  end

  test "UnsupportedDateRangeError names the calendar, value and range" do
    exception =
      Calendrical.UnsupportedDateRangeError.exception(
        calendar: Calendrical.Persian,
        value: ~D[0900-06-01],
        range: "Gregorian years 1001 to 3000"
      )

    message = Exception.message(exception)
    assert message =~ "Calendrical.Persian"
    assert message =~ "0900-06-01"
    assert message =~ "1001 to 3000"
  end
end
