defmodule Calendrical.Composite.Compiler do
  @moduledoc false

  defmacro __before_compile__(env) do
    config =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Calendrical.Composite.Config.extract_options()
      |> Macro.escape()

    Module.put_attribute(env.module, :calendar_config, config)

    quote location: :keep, bind_quoted: [config: config, reverse: Enum.reverse(config)] do
      @behaviour Calendar
      @behaviour Calendrical

      @type year :: -9999..9999
      @type month :: 1..12
      @type day :: 1..31

      @quarters_in_year 4

      import Localize.Macros
      import Calendrical.Composite.Config, only: [define_transition_functions: 2]

      @doc false
      def __config__, do: @calendar_config

      @doc """
      Identifies that the calendar is month based.

      This may not always be true for all dates in a composite
      calendar but only a single value per calendar is supported.

      """
      @impl true
      def calendar_base, do: :month

      @doc """
      Defines the CLDR calendar type for this calendar.

      This type is used in support of `Calendrical.localize/3`.

      """
      @impl true
      def cldr_calendar_type, do: :gregorian

      @doc """
      Identify the base calendar for a given date.

      This function derives the calendar we delegate to for a given
      date based upon the configuration.

      """
      for {_iso_days, y, m, d, calendar} <- reverse do
        def calendar_for_date(year, month, day)
            when year > unquote(y) or
                   (year >= unquote(y) and month > unquote(m)) or
                   (year >= unquote(y) and month >= unquote(m) and day >= unquote(d)) do
          unquote(calendar)
        end
      end

      def calendar_for_date(%{year: year, month: month, day: day, calendar: __MODULE__}) do
        calendar_for_date(year, month, day)
      end

      def calendar_for_date(%{year: _, month: _, day: _, calendar: _} = date) do
        date
        |> Date.convert!(__MODULE__)
        |> calendar_for_date()
      end

      @doc """
      Identify the base calendar for a given iso_days.

      """
      for {iso_days, _y, _m, _d, calendar} <- reverse do
        def calendar_for_iso_days(iso_days) when iso_days >= unquote(iso_days) do
          unquote(calendar)
        end
      end

      @doc """
      Determines if the date given is valid according to this calendar.

      """
      @impl true
      def valid_date?(year, month, day) do
        calendar = calendar_for_date(year, month, day)

        if calendar.valid_date?(year, month, day) do
          iso_days = date_to_iso_days(year, month, day)
          calendar_for_iso_days(iso_days) == calendar
        else
          false
        end
      end

      @doc """
      Calculates the year and era from the given `year`, `month`,
      and `day`. The result is in the context of the calendar in
      effect on that date.

      """
      @spec year_of_era(year, month, day) :: {year, era :: non_neg_integer}
      @impl true
      def year_of_era(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.year_of_era(year, month, day)
      end

      @doc """
      Returns the calendar year as displayed on rendered calendars.

      """
      @spec calendar_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def calendar_year(year, _month, _day), do: year

      @doc """
      Returns the related Gregorian year.

      """
      @spec related_gregorian_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.year()
      @impl true
      def related_gregorian_year(year, _month, _day), do: year

      @doc """
      Returns the extended year.

      """
      @spec extended_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def extended_year(year, _month, _day), do: year

      @doc """
      Returns the cyclic year.

      """
      @spec cyclic_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def cyclic_year(year, _month, _day), do: year

      @doc """
      Calculates the quarter of the year (1..4) for the given date.

      """
      @impl true
      def quarter_of_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.quarter_of_year(year, month, day)
      end

      @doc """
      Calculates the month of the year for the given date.

      """
      @impl true
      def month_of_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.month_of_year(year, month, day)
      end

      @doc """
      Calculates the week of the year for the given date.

      """
      @impl true
      def week_of_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.week_of_year(year, month, day)
      end

      @doc """
      Calculates the ISO week of the year for the given date.

      """
      @impl true
      def iso_week_of_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.iso_week_of_year(year, month, day)
      end

      @doc """
      Composite calendars do not define week-of-month.

      """
      @impl true
      def week_of_month(_year, _week, _day), do: {:error, :not_defined}

      @doc """
      Calculates the day and era for the given date.

      """
      @impl true
      def day_of_era(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.day_of_era(year, month, day)
      end

      @doc """
      Calculates the day of the year for the given date.

      """
      @impl true
      def day_of_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.day_of_year(year, month, day)
      end

      @doc """
      Calculates the day of the week for the given date.

      """
      @impl true
      def day_of_week(year, month, day, :default) do
        calendar = calendar_for_date(year, month, day)
        calendar.day_of_week(year, month, day, :default)
      end

      @doc """
      Returns the number of periods in the given year.

      """
      @impl true
      def periods_in_year(year), do: months_in_year(year)

      @doc """
      Returns the number of days in the given year.

      """
      @impl true
      def days_in_year(year) do
        starts = date_to_iso_days(year, 1, 1)
        ends = date_to_iso_days(year + 1, 1, 1)
        ends - starts
      end

      @doc """
      Returns the number of weeks in the given year (in the context
      of the calendar that starts the year).

      """
      @impl true
      def weeks_in_year(year) do
        calendar = calendar_for_date(year, 1, 1)
        calendar.weeks_in_year(year)
      end

      @doc """
      Returns the number of days in the given year/month.

      """
      @impl true
      define_transition_functions(config, fn
        # Transitions from one calendar to another
        {_, old_year, old_month, _, old_calendar}, [{_, new_year, new_month, _, new_calendar} | _] ->
          def days_in_month(year, month)
              when year == unquote(new_year) and month == unquote(new_month) do
            starts = date_to_iso_days(year, month, 1)

            ends =
              date_to_iso_days(year, month, unquote(new_calendar).days_in_month(year, month))

            ends - starts + 1
          end

          # Months and years earlier than the transition
          def days_in_month(year, month)
              when year == unquote(old_year) and month >= unquote(old_month) do
            unquote(old_calendar).days_in_month(year, month)
          end

        # All other months after the final transition
        {_, _, _, _, calendar}, [] ->
          def days_in_month(year, month) do
            unquote(calendar).days_in_month(year, month)
          end
      end)

      @doc """
      Returns the number of days in the given month.

      Composite calendars cannot answer this without a year so the
      default implementation returns `{:error, :undefined}`.

      """
      @impl true
      def days_in_month(_month), do: {:error, :undefined}

      @doc """
      Returns the number of days in a week.

      """
      def days_in_week, do: 7

      @doc """
      Returns a `Date.Range` representing a given year.

      """
      @impl true
      def year(year) do
        with {:ok, starts} <- Date.new(year, 1, 1, __MODULE__),
             {:ok, new_year} <- Date.new(year + 1, 1, 1, __MODULE__) do
          ends = Date.shift(new_year, day: -1)
          Date.range(starts, ends)
        end
      end

      @doc """
      Returns a `Date.Range` representing a given quarter of a year.

      """
      @impl true
      def quarter(year, quarter) do
        months_in_quarter = div(months_in_year(year), @quarters_in_year)
        starting_month = months_in_quarter * (quarter - 1) + 1
        starting_day = 1
        ending_month = starting_month + months_in_quarter - 1
        ending_day = days_in_month(year, ending_month)

        with {:ok, start_date} <- Date.new(year, starting_month, starting_day, __MODULE__),
             {:ok, end_date} <- Date.new(year, ending_month, ending_day, __MODULE__) do
          Date.range(start_date, end_date)
        end
      end

      @doc """
      Returns a `Date.Range` representing a given month of a year.

      """
      @impl true
      def month(year, month) do
        {:ok, starts} = Date.new(year, month, 1, __MODULE__)

        {next_year, next_month} = following_year_and_month(year, month)
        ending_iso_days = date_to_iso_days(next_year, next_month, 1) - 1
        {ny, nm, nd} = date_from_iso_days(ending_iso_days)
        {:ok, ends} = Date.new(ny, nm, nd, __MODULE__)

        Date.range(starts, ends)
      end

      @doc false
      def following_year_and_month(year, month) do
        if month < months_in_year(year) do
          {year, month + 1}
        else
          {year + 1, 1}
        end
      end

      @doc """
      Returns a `Date.Range` representing a given week of a year.

      Not all base calendars define weeks; the result depends on the
      calendar in effect on 1 January of the given year.

      """
      @impl true
      def week(year, week) do
        base_calendar = calendar_for_date(year, 1, 1)

        case base_calendar.week(year, week) do
          %Date.Range{first_in_iso_days: first_days, last_in_iso_days: last_days} ->
            {y1, m1, d1} = date_from_iso_days(first_days)
            {y2, m2, d2} = date_from_iso_days(last_days)

            {:ok, starts} = Date.new(y1, m1, d1, __MODULE__)
            {:ok, ends} = Date.new(y2, m2, d2, __MODULE__)

            Date.range(starts, ends)

          other ->
            other
        end
      end

      @doc """
      Returns whether the given year is a leap year, in the context
      of the calendar in effect on the first day of that year.

      """
      @impl true
      def leap_year?(year) do
        calendar = calendar_for_date(year, 1, 1)
        calendar.leap_year?(year)
      end

      @doc """
      Returns the number of days since the calendar epoch for the
      given `year-month-day`.

      """
      for {_iso_days, y, m, d, calendar} <- reverse do
        def date_to_iso_days(year, month, day)
            when year > unquote(y) or
                   (year >= unquote(y) and month > unquote(m)) or
                   (year >= unquote(y) and month >= unquote(m) and day >= unquote(d)) do
          unquote(calendar).date_to_iso_days(year, month, day)
        end
      end

      def date_to_iso_days(%{year: year, month: month, day: day, calendar: __MODULE__}) do
        date_to_iso_days(year, month, day)
      end

      def date_to_iso_days(%{calendar: _calendar} = date) do
        date
        |> Date.convert!(__MODULE__)
        |> date_to_iso_days()
      end

      @doc """
      Returns `{year, month, day}` calculated from the number of
      `iso_days`.

      """
      for {transition_iso_days, _year, _month, _day, calendar} <- reverse do
        def date_from_iso_days(iso_days) when iso_days >= unquote(transition_iso_days) do
          unquote(calendar).date_from_iso_days(iso_days)
        end
      end

      @doc """
      Returns the `t:Calendar.iso_days/0` form of the specified
      datetime.

      """
      @impl true
      @spec naive_datetime_to_iso_days(
              Calendar.year(),
              Calendar.month(),
              Calendar.day(),
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond()
            ) :: Calendar.iso_days()
      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        iso_days = date_to_iso_days(year, month, day)
        day_fraction = time_to_day_fraction(hour, minute, second, microsecond)
        {iso_days, day_fraction}
      end

      @doc """
      Converts a `t:Calendar.iso_days/0` to the datetime form for
      this calendar.

      """
      @impl true
      def naive_datetime_from_iso_days({days, day_fraction}) do
        {year, month, day} = date_from_iso_days(days)
        {hour, minute, second, microsecond} = time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc false
      @impl true
      def date_to_string(year, month, day) do
        Calendar.ISO.date_to_string(year, month, day)
      end

      @doc false
      @impl true
      def datetime_to_string(
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
          ) do
        Calendar.ISO.datetime_to_string(
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
        )
      end

      @doc false
      @impl true
      def naive_datetime_to_string(year, month, day, hour, minute, second, microsecond) do
        Calendar.ISO.naive_datetime_to_string(year, month, day, hour, minute, second, microsecond)
      end

      @doc false
      calendar_impl()

      def parse_date(string) do
        Calendrical.Parse.parse_date(string, __MODULE__)
      end

      @doc false
      calendar_impl()

      def parse_utc_datetime(string) do
        Calendrical.Parse.parse_utc_datetime(string, __MODULE__)
      end

      @doc false
      calendar_impl()

      def parse_naive_datetime(string) do
        Calendrical.Parse.parse_naive_datetime(string, __MODULE__)
      end

      @doc """
      Adds an `increment` number of `:months` or `:quarters` to the
      given `year-month-day`. Delegates to whichever base calendar is
      in effect on the input date.

      """
      @impl true
      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, date_part, increment, options)
          when date_part in [:months, :quarters] do
        calendar = calendar_for_date(year, month, day)
        calendar.plus(year, month, day, date_part, increment, options)
      end

      @doc """
      Shifts a date by the given duration.

      """
      @impl true
      @spec shift_date(year, month, day, Duration.t()) :: {year, month, day}
      def shift_date(year, month, day, duration) do
        shift_options = shift_date_options(duration)

        Enum.reduce(shift_options, {year, month, day}, fn
          {_, 0}, date ->
            date

          {:month, value}, date ->
            shift_months(date, value)

          {:day, value}, date ->
            shift_days(date, value)
        end)
      end

      @doc false
      def shift_days({year, month, day}, days) do
        date_to_iso_days(year, month, day)
        |> Kernel.+(days)
        |> date_from_iso_days()
      end

      defp shift_months({year, month, day}, months) do
        months_in_year = months_in_year(year)
        total_months = year * months_in_year + month + months - 1

        new_year = Integer.floor_div(total_months, months_in_year)

        new_month =
          case rem(total_months, months_in_year) + 1 do
            new_month when new_month < 1 -> new_month + months_in_year
            new_month -> new_month
          end

        new_day = min(day, days_in_month(new_year, new_month))

        {new_year, new_month, new_day}
      end

      defp shift_date_options(%Duration{
             year: year,
             month: month,
             week: week,
             day: day,
             hour: 0,
             minute: 0,
             second: 0,
             microsecond: {0, _precision}
           }) do
        [
          month: year * 12 + month,
          day: week * 7 + day
        ]
      end

      defp shift_date_options(_duration) do
        raise ArgumentError,
              "cannot shift date by time scale unit. Expected :year, :month, :week, :day"
      end

      @doc false
      @impl Calendar
      defdelegate shift_time(hour, minute, second, microsecond, duration), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate shift_naive_datetime(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                    microsecond,
                    duration
                  ),
                  to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate parse_time(string), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate months_in_year(year), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO
    end
  end
end
