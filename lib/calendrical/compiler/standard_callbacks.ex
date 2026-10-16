defmodule Calendrical.Compiler.StandardCallbacks do
  @moduledoc false

  # The callbacks every calendar answers the same way unless it has an
  # answer of its own. `Calendrical`'s API is one surface every calendar
  # has, so a consumer asks `calendar.some_callback(...)` of any calendar
  # and never whether it can. Each maker of calendars (`use
  # Calendrical.Behaviour`, the month, week and Julian compilers, the
  # composite compiler) and `Calendrical.Julian` `use` this module beside
  # its `@behaviour Calendrical`, so a callback added to the behaviour is
  # given its default once, here, and every calendar has it.
  #
  # Each default is overridable: a calendar that defines the function later
  # in its module answers for itself. What is generated into a calendar is
  # as little as a call; logic that is more belongs in a plain module.
  #
  # A maker whose calendars mark none of their callbacks with `@impl` says
  # `impl: false`, since one mark in a module asks for a mark on every
  # callback it defines.

  defmacro __using__(options) do
    impl = if Keyword.get(options, :impl, true), do: quote(do: @impl(Calendrical))

    quote location: :keep do
      @doc """
      Returns the day of the month that names a date's day: the day
      itself, in a calendar whose day field is its own name.

      """
      unquote(impl)
      def cardinal_day(_year, _month, day), do: day

      @doc """
      Returns the number a date's month is written with in figures: the
      month itself, in a calendar whose month field is its own number.

      """
      unquote(impl)
      def numeric_month(_year, month, _day), do: month

      @doc """
      Returns the year a date is written with: its calendar year, in a
      calendar whose dates are written as its own.

      """
      unquote(impl)
      def cardinal_year(year, month, day), do: calendar_year(year, month, day)

      @doc """
      Returns the date of this calendar that a written date names: the
      year and the day as written, and the month of the year the named
      month is, in a calendar whose dates are written as its own.

      """
      unquote(impl)

      def date_from_cardinal_date(year, month, day),
        do: Calendrical.Base.Common.date_from_cardinal_date(__MODULE__, year, month, day)

      @doc """
      Returns the CLDR calendar type whose data names a date's months and
      days: this calendar's own, in a calendar named by one CLDR calendar
      throughout.

      """
      unquote(impl)
      def cldr_calendar_type(_year, _month, _day), do: cldr_calendar_type()

      @doc """
      Returns the calendars a date written for this calendar may be
      written in: this calendar alone, in a calendar whose dates are
      written in one notation.

      """
      unquote(impl)
      def parsing_calendars, do: [__MODULE__]

      @doc """
      Returns the number of months in a leap year: the most months a year
      of this calendar has.

      """
      unquote(impl)
      def months_in_leap_year, do: elem(months_in_year_bounds(), 1)

      @doc """
      Returns the traditional month at a position in a year: the month
      itself, in a calendar whose months are their own numbering.

      """
      unquote(impl)

      def lunar_month_of_year(year, month),
        do: Calendrical.Base.Common.lunar_month_of_year(__MODULE__, year, month)

      @doc """
      Returns the position in a year of a traditional month: the month
      itself, in a calendar whose months are their own numbering, which
      has no leap month.

      """
      unquote(impl)

      def ordinal_month_from_traditional(year, traditional_month),
        do:
          Calendrical.Base.Common.ordinal_month_from_traditional(
            __MODULE__,
            year,
            traditional_month
          )

      @doc """
      Returns the traditional number of the month a year's leap month
      follows: `nil`, in a calendar that has no leap month.

      """
      unquote(impl)
      def traditional_leap_month(_year), do: nil

      @doc """
      Returns a year's months in order, named traditionally, with any
      leap month among them.

      """
      unquote(impl)

      def traditional_months(year),
        do: Calendrical.Base.Common.traditional_months(__MODULE__, year)

      @doc """
      Returns the date of a day of a year, counted from the year's first
      day.

      """
      unquote(impl)

      def date_from_day_of_year(year, day_of_year),
        do: Calendrical.Base.Common.date_from_day_of_year(__MODULE__, year, day_of_year)

      @doc """
      Returns the days of a named month in a year, in the order of time:
      one range for each month the year counts that carries the name.

      """
      unquote(impl)

      def named_month(year, named_month),
        do: Calendrical.Base.Common.named_month(__MODULE__, year, named_month)

      @doc """
      Returns the weeks of a month of a year in order, each a
      `t:Date.Range.t/0` of the days `week_of_month/3` names for it.

      """
      unquote(impl)

      def weeks_of_month(year, month),
        do: Calendrical.Base.MonthWeeks.weeks_of_month(__MODULE__, year, month)

      defoverridable weeks_of_month: 2

      @doc """
      Returns a month of a year as this calendar names it: the month
      itself, in a calendar whose months are their own numbering, and
      `lunar_month_of_year/2`'s answer in a lunisolar calendar.

      """
      unquote(impl)

      def traditional_month(year, month),
        do: Calendrical.Base.Common.traditional_month(__MODULE__, year, month)

      @doc """
      Returns the ordinal month of a year a traditional month names: the
      month itself, in a calendar whose months are their own numbering,
      and `ordinal_month_from_traditional/2`'s answer in a lunisolar
      calendar.

      """
      unquote(impl)

      def month_from_traditional(year, traditional_month),
        do: Calendrical.Base.Common.month_from_traditional(__MODULE__, year, traditional_month)

      defoverridable traditional_month: 2, month_from_traditional: 2

      @doc """
      Returns the fewest and the most months a year has, as
      `months_in_year/0` answers them, as `{fewest, most}`.

      """
      unquote(impl)

      def months_in_year_bounds,
        do: Calendrical.Base.Bounds.months_in_year_bounds(__MODULE__)

      @doc """
      Returns the fewest and the most days a month has in any year, as
      `days_in_month/1` answers them, as `{fewest, most}`.

      """
      unquote(impl)

      def days_in_month_bounds(month),
        do: Calendrical.Base.Bounds.days_in_month_bounds(__MODULE__, month)

      defoverridable months_in_year_bounds: 0, days_in_month_bounds: 1

      @doc """
      Returns the months a year has, as runs of their numbers.

      """
      unquote(impl)
      def month_numbers(year), do: Calendrical.Base.Common.month_numbers(__MODULE__, year)

      @doc """
      Returns the days a month of a year has, as runs of their numbers.

      """
      unquote(impl)

      def day_numbers(year, month),
        do: Calendrical.Base.Common.day_numbers(__MODULE__, year, month)

      defoverridable month_numbers: 1, day_numbers: 2

      @doc """
      Returns the date of a day of a week of a week-year, in this
      calendar's own weeks.

      """
      unquote(impl)

      def date_from_week_date(week_year, week, day) do
        Calendrical.Base.WeekDate.date_from_week_date(__MODULE__, week_year, week, day)
      end

      @doc """
      Returns the week-year, the week and the day of the week of a date,
      in this calendar's own weeks.

      """
      unquote(impl)

      def week_date_from_date(year, month, day) do
        Calendrical.Base.WeekDate.week_date_from_date(__MODULE__, year, month, day)
      end

      @doc """
      Returns the number of weeks in a week-year, as many as
      `weeks_in_year/1` counts.

      """
      unquote(impl)

      def weeks_in_week_year(week_year) do
        Calendrical.Base.WeekDate.weeks_in_week_year(__MODULE__, week_year)
      end

      defoverridable date_from_week_date: 3, week_date_from_date: 3, weeks_in_week_year: 1

      @doc """
      Returns the number of years after which this calendar's years
      repeat: `{:error, :undefined}`, in a calendar that says no cycle.

      """
      unquote(impl)
      def years_in_cycle, do: {:error, :undefined}

      defoverridable years_in_cycle: 0

      @doc """
      Returns the day of a solar term of a Gregorian year, reckoned at
      the traditional reference for the solar terms, the Chinese
      calendar's meridian: this calendar is reckoned at no place.

      """
      unquote(impl)

      def solar_term(index, gregorian_year),
        do:
          Calendrical.Lunisolar.solar_term(
            index,
            gregorian_year,
            &Calendrical.Chinese.location/1
          )

      defoverridable solar_term: 2

      @doc """
      Returns the position of a year's leap month, or `nil` where the
      year has none.

      """
      unquote(impl)
      def leap_month(year), do: Calendrical.Month.leap_month(__MODULE__, year)

      @doc """
      Returns the figures a date is written with: its own fields, in a
      calendar whose dates are written as its own.

      """
      unquote(impl)
      def written_date(year, month, day), do: {year, month, day}

      @doc """
      Returns the date of this calendar that written figures name: the
      inverse of `written_date/3`, the fields themselves where they are a
      date.

      """
      unquote(impl)

      def date_from_written_date(year, month, day),
        do: Calendrical.Base.Written.own_date(__MODULE__, year, month, day)

      defoverridable leap_month: 1, written_date: 3, date_from_written_date: 3

      defoverridable cardinal_day: 3,
                     cardinal_year: 3,
                     cldr_calendar_type: 3,
                     date_from_cardinal_date: 3,
                     months_in_leap_year: 0,
                     parsing_calendars: 0,
                     date_from_day_of_year: 2,
                     named_month: 2,
                     numeric_month: 3,
                     lunar_month_of_year: 2,
                     ordinal_month_from_traditional: 2,
                     traditional_leap_month: 1,
                     traditional_months: 1
    end
  end
end
