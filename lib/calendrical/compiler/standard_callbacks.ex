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

      defoverridable cardinal_day: 3,
                     numeric_month: 3,
                     lunar_month_of_year: 2,
                     ordinal_month_from_traditional: 2,
                     leap_month: 1,
                     traditional_leap_month: 1,
                     traditional_months: 1
    end
  end
end
