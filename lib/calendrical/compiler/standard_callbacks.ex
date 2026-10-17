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

      """
      def cldr_calendar_type, do: info().cldr_calendar_type

      @doc """
      Returns the CLDR calendar type that names this calendar's eras, as
      its `info/0` states.

      """
      def era_calendar_type, do: info().era_calendar_type

      @doc """
      Returns the calendar a date written for this calendar is parsed in,
      as its `info/0` states.

      """
      def parsing_calendar, do: info().parsing_calendar

      @doc """
      Returns what this calendar's year is built of, `:month` or `:week`,
      as its `info/0` states.

      """
      def calendar_base, do: Calendrical.Info.calendar_base(__MODULE__)

      @doc """
      Returns the calendar module of this calendar's family whose CLDR
      calendar type is the one given (`Calendrical.calendar_from_cldr_calendar_type/1`).

      """
      defdelegate calendar_from_cldr_calendar_type(calendar_type), to: Calendrical

      @doc """
      Returns the number of months in an ordinary year: the fewest months
      a year of this calendar has.

      """
      def months_in_ordinary_year, do: elem(info().months_in_year, 0)

      @doc """
      Returns the CLDR calendar type whose data names a date's months and
      days: the member in effect on the date in a composite calendar, and
      this calendar's own otherwise (`Calendrical.Info.cldr_calendar_type/4`).

      """
      def cldr_calendar_type(year, month, day),
        do: Calendrical.Info.cldr_calendar_type(__MODULE__, year, month, day)

      @doc """
      Returns the calendars a date written for this calendar may be
      written in: the members of a composite calendar, and this calendar
      alone otherwise (`Calendrical.Info.parsing_calendars/1`).

      """
      def parsing_calendars, do: Calendrical.Info.parsing_calendars(__MODULE__)

      @doc """
      Returns the number of months in a leap year: the most months a year
      of this calendar has.

      """
      def months_in_leap_year, do: elem(info().months_in_year, 1)

      @doc """
      Returns the number of months in a year without a year: the count
      where every year has as many, `{:ambiguous, range}` where a leap
      year has more, and `{:error, :undefined}` for a composite calendar
      (`Calendrical.Info.months_in_year/1`).

      """
      def months_in_year, do: Calendrical.Info.months_in_year(__MODULE__)

      @doc """
      Returns the position of a year's leap month, or `nil` where the
      year has none.

      """
      unquote(impl)
      def leap_month(_year), do: nil

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

      @doc """
      Returns the CLDR month of a month of a year: the index of its name
      in this calendar's CLDR data, with `{month, :leap}` where the name
      has a leap form (`Calendrical.Month.cldr_month/3`).

      """
      def month_of_year(year, month, _day) when is_nil(year) or is_nil(month) do
        {:error,
         %Calendrical.MissingFieldsError{
           function: "month_of_year",
           fields: [year: year, month: month]
         }}
      end

      def month_of_year(year, month, day) do
        if Calendrical.Month.day_in_month?(__MODULE__, year, month, day),
          do: Calendrical.Month.cldr_month(__MODULE__, year, month),
          else: {:error, :invalid_date}
      end

      @doc """
      Returns the CLDR month of a month of a year
      (`Calendrical.Month.cldr_month/3`).

      """
      def cldr_month(year, month), do: Calendrical.Month.cldr_month(__MODULE__, year, month)

      @doc """
      Returns the CLDR month a month of the year names without a year
      (`Calendrical.Month.cldr_month/2`).

      """
      def cardinal_month(month), do: Calendrical.Month.cldr_month(__MODULE__, month)

      @doc """
      Returns the month a CLDR month is written with in a year
      (`Calendrical.Month.written_month_from_cldr_month/3`).

      """
      def written_month_from_cldr_month(year, cldr_month) do
        Calendrical.Month.written_month_from_cldr_month(__MODULE__, year, cldr_month)
      end

      @doc """
      Returns the number a date's month is written with in figures: the
      month of its `written_date/3`.

      """
      def numeric_month(year, month, day) do
        {_year, written_month, _day} = written_date(year, month, day)
        written_month
      end

      @doc """
      Returns the day a date is written with: the day of its
      `written_date/3`.

      """
      def cardinal_day(year, month, day) do
        {_year, _month, written_day} = written_date(year, month, day)
        written_day
      end

      @doc """
      Returns the year a date is written with: the year of its
      `written_date/3`.

      """
      def cardinal_year(year, month, day) do
        {written_year, _month, _day} = written_date(year, month, day)
        written_year
      end

      @doc """
      Returns the date of this calendar that written figures name
      (`date_from_written_date/3`), as fields.

      """
      def date_from_cardinal_date(year, month, day) do
        case date_from_written_date(year, month, day) do
          {:ok, date} -> date
          {:error, :invalid_date} = error -> error
        end
      end

      @doc """
      Returns the traditional month at a position in a year
      (`Calendrical.Month.traditional_month/3`), or an error for a place
      the year does not have.

      """
      def lunar_month_of_year(year, month) do
        case Calendrical.Month.traditional_month(__MODULE__, year, month) do
          {:error, _no_such_month} -> {:error, :invalid_month}
          traditional_month -> traditional_month
        end
      end

      @doc """
      Returns the position in a year of a traditional month
      (`Calendrical.Month.month_from_traditional/3`), as `{:ok, month}`.

      """
      def ordinal_month_from_traditional(year, traditional_month) do
        case Calendrical.Month.month_from_traditional(__MODULE__, year, traditional_month) do
          position when is_integer(position) ->
            {:ok, position}

          {:error, _no_such_month} when is_tuple(traditional_month) ->
            {:error, leap_month_error(traditional_month)}

          {:error, _no_such_month} ->
            {:error, :invalid_month}
        end
      end

      # A leap month a year does not have is `:invalid_leap_month`; a tuple
      # that is no leap month at all is `:invalid_month`.
      defp leap_month_error({month, :leap}) when is_integer(month) and month in 1..12,
        do: :invalid_leap_month

      defp leap_month_error(_other), do: :invalid_month

      @doc """
      Returns the traditional number of the month a year's leap month
      follows, or `nil` (`Calendrical.Month.traditional_leap_month/2`).

      """
      def traditional_leap_month(year),
        do: Calendrical.Month.traditional_leap_month(__MODULE__, year)

      @doc """
      Returns a year's months in order, named traditionally
      (`Calendrical.Month.traditional_months/2`).

      """
      def traditional_months(year), do: Calendrical.Month.traditional_months(__MODULE__, year)

      @doc """
      Returns a month of a year as this calendar names it
      (`Calendrical.Month.traditional_month/3`).

      """
      def traditional_month(year, month),
        do: Calendrical.Month.traditional_month(__MODULE__, year, month)

      @doc """
      Returns the position of a traditional month in a year
      (`Calendrical.Month.month_from_traditional/3`).

      """
      def month_from_traditional(year, traditional_month),
        do: Calendrical.Month.month_from_traditional(__MODULE__, year, traditional_month)

      @doc """
      Returns the date of a day of a year, counted from the year's first
      day.

      """
      def date_from_day_of_year(year, day_of_year),
        do: Calendrical.Base.Common.date_from_day_of_year(__MODULE__, year, day_of_year)

      @doc """
      Returns the days of a named month in a year
      (`Calendrical.Month.named_month/3`).

      """
      def named_month(year, named_month),
        do: Calendrical.Month.named_month(__MODULE__, year, named_month)

      @doc """
      Returns the fewest and the most months a year has
      (`Calendrical.Month.months_in_year_bounds/1`).

      """
      def months_in_year_bounds, do: Calendrical.Month.months_in_year_bounds(__MODULE__)

      @doc """
      Returns the fewest and the most days a month has in any year
      (`Calendrical.Month.days_in_month_bounds/2`).

      """
      def days_in_month_bounds(month),
        do: Calendrical.Month.days_in_month_bounds(__MODULE__, month)

      @doc """
      Returns the number of days in a month without a year
      (`Calendrical.Month.days_in_month/2`).

      """
      def days_in_month(nil) do
        {:error, %Calendrical.MissingFieldsError{function: "days_in_month", fields: [month: nil]}}
      end

      def days_in_month(month), do: Calendrical.Month.days_in_month(__MODULE__, month)

      @doc """
      Returns the months a year has, as runs of their numbers
      (`Calendrical.Month.month_numbers/2`).

      """
      def month_numbers(year), do: Calendrical.Month.month_numbers(__MODULE__, year)

      @doc """
      Returns the days a month of a year has, as runs of their numbers
      (`Calendrical.Month.day_numbers/3`).

      """
      def day_numbers(year, month), do: Calendrical.Month.day_numbers(__MODULE__, year, month)

      @doc """
      Returns the week-year and the week of the year a date is in
      (`Calendrical.Week.week_of_year/4`).

      """
      def week_of_year(year, month, day),
        do: Calendrical.Week.week_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the ISO 8601 week-year and week of the day a date names
      (`Calendrical.Week.iso_week_of_year/4`).

      """
      def iso_week_of_year(year, month, day),
        do: Calendrical.Week.iso_week_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the month and the week of the month a date is in
      (`Calendrical.Week.week_of_month/4`).

      """
      def week_of_month(year, month, day),
        do: Calendrical.Week.week_of_month(__MODULE__, year, month, day)

      @doc """
      Returns the number of weeks in a year (`Calendrical.Week.weeks_in_year/2`).

      """
      def weeks_in_year(year), do: Calendrical.Week.weeks_in_year(__MODULE__, year)

      @doc """
      Returns the seven days of a week of a year (`Calendrical.Week.week/3`).

      """
      def week(year, week), do: Calendrical.Week.week(__MODULE__, year, week)

      @doc """
      Returns the weeks of a month of a year in order
      (`Calendrical.Week.weeks_of_month/3`).

      """
      def weeks_of_month(year, month),
        do: Calendrical.Week.weeks_of_month(__MODULE__, year, month)

      @doc """
      Returns the date of a day of a week of a week-year
      (`Calendrical.Week.date_from_week_date/4`).

      """
      def date_from_week_date(week_year, week, day),
        do: Calendrical.Week.date_from_week_date(__MODULE__, week_year, week, day)

      @doc """
      Returns the week-year, the week and the day of the week of a date
      (`Calendrical.Week.week_date_from_date/4`).

      """
      def week_date_from_date(year, month, day),
        do: Calendrical.Week.week_date_from_date(__MODULE__, year, month, day)

      @doc """
      Returns the number of weeks in a week-year
      (`Calendrical.Week.weeks_in_week_year/2`).

      """
      def weeks_in_week_year(week_year),
        do: Calendrical.Week.weeks_in_week_year(__MODULE__, week_year)

      @doc """
      Returns the days of a year (`Calendrical.Period.year/2`).

      """
      def year(year), do: Calendrical.Period.year(__MODULE__, year)

      @doc """
      Returns the days of a quarter of a year (`Calendrical.Period.quarter/3`).

      """
      def quarter(year, quarter), do: Calendrical.Period.quarter(__MODULE__, year, quarter)

      @doc """
      Returns the days of a quadrimester of a year
      (`Calendrical.Period.quadrimester/3`).

      """
      def quadrimester(year, quadrimester),
        do: Calendrical.Period.quadrimester(__MODULE__, year, quadrimester)

      @doc """
      Returns the days of a semester of a year (`Calendrical.Period.semester/3`).

      """
      def semester(year, semester), do: Calendrical.Period.semester(__MODULE__, year, semester)

      @doc """
      Returns the days of a month of a year (`Calendrical.Period.month/3`).

      """
      def month(year, month), do: Calendrical.Period.month(__MODULE__, year, month)

      @doc """
      Returns the quarter of the year a date falls in
      (`Calendrical.Period.quarter_of_year/4`).

      """
      unquote(calendar_impl)

      def quarter_of_year(year, month, day),
        do: Calendrical.Period.quarter_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the day of the year of a date (`Calendrical.Period.day_of_year/4`).

      """
      unquote(calendar_impl)

      def day_of_year(year, month, day),
        do: Calendrical.Period.day_of_year(__MODULE__, year, month, day)

      @doc """
      Returns the number of days in a year (`Calendrical.Period.days_in_year/2`).

      """
      def days_in_year(year), do: Calendrical.Period.days_in_year(__MODULE__, year)

      @doc """
      Returns the number of periods in a year: its months.

      """
      def periods_in_year(year), do: months_in_year(year)

      @doc """
      Returns the number of days in a week.

      """
      def days_in_week, do: 7

      @doc """
      Returns the dates of this calendar, earliest first, whose month and
      day are those given and that fall in a Gregorian year.

      """
      def dates_in_gregorian_year(gregorian_year, month, day),
        do: Calendrical.generic_dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)

      @doc """
      Returns the day of the week of a date (`Calendrical.Week.day_of_week/5`).

      """
      unquote(calendar_impl)

      def day_of_week(year, month, day, starting_on),
        do: Calendrical.Week.day_of_week(__MODULE__, year, month, day, starting_on)

      @doc """
      Returns the year of era and era of a year (`Calendrical.Era.year_of_era/2`).

      """
      def year_of_era(year), do: Calendrical.Era.year_of_era(__MODULE__, year)

      @doc """
      Returns the year of era and era of a date (`Calendrical.Era.year_of_era/4`).

      """
      unquote(calendar_impl)

      def year_of_era(year, month, day),
        do: Calendrical.Era.year_of_era(__MODULE__, year, month, day)

      @doc """
      Returns the day of era and era of a date (`Calendrical.Era.day_of_era/4`).

      """
      unquote(calendar_impl)

      def day_of_era(year, month, day),
        do: Calendrical.Era.day_of_era(__MODULE__, year, month, day)

      @doc """
      Returns the extended year of a date (`Calendrical.Era.extended_year/4`).

      """
      def extended_year(year, month, day),
        do: Calendrical.Era.extended_year(__MODULE__, year, month, day)

      @doc """
      Returns the related Gregorian year of a date
      (`Calendrical.Era.related_gregorian_year/4`).

      """
      def related_gregorian_year(year, month, day),
        do: Calendrical.Era.related_gregorian_year(__MODULE__, year, month, day)

      @doc """
      Returns the cyclic year of a date (`Calendrical.Era.cyclic_year/4`).

      """
      def cyclic_year(year, month, day),
        do: Calendrical.Era.cyclic_year(__MODULE__, year, month, day)

      @doc """
      Returns the number of whole units between two dates, counted
      positionally.

      """
      unquote(impl)

      def diff(from, to, date_part),
        do: Calendrical.Base.Common.diff(__MODULE__, from, to, date_part)

      @doc """
      Converts a naive datetime of this calendar to ISO days and a day
      fraction, as `c:Calendar.naive_datetime_to_iso_days/7` asks.

      """
      unquote(calendar_impl)

      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        {date_to_iso_days(year, month, day),
         Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)}
      end

      @doc """
      Converts ISO days and a day fraction to a naive datetime of this
      calendar, as `c:Calendar.naive_datetime_from_iso_days/1` asks.

      """
      unquote(calendar_impl)

      def naive_datetime_from_iso_days({days, day_fraction}) do
        {year, month, day} = date_from_iso_days(days)
        {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc """
      Parses a date written in this calendar's own notation.

      """
      unquote(calendar_impl)
      def parse_date(string), do: Calendrical.Parse.parse_date(string, __MODULE__)

      @doc """
      Parses a UTC datetime written in this calendar's own notation.

      """
      unquote(calendar_impl)
      def parse_utc_datetime(string), do: Calendrical.Parse.parse_utc_datetime(string, __MODULE__)

      @doc """
      Parses a naive datetime written in this calendar's own notation.

      """
      unquote(calendar_impl)

      def parse_naive_datetime(string),
        do: Calendrical.Parse.parse_naive_datetime(string, __MODULE__)

      @doc """
      Shifts a date by a duration: its years and months together, as
      `shift/6` adds months, and then its weeks and days.

      """
      unquote(calendar_impl)

      def shift_date(year, month, day, duration),
        do: Calendrical.shift_date(year, month, day, __MODULE__, duration)

      @doc """
      Shifts a time by a duration, as `Calendar.ISO` does.

      """
      unquote(calendar_impl)

      def shift_time(hour, minute, second, microsecond, duration),
        do: Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)

      @doc """
      Shifts a naive datetime by a duration: its date as `shift_date/4`
      shifts it, and its time as `Calendar.ISO` does.

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
      Returns the number of years after which this calendar's years
      repeat, as its `info/0` states, or `{:error, :undefined}`.

      """
      def years_in_cycle, do: Calendrical.Info.years_in_cycle(__MODULE__)

      @doc """
      Returns the day of a solar term of a Gregorian year, reckoned at the
      place this calendar's `info/0` names, or at the Chinese calendar's
      meridian, the traditional reference, where it names none.

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
                     year_of_era: 1,
                     year_of_era: 3,
                     day_of_era: 3,
                     diff: 3
    end
  end
end
