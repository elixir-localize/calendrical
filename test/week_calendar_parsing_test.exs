defmodule Calendrical.WeekCalendarParsing.Test do
  @moduledoc """
  A calendar of weeks names `Calendar.ISO` for parsing, with its
  `parsing_calendar/0`. Its months are CLDR's generic calendar's, "M02", so
  text that names a Gregorian month is none of its own formats' and is read
  as a Gregorian date and converted. Its own formats come first, so a date
  Localize writes for it reads back as itself, and a week date is its own
  week and day.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Hebrew
  alias Calendrical.ISOWeek
  alias Calendrical.NRF

  test "a calendar of weeks names Calendar.ISO for parsing, and a calendar of months itself" do
    for calendar <- [ISOWeek, NRF, Calendrical.CSCO] do
      assert calendar.parsing_calendar() == Calendar.ISO
    end

    for calendar <- [Calendrical.Gregorian, Hebrew, Calendrical.Persian, Calendrical.Julian] do
      assert calendar.parsing_calendar() == calendar
    end
  end

  # A month of a calendar of weeks has 28 days or 35, and a date reads back
  # on every one of them: 1 February 2024 is the 33rd day of NRF's twelfth
  # month of 2023, which begins on Sunday 31 December 2023.
  test "a date its own formats write reads back as itself" do
    assert Date.convert!(~D[2024-02-01], NRF) == ~D[2023-12-33 Calendrical.NRF]
    assert NRF.days_in_month(2023, 12) == 35

    for date <- [
          ~D[2026-06-16 Calendrical.ISOWeek],
          ~D[2026-12-35 Calendrical.ISOWeek],
          ~D[2023-12-33 Calendrical.NRF],
          ~D[2023-12-35 Calendrical.NRF],
          ~D[2024-01-01 Calendrical.NRF]
        ],
        format <- [:short, :medium, :long, :full],
        locale <- [:en, :de, :ja] do
      options = [format: format, locale: locale]
      {:ok, text} = Localize.Date.to_string(date, options)

      assert Localize.Date.parse(text, [calendar: date.calendar] ++ options) == {:ok, date},
             "#{inspect(date)} #{inspect(options)} #{inspect(text)}"
    end

    assert Localize.Date.to_string(~D[2026-06-16 Calendrical.ISOWeek], format: :long, locale: :en) ==
             {:ok, "M06 16, 2026 AD"}

    assert Localize.Date.parse("M06 16, 2026 AD", locale: :en, calendar: ISOWeek) ==
             {:ok, ~D[2026-06-16 Calendrical.ISOWeek]}
  end

  # 1 February 2024 is the Thursday of ISO week 5, the fourth day of the ISO
  # week calendar's second month, and a day of NRF's 2023, whose 2024 begins
  # on Sunday 4 February.
  test "text that names a Gregorian month is the Gregorian date, converted" do
    assert :calendar.iso_week_number({2024, 2, 1}) == {2024, 5}
    assert Date.convert!(~D[2024-02-01], ISOWeek) == ~D[2024-02-04 Calendrical.ISOWeek]

    for {text, locale} <- [
          {"Feb 1, 2024", :en},
          {"February 1, 2024", :en},
          {"Thu, Feb 1, 2024", :en},
          {"1. Februar 2024", :de},
          {"2024-02-01", :en}
        ] do
      assert Localize.Date.parse(text, locale: locale, calendar: ISOWeek) ==
               {:ok, ~D[2024-02-04 Calendrical.ISOWeek]},
             text

      assert Localize.Date.parse(text, locale: locale, calendar: NRF) ==
               {:ok, ~D[2023-12-33 Calendrical.NRF]},
             text
    end

    assert {:ok, datetime} =
             Localize.DateTime.parse("Feb 1, 2024, 10:30 AM", locale: :en, calendar: ISOWeek)

    assert NaiveDateTime.to_date(datetime) == ~D[2024-02-04 Calendrical.ISOWeek]
    assert {datetime.hour, datetime.minute} == {10, 30}
  end

  # The calendar's own formats come first. en.xml's generic short date writes
  # the era, so "2/1/2024 AD" is the first day of the calendar's second
  # month, Monday 29 January 2024 in the ISO week calendar and Sunday 3 March
  # in NRF, where the same digits without the era, which none of its formats
  # writes, are 1 February 2024.
  test "the digits of a date are the calendar's own where one of its formats reads them" do
    assert Date.convert!(~D[2024-02-01 Calendrical.ISOWeek], Calendar.ISO) == ~D[2024-01-29]
    assert Date.convert!(~D[2024-02-01 Calendrical.NRF], Calendar.ISO) == ~D[2024-03-03]

    for {calendar, own, gregorian} <- [
          {ISOWeek, ~D[2024-02-01 Calendrical.ISOWeek], ~D[2024-02-04 Calendrical.ISOWeek]},
          {NRF, ~D[2024-02-01 Calendrical.NRF], ~D[2023-12-33 Calendrical.NRF]}
        ] do
      for text <- ["2/1/2024 AD", "M02 1, 2024 AD"] do
        assert Localize.Date.parse(text, locale: :en, calendar: calendar) == {:ok, own}, text
      end

      assert Localize.Date.parse("2/1/2024", locale: :en, calendar: calendar) == {:ok, gregorian}
    end
  end

  # A week date is the calendar's own week and day, in every form ISO 8601
  # writes one in: NRF's weeks begin on Sunday, so its 2024-W05-4 is the
  # fourth day of its second month, Wednesday 6 March 2024, and no day of
  # ISO 8601's week 5.
  test "a week date is the calendar's own week and day" do
    assert NRF.date_from_week_date(2024, 5, 4) == ~D[2024-02-04 Calendrical.NRF]
    assert Date.convert!(~D[2024-02-04 Calendrical.NRF], Calendar.ISO) == ~D[2024-03-06]

    for text <- ["2024-W05-4", "2024W054"] do
      assert Localize.Date.parse(text, locale: :en, calendar: NRF) ==
               {:ok, ~D[2024-02-04 Calendrical.NRF]},
             text

      assert Localize.Date.parse(text, locale: :en, calendar: ISOWeek) ==
               {:ok, ~D[2024-02-04 Calendrical.ISOWeek]},
             text
    end

    assert Localize.Date.parse("2026-W25", locale: :en, calendar: ISOWeek) ==
             {:ok, ~D[2026-06-15 Calendrical.ISOWeek]}

    assert {:error, %Localize.DateParseError{}} =
             Localize.Date.parse("2025-W53-1", locale: :en, calendar: ISOWeek)
  end

  # The whole of a text is read in one calendar. 28 December 2026 and 3
  # January 2027 are the Monday and the Sunday of ISO week 53 of 2026, and
  # the calendar's own year does not turn between them: were each end read as
  # a Gregorian day and set in the calendar's years, the range was inverted.
  test "a range written as Gregorian dates is read whole as one" do
    assert :calendar.iso_week_number({2026, 12, 28}) == {2026, 53}
    assert :calendar.iso_week_number({2027, 1, 3}) == {2026, 53}

    week_53 =
      Date.range(
        ISOWeek.date_from_week_date(2026, 53, 1),
        ISOWeek.date_from_week_date(2026, 53, 7)
      )

    options = [locale: :en, calendar: ISOWeek, reference_date: ~D[2026-06-01]]

    for input <- ["Dec 28 – Jan 3", "December 28 to January 3", {"Dec 28", "Jan 3"}] do
      assert Localize.Interval.parse(input, options) == {:ok, week_53}, inspect(input)
    end

    assert Localize.Interval.parse("Feb 1 – 5, 2024", locale: :en, calendar: ISOWeek) ==
             {:ok,
              Date.range(~D[2024-02-04 Calendrical.ISOWeek], ~D[2024-02-08 Calendrical.ISOWeek])}
  end

  # A calendar of months names itself, so text its own formats do not read
  # is no date of it: the Hebrew calendar has no "Feb", and its numeric
  # date is written with its era.
  test "a calendar that names itself reads only its own formats" do
    assert Localize.Date.parse("2/1/5784 AM", locale: :en, calendar: Hebrew) ==
             {:ok, ~D[5784-02-01 Calendrical.Hebrew]}

    for text <- ["Feb 1, 2024", "2/1/2024", "2/1/5784"] do
      assert {:error, %Localize.DateParseError{}} =
               Localize.Date.parse(text, locale: :en, calendar: Hebrew),
             text
    end
  end
end
