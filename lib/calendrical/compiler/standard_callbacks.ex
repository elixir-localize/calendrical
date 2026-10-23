defmodule Calendrical.Compiler.StandardCallbacks do
  @moduledoc false

  # The functions every calendar module carries beside its kernel: one-line
  # delegations to the derived API, `Calendrical.Week`, `Calendrical.Month`
  # and the written date, each computed once for every calendar from the
  # kernel. Each maker of calendars (`use Calendrical.Calendar`, the
  # month, week and Julian compilers, the composite compiler) and
  # `Calendrical.Julian` `use` this module beside its `@behaviour
  # Calendrical`, so a calendar answers every question Localize asks of a
  # module and never implements the answer itself.
  #
  # A maker whose calendars mark none of their callbacks with `@impl` says
  # `impl: false`, since one mark in a module asks for a mark on every
  # callback it defines.
  #
  # Only the kernel trio with defaults here, `leap_month/1`, `written_date/3`
  # and `date_from_written_date/3`, may be overridden: every other
  # definition is derived and closed.

  defmacro __using__(options) do
    impl? = Keyword.get(options, :impl, true)
    impl = if impl?, do: quote(do: @impl(Calendrical))
    calendar_impl = if impl?, do: quote(do: @impl(Calendar))

    quote location: :keep do
      @doc """
      Returns the CLDR calendar type whose data names this calendar's
      months, days and quarters, as its `info/0` states.

      ### Returns

      * A CLDR calendar type such as `:gregorian` or `:hebrew`.

      ### Examples

          iex> #{inspect(__MODULE__)}.cldr_calendar_type() == #{inspect(__MODULE__)}.info().cldr_calendar_type
          true

      """
      def cldr_calendar_type, do: info().cldr_calendar_type

      @doc """
      Returns the CLDR calendar type that names this calendar's eras, as
      its `info/0` states.

      ### Returns

      * A CLDR calendar type such as `:gregorian` or `:japanese`.

      ### Examples

          iex> #{inspect(__MODULE__)}.era_calendar_type() == #{inspect(__MODULE__)}.info().era_calendar_type
          true

      """
      def era_calendar_type, do: info().era_calendar_type

      @doc """
      Returns the calendar a date written for this calendar is parsed in,
      as its `info/0` states.

      ### Returns

      * A calendar module.

      ### Examples

          iex> #{inspect(__MODULE__)}.parsing_calendar() == #{inspect(__MODULE__)}.info().parsing_calendar
          true

      """
      def parsing_calendar, do: info().parsing_calendar

      @doc """
      Returns what this calendar's year is built of, `:month` or `:week`,
      as its `info/0` states.

      ### Returns

      * `:week` for a calendar whose year is built of weeks.

      * `:month` otherwise.

      ### Examples

          iex> #{inspect(__MODULE__)}.calendar_base() in [:month, :week]
          true

      """
      def calendar_base, do: Calendrical.Info.calendar_base(__MODULE__)

      @doc """
      Returns the calendar module whose CLDR calendar type is the one
      given, whichever calendar is asked
      (`Calendrical.calendar_from_cldr_calendar_type/1`).

      ### Arguments

      * `calendar_type` is a CLDR calendar type as an atom or a string.

      ### Returns

      * `{:ok, calendar_module}`, or

      * `{:error, exception}` for a calendar type no calendar module has.

      ### Examples

          iex> #{inspect(__MODULE__)}.calendar_from_cldr_calendar_type(:gregorian)
          {:ok, Calendrical.Gregorian}

          iex> {:error, %Localize.UnknownCalendarError{}} =
          ...>   #{inspect(__MODULE__)}.calendar_from_cldr_calendar_type(:not_a_calendar)

      """
      defdelegate calendar_from_cldr_calendar_type(calendar_type), to: Calendrical

      @doc """
      Returns the number of months in an ordinary year: the fewest months
      a year of this calendar has.

      ### Returns

      * A positive integer.

      ### Examples

          iex> #{inspect(__MODULE__)}.months_in_ordinary_year() <= #{inspect(__MODULE__)}.months_in_leap_year()
          true

      """
      def months_in_ordinary_year, do: elem(info().months_in_year, 0)

      @doc """
      Returns the CLDR calendar type whose data names a date's months and
      days: the member in effect on the date in a composite calendar, and
      this calendar's own otherwise (`Calendrical.Info.cldr_calendar_type/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * A CLDR calendar type.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> in_effect = Calendrical.Info.in_effect(#{inspect(__MODULE__)}, date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.cldr_calendar_type(date.year, date.month, date.day) == in_effect.cldr_calendar_type()
          true

      """
      def cldr_calendar_type(year, month, day),
        do: Calendrical.Info.cldr_calendar_type(__MODULE__, year, month, day)

      @doc """
      Returns the calendars a date written for this calendar may be
      written in: the members of a composite calendar, and this calendar
      alone otherwise (`Calendrical.Info.parsing_calendars/1`).

      ### Returns

      * A non-empty list of calendar modules, the members of a composite
        calendar in the order they take effect.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> in_effect = Calendrical.Info.in_effect(#{inspect(__MODULE__)}, date.year, date.month, date.day)
          iex> in_effect in #{inspect(__MODULE__)}.parsing_calendars()
          true

      """
      def parsing_calendars, do: Calendrical.Info.parsing_calendars(__MODULE__)

      @doc """
      Returns the number of months in a leap year: the most months a year
      of this calendar has.

      ### Returns

      * A positive integer.

      ### Examples

          iex> #{inspect(__MODULE__)}.months_in_leap_year() >= #{inspect(__MODULE__)}.months_in_ordinary_year()
          true

      """
      def months_in_leap_year, do: elem(info().months_in_year, 1)

      @doc """
      Returns the number of months in a year without a year: the count
      where every year has as many, `{:ambiguous, range}` where a leap
      year has more, and `{:error, %Calendrical.NotDefinedError{}}` for a composite calendar
      (`Calendrical.Info.months_in_year/1`).

      ### Returns

      * The number of months where every year has as many, or

      * `{:ambiguous, fewest..most}` where a leap year has more, or

      * `{:error, %Calendrical.NotDefinedError{}}` for a composite calendar, whose bounds
        `months_in_year_bounds/0` gives.

      ### Examples

          iex> case #{inspect(__MODULE__)}.months_in_year() do
          ...>   months when is_integer(months) -> months == #{inspect(__MODULE__)}.months_in_leap_year()
          ...>   {:ambiguous, fewest..most//1} -> {fewest, most} == #{inspect(__MODULE__)}.info().months_in_year
          ...>   {:error, %Calendrical.NotDefinedError{}} -> is_list(#{inspect(__MODULE__)}.info().members)
          ...> end
          true

      """
      def months_in_year, do: Calendrical.Info.months_in_year(__MODULE__)

      @doc """
      Returns the position of a year's leap month, or `nil` where the
      year has none.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The leap month's position in the year, or

      * `nil` where the year has no leap month, as for anything but an
        integer year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> leap_month = #{inspect(__MODULE__)}.leap_month(date.year)
          iex> is_nil(leap_month) or leap_month in 1..#{inspect(__MODULE__)}.months_in_year(date.year)
          true

      """
      unquote(impl)
      def leap_month(_year), do: nil

      @doc """
      Returns the figures a date is written with: its own fields, in a
      calendar whose dates are written as its own.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{year, month, day}` as the date is written, where the month of a
        lunisolar calendar is its traditional number, `{month, :leap}`
        for a leap month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day) == {:ok, {date.year, date.month, date.day}}
          true

      """
      unquote(impl)
      def written_date(year, month, day), do: {year, month, day}

      @doc """
      Returns the date of this calendar that written figures name: the
      inverse of `written_date/3`, the fields themselves where they are a
      date.

      ### Arguments

      * `year`, `month` and `day` are the figures a date is written with,
        as `written_date/3` returns them.

      ### Returns

      * `{:ok, {year, month, day}}`, the date of this calendar, or

      * `{:error, :invalid_date}` where the figures name no date.

      The reason is an atom, not an exception: Localize's date parser reads
      it, as `c:Calendrical.date_from_written_date/3` sets out.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day) == {:ok, {date.year, date.month, date.day}}
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_from_written_date(date.year, 0, 1)
          {:error, :invalid_date}

      """
      unquote(impl)

      def date_from_written_date(year, month, day),
        do: Calendrical.Base.Written.own_date(__MODULE__, year, month, day)

      @doc """
      Returns the CLDR month of a month of a year: the index of its name
      in this calendar's CLDR data, with `{month, :leap}` where the name
      has a leap form (`Calendrical.Month.cldr_month/3`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar. The year
        and the day may be `nil`: a month's name needs only the month.

      ### Returns

      * A CLDR month number, or `{month, :leap}`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a day the month does not have, or

      * `{:error, exception}` for a month the year does not have, or a
        `Calendrical.MissingFieldsError` where the month is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.month_of_year(date.year, date.month, date.day) == #{inspect(__MODULE__)}.cldr_month(date.year, date.month)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.month_of_year(date.year, date.month, 0)

      """
      # A month's name needs only the month: the year refines it where it
      # varies (a leap month), and the day only checks that the date exists.
      def month_of_year(year, month, _day) when is_nil(month) do
        {:error,
         %Calendrical.MissingFieldsError{
           function: "month_of_year",
           fields: [year: year, month: month]
         }}
      end

      # With no year, the month must be one the calendar has, and the day,
      # where given, one such a month can have.
      def month_of_year(nil, month, day) do
        case days_in_month_bounds(month) do
          {_fewest, most} when is_integer(most) ->
            if is_nil(day) or (is_integer(day) and day in 1..most//1),
              do: Calendrical.Month.cldr_month(__MODULE__, month),
              else:
                {:error,
                 Calendrical.InvalidDateError.exception(
                   calendar: __MODULE__,
                   value: [month: month, day: day]
                 )}

          {:error, _no_such_month} = error ->
            error
        end
      end

      def month_of_year(year, month, nil),
        do: Calendrical.Month.cldr_month(__MODULE__, year, month)

      def month_of_year(year, month, day) do
        if Calendrical.Month.day_in_month?(__MODULE__, year, month, day),
          do: Calendrical.Month.cldr_month(__MODULE__, year, month),
          else:
            {:error,
             Calendrical.InvalidDateError.exception(
               calendar: __MODULE__,
               value: {year, month, day}
             )}
      end

      @doc """
      Returns the CLDR month of a month of a year
      (`Calendrical.Month.cldr_month/3`).

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * A CLDR month number, or `{month, :leap}` where the month's name
        has a leap form, or

      * `{:error, exception}` for a month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> cldr_month = #{inspect(__MODULE__)}.cldr_month(date.year, date.month)
          iex> #{inspect(__MODULE__)}.written_month_from_cldr_month(date.year, cldr_month) ==
          ...>   #{inspect(__MODULE__)}.numeric_month(date.year, date.month, date.day)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.cldr_month(date.year, 99)

      """
      def cldr_month(year, month), do: Calendrical.Month.cldr_month(__MODULE__, year, month)

      @doc """
      Returns the CLDR month a month of the year names without a year
      (`Calendrical.Month.cldr_month/2`).

      ### Arguments

      * `month` is a month of this calendar.

      ### Returns

      * The CLDR month the month is named in the year that holds
        1 January 2000, the month itself in the Hebrew calendar, whose
        names depend on the year, and the month itself where the
        reference year has no such month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2000-01-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.cardinal_month(1) == #{inspect(__MODULE__)}.cldr_month(date.year, 1)
          true

      """
      def cardinal_month(month), do: Calendrical.Month.cldr_month(__MODULE__, month)

      @doc """
      Returns the month a CLDR month is written with in a year
      (`Calendrical.Month.written_month_from_cldr_month/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `cldr_month` is a CLDR month number, or `{month, :leap}`.

      ### Returns

      * The month as `written_date/3` writes it, or

      * `{:error, :invalid_month}` where the year has no month of that
        name. The reason is an atom, not an exception: Localize's date parser
        reads it, where `Calendrical.Month.written_month_from_cldr_month/3`
        answers with an exception.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {_year, written_month, _day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> cldr_month = #{inspect(__MODULE__)}.cldr_month(date.year, date.month)
          iex> #{inspect(__MODULE__)}.written_month_from_cldr_month(date.year, cldr_month) == written_month
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.written_month_from_cldr_month(date.year, 99)
          {:error, :invalid_month}

      """
      def written_month_from_cldr_month(year, cldr_month) do
        case Calendrical.Month.written_month_from_cldr_month(__MODULE__, year, cldr_month) do
          # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
          # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
          {:error, _no_such_month} -> {:error, :invalid_month}
          written_month -> written_month
        end
      end

      @doc """
      Returns the number a date's month is written with in figures: the
      month of its `written_date/3`.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The month of the date's `written_date/3`: a month number, or
        `{month, :leap}` for a leap month of a lunisolar calendar.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {_year, written_month, _day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.numeric_month(date.year, date.month, date.day) == written_month
          true

      """
      def numeric_month(year, month, day) do
        {_year, written_month, _day} = written_date(year, month, day)
        written_month
      end

      @doc """
      Returns the day a date is written with: the day of its
      `written_date/3`.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The day of the date's `written_date/3`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {_year, _month, written_day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.cardinal_day(date.year, date.month, date.day) == written_day
          true

      """
      def cardinal_day(year, month, day) do
        {_year, _month, written_day} = written_date(year, month, day)
        written_day
      end

      @doc """
      Returns the year a date is written with: the year of its
      `written_date/3`.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The year of the date's `written_date/3`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {written_year, _month, _day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.cardinal_year(date.year, date.month, date.day) == written_year
          true

      """
      def cardinal_year(year, month, day) do
        {written_year, _month, _day} = written_date(year, month, day)
        written_year
      end

      @doc """
      Returns the date of this calendar that written figures name
      (`date_from_written_date/3`), as fields.

      ### Arguments

      * `year`, `month` and `day` are the figures a date is written with,
        as `written_date/3` returns them.

      ### Returns

      * `{year, month, day}`, the date of this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` where the figures name no date.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_cardinal_date(year, month, day) == {date.year, date.month, date.day}
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.date_from_cardinal_date(date.year, 0, 1)

      """
      def date_from_cardinal_date(year, month, day) do
        case date_from_written_date(year, month, day) do
          {:ok, date} ->
            date

          {:error, :invalid_date} ->
            {:error,
             Calendrical.InvalidDateError.exception(
               calendar: __MODULE__,
               value: {year, month, day}
             )}
        end
      end

      @doc """
      Returns the traditional month at a position in a year
      (`Calendrical.Month.traditional_month/3`), or an error for a place
      the year does not have.

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * The month's traditional number, or `{month, :leap}` for a leap
        month, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.lunar_month_of_year(date.year, date.month) ==
          ...>   #{inspect(__MODULE__)}.traditional_month(date.year, date.month)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.lunar_month_of_year(date.year, 99)

      """
      def lunar_month_of_year(year, month) do
        case Calendrical.Month.traditional_month(__MODULE__, year, month) do
          {:error, _no_such_month} = error -> error
          traditional_month -> traditional_month
        end
      end

      @doc """
      Returns the position in a year of a traditional month
      (`Calendrical.Month.month_from_traditional/3`), as `{:ok, month}`.

      ### Arguments

      * `year` is a year of this calendar.

      * `traditional_month` is a month's traditional number, or
        `{month, :leap}` for a leap month.

      ### Returns

      * `{:ok, month}`, the month's position in the year, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month or a leap
        month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> traditional_month = #{inspect(__MODULE__)}.traditional_month(date.year, date.month)
          iex> #{inspect(__MODULE__)}.ordinal_month_from_traditional(date.year, traditional_month) == {:ok, date.month}
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.ordinal_month_from_traditional(date.year, 99)

      """
      def ordinal_month_from_traditional(year, traditional_month) do
        case Calendrical.Month.month_from_traditional(__MODULE__, year, traditional_month) do
          position when is_integer(position) ->
            {:ok, position}

          {:error, _no_such_month} = error ->
            error
        end
      end

      @doc """
      Returns the traditional number of the month a year's leap month
      follows, or `nil` (`Calendrical.Month.traditional_leap_month/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The traditional number of the month the leap month follows, or

      * `nil` where the year has no leap month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> is_nil(#{inspect(__MODULE__)}.traditional_leap_month(date.year)) ==
          ...>   is_nil(#{inspect(__MODULE__)}.leap_month(date.year))
          true

      """
      def traditional_leap_month(year),
        do: Calendrical.Month.traditional_leap_month(__MODULE__, year)

      @doc """
      Returns a year's months in order, named traditionally
      (`Calendrical.Month.traditional_months/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * A list of traditional months, the nth naming the year's nth month,
        with `{month, :leap}` for a leap month, and `[]` for a year the
        calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> length(#{inspect(__MODULE__)}.traditional_months(date.year)) ==
          ...>   #{inspect(__MODULE__)}.months_in_year(date.year)
          true

      """
      def traditional_months(year), do: Calendrical.Month.traditional_months(__MODULE__, year)

      @doc """
      Returns a month of a year as this calendar names it
      (`Calendrical.Month.traditional_month/3`).

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * The month's traditional number, or `{month, :leap}` for a leap
        month, or

      * `{:error, exception}` for a month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.traditional_month(date.year, date.month) ==
          ...>   Enum.at(#{inspect(__MODULE__)}.traditional_months(date.year), date.month - 1)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.traditional_month(date.year, 99)

      """
      def traditional_month(year, month),
        do: Calendrical.Month.traditional_month(__MODULE__, year, month)

      @doc """
      Returns the position of a traditional month in a year
      (`Calendrical.Month.month_from_traditional/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `traditional_month` is a month's traditional number, or
        `{month, :leap}` for a leap month.

      ### Returns

      * The month's position in the year, or

      * `{:error, exception}` where the year has no such month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> traditional_month = #{inspect(__MODULE__)}.traditional_month(date.year, date.month)
          iex> #{inspect(__MODULE__)}.month_from_traditional(date.year, traditional_month) == date.month
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.month_from_traditional(date.year, 99)

      """
      def month_from_traditional(year, traditional_month),
        do: Calendrical.Month.month_from_traditional(__MODULE__, year, traditional_month)

      @doc """
      Returns the date of a day of a year, counted from the year's first
      day.

      ### Arguments

      * `year` is a year of this calendar.

      * `day_of_year` is the day of the year, counted from 1.

      ### Returns

      * A `t:Date.t/0` of this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a day the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> day_of_year = #{inspect(__MODULE__)}.day_of_year(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_day_of_year(date.year, day_of_year) == date
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.date_from_day_of_year(date.year, 1000)

      """
      def date_from_day_of_year(year, day_of_year),
        do: Calendrical.Base.Common.date_from_day_of_year(__MODULE__, year, day_of_year)

      @doc """
      Returns the days of a named month in a year
      (`Calendrical.Month.named_month/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `named_month` is the CLDR month that names the month.

      ### Returns

      * A list of `t:Date.Range.t/0`, one for each counted month that
        carries the name, earliest first, and `[]` where none does.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> cldr_month = #{inspect(__MODULE__)}.cldr_month(date.year, date.month)
          iex> #{inspect(__MODULE__)}.named_month(date.year, cldr_month) |> Enum.any?(&(date in &1))
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.named_month(date.year, 99)
          []

      """
      def named_month(year, named_month),
        do: Calendrical.Month.named_month(__MODULE__, year, named_month)

      @doc """
      Returns the fewest and the most months a year has
      (`Calendrical.Month.months_in_year_bounds/1`).

      ### Returns

      * `{fewest, most}`, which in a composite calendar counts the months
        left in a year a change of calendar falls in.

      ### Examples

          iex> {fewest, most} = #{inspect(__MODULE__)}.months_in_year_bounds()
          iex> fewest <= #{inspect(__MODULE__)}.months_in_ordinary_year() and
          ...>   most >= #{inspect(__MODULE__)}.months_in_leap_year()
          true

      """
      def months_in_year_bounds, do: Calendrical.Month.months_in_year_bounds(__MODULE__)

      @doc """
      Returns the fewest and the most days a month has in any year
      (`Calendrical.Month.days_in_month_bounds/2`).

      ### Arguments

      * `month` is a month of this calendar.

      ### Returns

      * `{fewest, most}`, or

      * `{:error, exception}` for a month the calendar has in no year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {fewest, most} = #{inspect(__MODULE__)}.days_in_month_bounds(date.month)
          iex> #{inspect(__MODULE__)}.days_in_month(date.year, date.month) in fewest..most
          true

          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.days_in_month_bounds(99)

      """
      def days_in_month_bounds(month),
        do: Calendrical.Month.days_in_month_bounds(__MODULE__, month)

      @doc """
      Returns the number of days in a month without a year
      (`Calendrical.Month.days_in_month/2`).

      ### Arguments

      * `month` is a month of this calendar.

      ### Returns

      * The number of days where the month has as many in every year, or

      * `{:ambiguous, lengths}` where its length depends on the year, the
        lengths a range or, where they are not consecutive, a list, or

      * `{:error, %Calendrical.NotDefinedError{}}` for a month the calendar has in no year, or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, where
        the month is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {fewest, most} = #{inspect(__MODULE__)}.days_in_month_bounds(date.month)
          iex> case #{inspect(__MODULE__)}.days_in_month(date.month) do
          ...>   days when is_integer(days) -> fewest == days and most == days
          ...>   {:ambiguous, lengths} -> Enum.min(lengths) == fewest and Enum.max(lengths) == most
          ...> end
          true

          iex> {:error, %Calendrical.NotDefinedError{}} = #{inspect(__MODULE__)}.days_in_month(99)

      """
      def days_in_month(nil) do
        {:error, %Calendrical.MissingFieldsError{function: "days_in_month", fields: [month: nil]}}
      end

      def days_in_month(month), do: Calendrical.Month.days_in_month(__MODULE__, month)

      @doc """
      Returns the months a year has, as runs of their numbers
      (`Calendrical.Month.month_numbers/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * A list of ranges: one from 1 in every year of every calendar but a
        composite, whose year a change of calendar falls in has the months
        that are left, and `[]` for a year the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.month_numbers(date.year) == [1..#{inspect(__MODULE__)}.months_in_year(date.year)//1]
          true

      """
      def month_numbers(year), do: Calendrical.Month.month_numbers(__MODULE__, year)

      @doc """
      Returns the days a month of a year has, as runs of their numbers
      (`Calendrical.Month.day_numbers/3`).

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * A list of ranges: one from 1 in every month of every calendar but
        a composite, whose month a change of calendar falls in has the
        days that are left, and `[]` for a month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.day_numbers(date.year, date.month) ==
          ...>   [1..#{inspect(__MODULE__)}.days_in_month(date.year, date.month)//1]
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.day_numbers(date.year, 99)
          []

      """
      def day_numbers(year, month), do: Calendrical.Month.day_numbers(__MODULE__, year, month)

      @doc """
      Returns the week-year and the week of the year a date is in
      (`Calendrical.Week.week_of_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{week_year, week}`, where the week-year is the year before or
        after where the date falls in that year's last or first week, or

      * `{:error, exception}` for a date the calendar does not have: a
        `Calendrical.MissingFieldsError` for a date missing a field, and a
        `Calendrical.InvalidDateError` otherwise.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week} = #{inspect(__MODULE__)}.week_of_year(date.year, date.month, date.day)
          iex> date in #{inspect(__MODULE__)}.week(week_year, week)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.week_of_year(date.year, date.month, 0)

      """
      def week_of_year(year, month, day),
        do: Calendrical.Week.week_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the ISO 8601 week-year and week of the day a date names
      (`Calendrical.Week.iso_week_of_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{week_year, week}` of ISO 8601, or

      * `{:error, exception}` for a date the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.iso_week_of_year(date.year, date.month, date.day)
          {2024, 22}

      """
      def iso_week_of_year(year, month, day),
        do: Calendrical.Week.iso_week_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the month and the week of the month a date is in
      (`Calendrical.Week.week_of_month/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{month, week}`, where the month is the one before or after where
        the date falls in that month's last or first week, or

      * `{:error, exception}` for a date the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {month, week} = #{inspect(__MODULE__)}.week_of_month(date.year, date.month, date.day)
          iex> month in (date.month - 1)..(date.month + 1) and week >= 1
          true

      """
      def week_of_month(year, month, day),
        do: Calendrical.Week.week_of_month(__MODULE__, year, month, day)

      @doc """
      Returns the number of weeks in a year (`Calendrical.Week.weeks_in_year/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The number of weeks, or

      * `{:error, exception}` for a year the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week} = #{inspect(__MODULE__)}.week_of_year(date.year, date.month, date.day)
          iex> week <= #{inspect(__MODULE__)}.weeks_in_year(week_year)
          true

      """
      def weeks_in_year(year), do: Calendrical.Week.weeks_in_year(__MODULE__, year)

      @doc """
      Returns the seven days of a week of a year (`Calendrical.Week.week/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `week` is a week of the year.

      ### Returns

      * A `t:Date.Range.t/0` of the week's seven days, which may begin in
        the year before or end in the year after, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a week the year does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        week is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week} = #{inspect(__MODULE__)}.week_of_year(date.year, date.month, date.day)
          iex> days = #{inspect(__MODULE__)}.week(week_year, week)
          iex> {Enum.count(days), date in days}
          {7, true}

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.week(date.year, 0)

      """
      def week(year, week), do: Calendrical.Week.week(__MODULE__, year, week)

      @doc """
      Returns the weeks of a month of a year in order
      (`Calendrical.Week.weeks_of_month/3`).

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * A list of `t:Date.Range.t/0`, one for each week `week_of_month/3`
        names for the month, the first of which may begin in the month
        before and the last run into the month after, or

      * `{:error, exception}` for a month the year does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.weeks_of_month(date.year, date.month) |> Enum.all?(&(Enum.count(&1) == 7))
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{}} = #{inspect(__MODULE__)}.weeks_of_month(date.year, 99)

      """
      def weeks_of_month(year, month),
        do: Calendrical.Week.weeks_of_month(__MODULE__, year, month)

      @doc """
      Returns the date of a day of a week of a week-year
      (`Calendrical.Week.date_from_week_date/4`).

      ### Arguments

      * `week_year` is a week-year of this calendar.

      * `week` is a week of the week-year.

      * `day` is the day of the week, numbered from 1 for the day the
        calendar's weeks begin on.

      ### Returns

      * A `t:Date.t/0` of this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` where the week has no such day.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week, day} = #{inspect(__MODULE__)}.week_date_from_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_week_date(week_year, week, day) == date
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.date_from_week_date(date.year, 1, 8)

      """
      def date_from_week_date(week_year, week, day),
        do: Calendrical.Week.date_from_week_date(__MODULE__, week_year, week, day)

      @doc """
      Returns the week-year, the week and the day of the week of a date
      (`Calendrical.Week.week_date_from_date/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{week_year, week, day_of_week}`, the day numbered from the day
        the calendar's weeks begin on, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week, day} = #{inspect(__MODULE__)}.week_date_from_date(date.year, date.month, date.day)
          iex> {week_year, week} == #{inspect(__MODULE__)}.week_of_year(date.year, date.month, date.day) and day in 1..7
          true

      """
      def week_date_from_date(year, month, day),
        do: Calendrical.Week.week_date_from_date(__MODULE__, year, month, day)

      @doc """
      Returns the number of weeks in a week-year
      (`Calendrical.Week.weeks_in_week_year/2`).

      ### Arguments

      * `week_year` is a week-year of this calendar.

      ### Returns

      * The number of weeks, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {week_year, week, _day} = #{inspect(__MODULE__)}.week_date_from_date(date.year, date.month, date.day)
          iex> week <= #{inspect(__MODULE__)}.weeks_in_week_year(week_year)
          true

      """
      def weeks_in_week_year(week_year),
        do: Calendrical.Week.weeks_in_week_year(__MODULE__, week_year)

      @doc """
      Returns the days of a year (`Calendrical.Period.year/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * A `t:Date.Range.t/0`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for
        no year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> date in #{inspect(__MODULE__)}.year(date.year)
          true

          iex> {:error, %Calendrical.MissingFieldsError{}} = #{inspect(__MODULE__)}.year(nil)

      """
      def year(year), do: Calendrical.Period.year(__MODULE__, year)

      @doc """
      Returns the days of a quarter of a year (`Calendrical.Period.quarter/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `quarter` is the quarter, `1` to `4`.

      ### Returns

      * A `t:Date.Range.t/0`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a quarter or a year the calendar
        does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        quarter is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> quarter = #{inspect(__MODULE__)}.quarter_of_year(date.year, date.month, date.day)
          iex> date in #{inspect(__MODULE__)}.quarter(date.year, quarter)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.quarter(date.year, 5)

      """
      def quarter(year, quarter), do: Calendrical.Period.quarter(__MODULE__, year, quarter)

      @doc """
      Returns the days of a quadrimester of a year
      (`Calendrical.Period.quadrimester/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `quadrimester` is the quadrimester, `1` to `3`.

      ### Returns

      * A `t:Date.Range.t/0`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a quadrimester or a year the
        calendar does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        quadrimester is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.quadrimester(date.year, 1).first == #{inspect(__MODULE__)}.year(date.year).first
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.quadrimester(date.year, 4)

      """
      def quadrimester(year, quadrimester),
        do: Calendrical.Period.quadrimester(__MODULE__, year, quadrimester)

      @doc """
      Returns the days of a semester of a year (`Calendrical.Period.semester/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `semester` is the semester, `1` or `2`.

      ### Returns

      * A `t:Date.Range.t/0`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a semester or a year the calendar
        does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        semester is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.semester(date.year, 1).first == #{inspect(__MODULE__)}.year(date.year).first
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.semester(date.year, 3)

      """
      def semester(year, semester), do: Calendrical.Period.semester(__MODULE__, year, semester)

      @doc """
      Returns the days of a month of a year (`Calendrical.Period.month/3`).

      ### Arguments

      * `year` and `month` are a month of this calendar.

      ### Returns

      * A `t:Date.Range.t/0`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a month the year does not have, or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for a
        missing year or month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> date in #{inspect(__MODULE__)}.month(date.year, date.month)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.month(date.year, 99)

      """
      def month(year, month), do: Calendrical.Period.month(__MODULE__, year, month)

      @doc """
      Returns the quarter of the year a date falls in
      (`Calendrical.Period.quarter_of_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The quarter, `1` to `4`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for a
        missing year or month.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.quarter_of_year(date.year, date.month, date.day) in 1..4
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.quarter_of_year(date.year, date.month, 0)

      """
      unquote(calendar_impl)

      def quarter_of_year(year, month, day),
        do: Calendrical.Period.quarter_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the day of the year of a date (`Calendrical.Period.day_of_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The day of the year, counted from 1 for its first day, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for a
        missing field.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> first_day = #{inspect(__MODULE__)}.year(date.year).first
          iex> #{inspect(__MODULE__)}.day_of_year(date.year, date.month, date.day) == Date.diff(date, first_day) + 1
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.day_of_year(date.year, date.month, 0)

      """
      unquote(calendar_impl)

      def day_of_year(year, month, day),
        do: Calendrical.Period.day_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the number of days in a year (`Calendrical.Period.days_in_year/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The number of days, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.days_in_year(date.year) == Enum.count(#{inspect(__MODULE__)}.year(date.year))
          true

          iex> {:error, %Calendrical.MissingFieldsError{}} = #{inspect(__MODULE__)}.days_in_year(nil)

      """
      def days_in_year(year), do: Calendrical.Period.days_in_year(__MODULE__, year)

      @doc """
      Returns the number of periods in a year: its months.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The number of months in the year, as `months_in_year/1` returns
        it.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.periods_in_year(date.year) == #{inspect(__MODULE__)}.months_in_year(date.year)
          true

      """
      def periods_in_year(year), do: months_in_year(year)

      @doc """
      Returns the number of days in a week.

      ### Returns

      * `7`.

      ### Examples

          iex> #{inspect(__MODULE__)}.days_in_week()
          7

      """
      def days_in_week, do: 7

      @doc """
      Returns the dates of this calendar, earliest first, whose month and
      day are those given and that fall in a Gregorian year.

      ### Arguments

      * `gregorian_year` is the Gregorian year to search within.

      * `month` and `day` are a month and a day of this calendar.

      ### Returns

      * A list of zero, one or two `t:Date.t/0` of this calendar, earliest
        first, since this calendar's years and the Gregorian years drift.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> date in #{inspect(__MODULE__)}.dates_in_gregorian_year(2024, date.month, date.day)
          true

      """
      def dates_in_gregorian_year(gregorian_year, month, day),
        do: Calendrical.generic_dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)

      @doc """
      Returns the day of the week of a date (`Calendrical.Week.day_of_week/5`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `starting_on` is `:default` for the day this calendar's weeks
        begin on, or the name of a weekday, `:monday` to `:sunday`.

      ### Returns

      * `{day_of_week, 1, 7}`, the day numbered from the day the week
        begins on, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for a
        missing field.

      ### Examples

          # 1 June 2024 is a Saturday
          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.day_of_week(date.year, date.month, date.day, :monday)
          {6, 1, 7}

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.day_of_week(date.year, date.month, 0, :monday)

      """
      unquote(calendar_impl)

      def day_of_week(year, month, day, starting_on),
        do: Calendrical.Week.day_of_week(__MODULE__, year, month, day, starting_on)

      @doc """
      Returns the year of era and era of a year (`Calendrical.Era.year_of_era/2`).

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * `{year_of_era, era}`, the era in effect on the year's first day,
        or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.year_of_era(date.year) ==
          ...>   #{inspect(__MODULE__)}.year_of_era(date.year, date.month, date.day)
          true

      """
      def year_of_era(year), do: Calendrical.Era.year_of_era(__MODULE__, year)

      @doc """
      Returns the year of era and era of a date (`Calendrical.Era.year_of_era/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{year_of_era, era}`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year_of_era, era} = #{inspect(__MODULE__)}.year_of_era(date.year, date.month, date.day)
          iex> year_of_era >= 1 and is_integer(era)
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.year_of_era(date.year, 99, 1)

      """
      unquote(calendar_impl)

      def year_of_era(year, month, day),
        do: Calendrical.Era.default_year_of_era(__MODULE__, year, month, day)

      @doc """
      Returns the day of era and era of a date (`Calendrical.Era.day_of_era/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{day_of_era, era}`, where the day of the era counts from the
        era's first day, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for a
        missing field.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {day_of_era, era} = #{inspect(__MODULE__)}.day_of_era(date.year, date.month, date.day)
          iex> {_year_of_era, year_era} = #{inspect(__MODULE__)}.year_of_era(date.year, date.month, date.day)
          iex> day_of_era >= 1 and era == year_era
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.day_of_era(date.year, date.month, 0)

      """
      unquote(calendar_impl)

      def day_of_era(year, month, day),
        do: Calendrical.Era.default_day_of_era(__MODULE__, year, month, day)

      @doc """
      Returns the extended year of a date (`Calendrical.Era.extended_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The year numbered without a gap at 0, so that in a calendar with
        no year 0 the year before 1 is 0, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have, or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.extended_year(date.year, date.month, date.day) == date.year
          true

          iex> {:error, %Calendrical.MissingFieldsError{}} = #{inspect(__MODULE__)}.extended_year(nil, 1, 1)

      """
      def extended_year(year, month, day),
        do: Calendrical.Era.extended_year(__MODULE__, year, month, day)

      @doc """
      Returns the related Gregorian year of a date
      (`Calendrical.Era.related_gregorian_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The Gregorian year the date's calendar year begins in, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:ok, first_day} = Date.convert(#{inspect(__MODULE__)}.year(date.year).first, Calendrical.Gregorian)
          iex> #{inspect(__MODULE__)}.related_gregorian_year(date.year, date.month, date.day) == first_day.year
          true

      """
      def related_gregorian_year(year, month, day),
        do: Calendrical.Era.related_gregorian_year(__MODULE__, year, month, day)

      @doc """
      Returns the cyclic year of a date (`Calendrical.Era.cyclic_year/4`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The date's place in the sexagenary cycle, `1` to `60`, in an East
        Asian calendar, and its year in a calendar whose years run in no
        such cycle, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have,
        or

      * `{:error, exception}`, a `Calendrical.MissingFieldsError`, for no
        year.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> cyclic_year = #{inspect(__MODULE__)}.cyclic_year(date.year, date.month, date.day)
          iex> cyclic_year in 1..60 or cyclic_year == date.year
          true

          iex> {:error, %Calendrical.MissingFieldsError{}} = #{inspect(__MODULE__)}.cyclic_year(nil, 1, 1)

      """
      def cyclic_year(year, month, day),
        do: Calendrical.Era.cyclic_year(__MODULE__, year, month, day)

      @doc """
      Returns the number of whole units between two dates, counted
      positionally.

      ### Arguments

      * `from` and `to` are dates of this calendar as `{year, month, day}`
        tuples.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      ### Returns

      * The largest number of `date_part`s that can be added to `from`
        without passing `to`, negative where `to` is before `from`, or

      * `{:error, %Calendrical.InvalidDateError{}}` for a `from` or `to`
        the calendar does not have, `{:error, %Calendrical.MissingFieldsError{}}`
        for one missing a field, or `{:error, %Calendrical.InvalidPartError{}}`
        for a `date_part` other than the five.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> from = {date.year, date.month, date.day}
          iex> #{inspect(__MODULE__)}.diff(from, {date.year + 1, date.month, date.day}, :years)
          1

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> later = Date.add(date, 10)
          iex> #{inspect(__MODULE__)}.diff({later.year, later.month, later.day}, {date.year, date.month, date.day}, :days)
          -10

      """
      unquote(impl)

      def diff(from, to, date_part),
        do: Calendrical.Base.Common.diff(__MODULE__, from, to, date_part)

      @doc """
      Converts a naive datetime of this calendar to ISO days and a day
      fraction, as `c:Calendar.naive_datetime_to_iso_days/7` asks.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `hour`, `minute`, `second` and `microsecond` are a time of day,
        the microsecond as `{microseconds, precision}`.

      ### Returns

      * `{iso_days, {parts_in_day, parts_per_day}}`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.naive_datetime_to_iso_days(date.year, date.month, date.day, 12, 0, 0, {0, 6})
          {739403, {43200000000, 86400000000}}

      """
      unquote(calendar_impl)

      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        {date_to_iso_days(year, month, day),
         Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)}
      end

      @doc """
      Converts ISO days and a day fraction to a naive datetime of this
      calendar, as `c:Calendar.naive_datetime_from_iso_days/1` asks.

      ### Arguments

      * `iso_days` is `{days, {parts_in_day, parts_per_day}}`, a day and a
        fraction of it.

      ### Returns

      * `{year, month, day, hour, minute, second, microsecond}` of this
        calendar.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day, 12, 0, 0, {0, 6}} =
          ...>   #{inspect(__MODULE__)}.naive_datetime_from_iso_days({739403, {43200000000, 86400000000}})
          iex> {year, month, day} == {date.year, date.month, date.day}
          true

      """
      unquote(calendar_impl)

      def naive_datetime_from_iso_days({days, day_fraction}) do
        {year, month, day} = date_from_iso_days(days)
        {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc """
      Parses a date written in this calendar's own notation.

      ### Arguments

      * `string` is a date written `YYYY-MM-DD`, with a leading `-` for a
        year before 1, or, in a calendar of weeks, `YYYY-Www-D`.

      ### Returns

      * `{:ok, {year, month, day}}`, or

      * `{:error, :invalid_format}` where the text is not in that form or
        its fields are not digits, or

      * `{:error, :invalid_date}` where the text names no date of this
        calendar.

      The reason is an atom, not an exception, because `c:Calendar.parse_date/1`
      requires one: `Date.from_iso8601/2` reads it.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.parse_date(Date.to_string(date)) == {:ok, {date.year, date.month, date.day}}
          true

          iex> #{inspect(__MODULE__)}.parse_date("not a date")
          {:error, :invalid_format}

      """
      unquote(calendar_impl)
      def parse_date(string), do: Calendrical.Parse.parse_date(string, __MODULE__)

      @doc """
      Parses a UTC datetime written in this calendar's own notation.

      ### Arguments

      * `string` is a date as `parse_date/1` reads it, then `T` or a
        space, a time of day and an offset from UTC, `Z` or `±HH:MM`.

      ### Returns

      * `{:ok, {year, month, day, hour, minute, second, microsecond}, offset}`,
        the datetime in UTC and the offset in seconds it was written with,
        or

      * `{:error, reason}`, such as `:invalid_format`, `:invalid_date` or
        `:missing_offset`, where the text is no such datetime.

      The reason is an atom, not an exception, because
      `c:Calendar.parse_utc_datetime/1` requires one:
      `DateTime.from_iso8601/2` reads it.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.parse_utc_datetime(Date.to_string(date) <> "T12:00:00Z") ==
          ...>   {:ok, {date.year, date.month, date.day, 12, 0, 0, {0, 0}}, 0}
          true

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.parse_utc_datetime(Date.to_string(date) <> "T12:00:00")
          {:error, :missing_offset}

      """
      unquote(calendar_impl)
      def parse_utc_datetime(string), do: Calendrical.Parse.parse_utc_datetime(string, __MODULE__)

      @doc """
      Parses a naive datetime written in this calendar's own notation.

      ### Arguments

      * `string` is a date as `parse_date/1` reads it, then `T` or a
        space and a time of day.

      ### Returns

      * `{:ok, {year, month, day, hour, minute, second, microsecond}}`, or

      * `{:error, reason}`, such as `:invalid_format` or `:invalid_date`,
        where the text is no such datetime.

      The reason is an atom, not an exception, because
      `c:Calendar.parse_naive_datetime/1` requires one:
      `NaiveDateTime.from_iso8601/2` reads it.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.parse_naive_datetime(Date.to_string(date) <> "T12:00:00") ==
          ...>   {:ok, {date.year, date.month, date.day, 12, 0, 0, {0, 0}}}
          true

          iex> #{inspect(__MODULE__)}.parse_naive_datetime("2024-06-01")
          {:error, :invalid_format}

      """
      unquote(calendar_impl)

      def parse_naive_datetime(string),
        do: Calendrical.Parse.parse_naive_datetime(string, __MODULE__)

      @doc """
      Shifts a date by a duration: its years and months together, as
      `shift/6` adds months, and then its weeks and days.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `duration` is a `t:Duration.t/0`.

      ### Returns

      * `{year, month, day}` of this calendar.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.shift_date(date.year, date.month, date.day, Duration.new!(day: 7))
          iex> Date.new!(year, month, day, #{inspect(__MODULE__)}) == Date.add(date, 7)
          true

      """
      unquote(calendar_impl)

      def shift_date(year, month, day, duration),
        do: Calendrical.shift_date(year, month, day, __MODULE__, duration)

      @doc """
      Shifts a time by a duration, as `Calendar.ISO` does.

      ### Arguments

      * `hour`, `minute`, `second` and `microsecond` are a time of day,
        the microsecond as `{microseconds, precision}`.

      * `duration` is a `t:Duration.t/0` of time units.

      ### Returns

      * `{hour, minute, second, microsecond}`, wrapped around midnight.

      ### Examples

          iex> #{inspect(__MODULE__)}.shift_time(23, 0, 0, {0, 0}, Duration.new!(hour: 2))
          {1, 0, 0, {0, 0}}

      """
      unquote(calendar_impl)

      def shift_time(hour, minute, second, microsecond, duration),
        do: Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)

      @doc """
      Shifts a naive datetime by a duration: its date as `shift_date/4`
      shifts it, and its time as `Calendar.ISO` does.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `hour`, `minute`, `second` and `microsecond` are a time of day,
        the microsecond as `{microseconds, precision}`.

      * `duration` is a `t:Duration.t/0`.

      ### Returns

      * `{year, month, day, hour, minute, second, microsecond}` of this
        calendar.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> next_day = Date.add(date, 1)
          iex> #{inspect(__MODULE__)}.shift_naive_datetime(date.year, date.month, date.day, 23, 0, 0, {0, 0}, Duration.new!(hour: 2)) ==
          ...>   {next_day.year, next_day.month, next_day.day, 1, 0, 0, {0, 0}}
          true

      """
      unquote(calendar_impl)

      def shift_naive_datetime(year, month, day, hour, minute, second, microsecond, duration) do
        Calendrical.shift_naive_datetime(
          year,
          month,
          day,
          hour,
          minute,
          second,
          microsecond,
          __MODULE__,
          duration
        )
      end

      @doc false
      unquote(calendar_impl)
      defdelegate date_to_string(year, month, day), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)

      defdelegate datetime_to_string(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                    microsecond,
                    time_zone,
                    zone_abbr,
                    utc_offset,
                    std_offset
                  ),
                  to: Calendar.ISO

      @doc false
      unquote(calendar_impl)

      defdelegate naive_datetime_to_string(year, month, day, hour, minute, second, microsecond),
        to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate parse_time(string), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

      @doc false
      unquote(calendar_impl)
      defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO

      @doc """
      Adds whole years, quarters or months to the fields of a naive
      datetime, keeping its time of day: the `add/9` callback
      [`CalendarInterval`](https://hexdocs.pm/calendar_interval) steps an
      interval of a year or a month with. The date moves as `shift/6`
      moves it, clamping the day into a shorter month.

      ### Arguments

      * `year`, `month` and `day` are the date's fields in this calendar.

      * `hour`, `minute`, `second` and `microsecond` are the time of day,
        returned unchanged.

      * `precision` is `:year`, `:quarter` or `:month`.

      * `step` is the number of years, quarters or months to add, which
        may be negative.

      ### Returns

      * `{year, month, day, hour, minute, second, microsecond}`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day, 12, 30, 0, {0, 0}} =
          ...>   #{inspect(__MODULE__)}.add(date.year, date.month, date.day, 12, 30, 0, {0, 0}, :month, 1)
          iex> {year, month, day} == #{inspect(__MODULE__)}.shift(date.year, date.month, date.day, :months, 1, [])
          true

      """
      def add(year, month, day, hour, minute, second, microsecond, :year, step),
        do:
          add_time(
            shift(year, month, day, :years, step, clamp: true),
            hour,
            minute,
            second,
            microsecond
          )

      def add(year, month, day, hour, minute, second, microsecond, :quarter, step),
        do:
          add_time(
            shift(year, month, day, :quarters, step, clamp: true),
            hour,
            minute,
            second,
            microsecond
          )

      def add(year, month, day, hour, minute, second, microsecond, :month, step),
        do:
          add_time(
            shift(year, month, day, :months, step, clamp: true),
            hour,
            minute,
            second,
            microsecond
          )

      defp add_time({year, month, day}, hour, minute, second, microsecond),
        do: {year, month, day, hour, minute, second, microsecond}

      @doc """
      Returns the number of years after which this calendar's years
      repeat, as its `info/0` states, or `{:error, %Calendrical.NotDefinedError{}}`.

      ### Returns

      * The number of years in the cycle, or

      * `{:error, %Calendrical.NotDefinedError{}}` where the calendar states none.

      ### Examples

          # A year has as many days as the year one cycle later
          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> case #{inspect(__MODULE__)}.years_in_cycle() do
          ...>   {:error, %Calendrical.NotDefinedError{}} -> true
          ...>   years -> #{inspect(__MODULE__)}.days_in_year(date.year) == #{inspect(__MODULE__)}.days_in_year(date.year + years)
          ...> end
          true

      """
      def years_in_cycle, do: Calendrical.Info.years_in_cycle(__MODULE__)

      @doc """
      Returns the day of a solar term of a Gregorian year, reckoned at the
      place this calendar's `info/0` names, or at the Chinese calendar's
      meridian, the traditional reference, where it names none.

      ### Arguments

      * `index` is the solar term's number, `1` (lichun, 315° of solar
        longitude) to `24`, every 15° on.

      * `gregorian_year` is a Gregorian year.

      ### Returns

      * `{:ok, date}`, a `t:Date.t/0` in `Calendrical.Gregorian`, or

      * `{:error, %Calendrical.InvalidSolarTermError{}}` where `index` is not
        `1` to `24`.

      ### Examples

          # Qingming, the fifth solar term
          iex> #{inspect(__MODULE__)}.solar_term(5, 2025)
          {:ok, ~D[2025-04-04 Calendrical.Gregorian]}

          iex> #{inspect(__MODULE__)}.solar_term(25, 2025)
          {:error, %Calendrical.InvalidSolarTermError{index: 25}}

      """
      def solar_term(index, gregorian_year),
        do:
          Calendrical.Lunisolar.solar_term(
            index,
            gregorian_year,
            Calendrical.Info.location(__MODULE__)
          )

      defoverridable leap_month: 1,
                     written_date: 3,
                     date_from_written_date: 3,
                     year_of_era: 3,
                     day_of_era: 3,
                     diff: 3
    end
  end
end
