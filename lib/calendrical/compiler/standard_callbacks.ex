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
      Returns the ordinal month that is the leap month of a year: `nil`,
      in a calendar that has no leap month.

      """
      unquote(impl)
      def leap_month(_year), do: nil

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
      Returns the number of weeks in a month: the weeks `week_of_month/3`
      names for it.

      """
      unquote(impl)

      def weeks_in_month(year, month),
        do: Calendrical.Base.MonthWeeks.weeks_in_month(__MODULE__, year, month)

      @doc """
      Returns a `t:Date.Range.t/0` representing a given week of a month
      of a year: the days `week_of_month/3` names for it.

      """
      unquote(impl)

      def month_week(year, month, week),
        do: Calendrical.Base.MonthWeeks.month_week(__MODULE__, year, month, week)

      defoverridable weeks_in_month: 2, month_week: 3

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

      defoverridable cardinal_day: 3,
                     date_from_day_of_year: 2,
                     named_month: 2,
                     numeric_month: 3,
                     lunar_month_of_year: 2,
                     ordinal_month_from_traditional: 2,
                     leap_month: 1,
                     traditional_leap_month: 1,
                     traditional_months: 1
    end
  end
end
