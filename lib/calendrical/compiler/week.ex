defmodule Calendrical.Compiler.Week do
  @moduledoc false

  defmacro __before_compile__(env) do
    config =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Calendrical.Config.extract_options()
      |> Calendrical.Config.validate_config!(:week)

    Module.put_attribute(env.module, :calendar_config, config)

    quote location: :keep do
      @behaviour Calendar
      @behaviour Calendrical
      use Calendrical.Compiler.StandardCallbacks

      # @type year :: -9999..9999
      # @type month :: 1..12
      # @type week :: 1..53
      # @type day :: 1..7

      import Localize.Macros

      import Calendrical,
        only: [
          missing_date_error: 4,
          missing_year_month_error: 3,
          missing_month_error: 2,
          missing_year_error: 2
        ]

      alias Calendrical.Base.Week

      def __config__ do
        @calendar_config
      end

      @doc """
      Identifies that the calendar is week based.
      """
      @impl true
      def calendar_base do
        :week
      end

      @doc """
      Returns the CLDR calendar type whose data names this calendar's months, days and quarters: `:generic`.

      A calendar of weeks has no month names of its own: its months are the ordinal periods of its pattern of weeks (4-4-5, 4-5-4 or 5-4-4), so they take the names of CLDR's generic calendar, "M01" to "M12". Its days, quarters and day periods are the generic calendar's, which are the Gregorian calendar's.

      """
      @impl true
      def cldr_calendar_type do
        :generic
      end

      @doc """
      Returns the calendar module of this calendar's family whose CLDR
      calendar type is the one given.

      Localize asks a calendar for the calendars of its family: a CLDR
      calendar type names no module of its own, and a locale's `-u-ca-`
      names a type rather than a calendar.

      """
      @impl Calendrical
      defdelegate calendar_from_cldr_calendar_type(calendar_type), to: Calendrical

      @doc """
      Returns the CLDR calendar type that names the calendar's eras: `:gregorian`.

      A calendar of weeks counts its years as the Gregorian calendar does, and CLDR's generic calendar leaves its eras unnamed ("ERA0", "ERA1"), so its eras take the Gregorian calendar's names.

      """
      @impl true
      def era_calendar_type do
        :gregorian
      end

      @doc """
      Returns the calendar module a date written for this calendar
      is parsed in: `Calendar.ISO`. A written month and day, such as
      "Feb 1, 2024", name no single week, so a date is read as a
      Gregorian date and converted into this calendar.

      """
      @impl true
      def parsing_calendar do
        Calendar.ISO
      end

      @doc """
      Determines if the date given is valid according to the this calendar.

      """
      @impl true
      def valid_date?(year, week, day) do
        Week.valid_date?(year, week, day, __config__())
      end

      @doc """
      Calculates the year and era from the given `year`.
      The ISO calendar has two eras: the current era which
      starts in year 1 and is defined as era "1". And a
      second era for those years less than 1 defined as
      era "0".

      """
      @spec year_of_era(Calendrical.year()) ::
              {year :: Calendar.year(), era :: Calendrical.era()}

      def year_of_era(year) do
        Week.year_of_era(year, __config__())
      end

      @doc """
      Calculates the year and era from the given `year`,
      `month` and `day`.

      The ISO calendar has two eras: the current era which
      starts in year 1 and is defined as era "1". And a
      second era for those years less than 1 defined as
      era "0".

      """
      @spec year_of_era(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              {year :: Calendar.year(), era :: Calendrical.era()}
              | Calendrical.date_error()

      @impl true

      def year_of_era(year, _week, _day) do
        Week.year_of_era(year, __config__())
      end

      @doc """
      Returns the calendar year as displayed
      on rendered calendars.

      """
      @spec calendar_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              year :: Calendar.year() | Calendrical.date_error()

      @impl true
      def calendar_year(year, _week, _day) when is_integer(year) do
        year
      end

      def calendar_year(year, _week, _day) do
        {:error, missing_year_error("calendar_year", year)}
      end

      @doc """
      Returns the related gregorian year as displayed
      on rendered calendars.

      """
      @spec related_gregorian_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              year :: Calendar.year() | Calendrical.date_error()

      @impl true
      def related_gregorian_year(year, _week, _day) when is_integer(year) do
        year
      end

      def related_gregorian_year(year, _week, _day) do
        {:error, missing_year_error("calendar_year", year)}
      end

      @doc """
      Returns the extended year, one number for the year through every era: the calendar year itself in this calendar.

      """
      @spec extended_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              year :: Calendar.year() | Calendrical.date_error()

      @impl true
      def extended_year(year, week, day) when is_integer(year) do
        year
      end

      def extended_year(year, _week, _day) do
        {:error, missing_year_error("extended_year", year)}
      end

      @doc """
      Returns the cyclic year as displayed
      on rendered calendars.

      """
      @spec cyclic_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              year :: Calendar.year() | Calendrical.date_error()

      @impl true
      def cyclic_year(year, _week, _day) when is_integer(year) do
        year
      end

      def cyclic_year(year, _week, _day) do
        {:error, missing_year_error("cyclic_year", year)}
      end

      @doc """
      Calculates the quarter of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 4.

      """
      @spec quarter_of_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              quarter :: Calendrical.quarter() | Calendrical.date_error()

      @impl true
      def quarter_of_year(year, week, day) do
        Week.quarter_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the month of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 12.

      """
      @spec month_of_year(
              year :: Calendrical.year(),
              week :: Calendrical.week(),
              day :: Calendrical.day()
            ) ::
              month :: Calendar.month() | Calendrical.date_error()

      @impl true
      def month_of_year(year, week, day) do
        Week.month_of_year(year, week, day, __config__())
      end

      @doc """
      Returns the Gregorian month that a month of the year, as
      `month_of_year/3` returns it, names: counted from the month
      the year begins in.

      """
      @spec cardinal_month(Calendar.month()) :: Calendar.month()

      @impl true
      def cardinal_month(month) do
        Week.cardinal_month(month, __config__())
      end

      @doc """
      Calculates the week of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 53.

      """
      @spec week_of_year(Calendrical.year(), Calendrical.month(), Calendrical.day()) ::
              {year :: Calendar.year(), week :: Calendrical.week()}
              | Calendrical.date_error()

      @impl true
      def week_of_year(year, week, day) do
        Week.week_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the ISO week of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 53.

      """
      @spec iso_week_of_year(Calendrical.year(), Calendrical.month(), Calendrical.day()) ::
              {year :: Calendar.year(), week :: Calendrical.week()}
              | Calendrical.date_error()

      @impl true
      def iso_week_of_year(year, week, day) do
        Week.iso_week_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the week of the month from the given `year`, `month`, and `day`.
      It is an integer from 1 to 5.

      """
      @spec week_of_month(Calendrical.year(), Calendrical.week(), Calendar.day()) ::
              {month :: Calendar.month(), week :: Calendrical.week()}
              | Calendrical.date_error()

      @impl true
      def week_of_month(year, week, day) do
        Week.week_of_month(year, week, day, __config__())
      end

      @doc """
      Calculates the day and era from the given `year`, `month`, and `day`.

      """
      @spec day_of_era(Calendrical.year(), Calendrical.month(), Calendrical.day()) ::
              {day :: Calendrical.day(), era :: Calendrical.era()}
              | Calendrical.date_error()

      @impl true
      def day_of_era(year, week, day) do
        Week.day_of_era(year, week, day, __config__())
      end

      @doc """
      Calculates the day of the year from the given `year`, `month`, and `day`.
      It is an integer from 1 to 364, or to 371 in a long year.

      """
      @spec day_of_year(Calendrical.year(), Calendrical.month(), Calendrical.day()) ::
              day :: Calendar.day() | Calendrical.date_error()

      @impl true
      def day_of_year(year, week, day) do
        Week.day_of_year(year, week, day, __config__())
      end

      @doc """
      Calculates the day of the week from the given `year`, `week`, and `day`.
      It is an integer where 1 means the first day of the week and 7 means the
      last day of the week.

      Explicity, `1` does *not* mean `Monday` unless `starting_on` is `:monday`.

      """
      @spec day_of_week(
              year :: Calendrical.year(),
              month :: Calendrical.week(),
              day :: Calendrical.day(),
              :default | atom()
            ) ::
              {day_of_week :: Calendar.day_of_week(),
               first_day_of_week ::
                 Calendar.day_of_week(), last_day_of_week :: Calendar.day_of_week()}
              | Calendrical.date_error()

      @impl true
      def day_of_week(year, week, day, starting_on) do
        case Week.day_of_week(year, week, day, starting_on, __config__()) do
          {:error, reason} -> {:error, reason}
          day -> {day, 1, 7}
        end
      end

      @doc """
      Calculates the number of period in a given `year`. A period
      corresponds to a month in month-based calendars and
      a week in week-based calendars..

      """
      @spec periods_in_year(year :: Calendrical.year()) :: Calendar.week() | :error
      def periods_in_year(year) do
        {weeks_in_year, _} = weeks_in_year(year)
        weeks_in_year
      end

      @doc """
      Returns the number weeks in a given year.

      ### Arguments

      * `year` is any `t:Calendar.year/0`

      ### Returns

      * `{weeks_in_year, days_in_last_week}`

      ### Example

          iex> Calendrical.ISOWeek.weeks_in_year 2020
          {53, 7}

          iex> Calendrical.ISOWeek.weeks_in_year 2021
          {52, 7}

      """
      @spec weeks_in_year(year :: Calendrical.year()) ::
              {weeks :: Calendar.week(), days_in_last_week :: Calendar.day()}
              | {:error, Exception.t()}

      @impl true
      def weeks_in_year(year) do
        Week.weeks_in_year(year, __config__())
      end

      @doc """
      Returns the number days in a given year.

      """
      @spec days_in_year(year :: Calendrical.year()) ::
              days :: Calendar.day() | {:error, Exception.t()}

      @impl true
      def days_in_year(year) do
        Week.days_in_year(year, __config__())
      end

      @doc """
      Returns the dates in this calendar, of the given `month` and `day`,
      that fall within the given Gregorian year — zero, one or two of them,
      in this calendar.

      """
      @spec dates_in_gregorian_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              [Date.t()]

      @impl true
      def dates_in_gregorian_year(gregorian_year, month, day) do
        Calendrical.generic_dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)
      end

      @doc """
      Returns how many days there are in the given week of a year: seven.

      A date of this calendar is a year, a week and a day of the week, so the week is its month field, and it is the week that `Date.days_in_month/1` and `Date.end_of_month/1` ask about: the last day of 2026-W25 is 2026-W25-7. The days of a month of the calendar's pattern of weeks (4-4-5 and its kin) are those of `month/2`.

      ### Arguments

      * `year` is any year.

      * `week` is a week of that year.

      ### Returns

      * `7`, or

      * `{:error, :invalid_date}` for a week the year does not have.

      """
      @spec days_in_month(year :: Calendrical.year(), week :: Calendrical.week()) ::
              days ::
              Calendar.day()
              | {:error, :invalid_date | Exception.t()}

      @impl true
      def days_in_month(year, week) do
        Week.days_in_month(year, week, __config__())
      end

      @doc """
      Returns how many days there are in the given week, whatever the year: seven.

      ### Arguments

      * `week` is a week of the year.

      ### Returns

      * `7`, or

      * `{:error, :invalid_date}` for a week no year has.

      """
      @spec days_in_month(week :: Calendrical.week()) ::
              days ::
              Calendar.day()
              | {:error, :invalid_date | Exception.t()}

      @impl true
      def days_in_month(week) do
        Week.days_in_month(week, __config__())
      end

      @doc """
      Returns the number of months in a year (without a year).

      """
      @impl true
      def months_in_year do
        Week.months_in_year(__config__())
      end

      @doc """
      Returns the number days in a a week.

      """
      @impl true
      def days_in_week do
        Week.days_in_week()
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given year.

      """
      @impl true
      def year(year) do
        Week.year(year, __config__())
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given quarter of a year.

      """
      @impl true
      def quarter(year, quarter) do
        Week.quarter(year, quarter, __config__())
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given quadrimester (third) of a year: four of its months.

      """
      def quadrimester(year, quadrimester) do
        Calendrical.Period.date_range(__MODULE__, year, quadrimester, 4)
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given semester (half) of a year: six of its months.

      """
      def semester(year, semester) do
        Calendrical.Period.date_range(__MODULE__, year, semester, 6)
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given month of a year.

      """
      @impl true
      def month(year, month) do
        Week.month(year, month, __config__())
      end

      @doc """
      Returns a `t:Date.Range.t/0` representing
      a given week of a year.

      """
      @impl true
      def week(year, week) do
        Week.week(year, week, __config__())
      end

      @doc """
      Adds an `increment` number of `date_part`s
      to a `year-month-day`.

      `date_part` can be `:years`, `:quarters`,
      `:months` or `days`.

      """
      @impl true
      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :years, quarters, options) do
        Week.plus(year, month, day, __config__(), :years, quarters, options)
      end

      def plus(year, week, day, :quarters, quarters, options) do
        Week.plus(year, week, day, __config__(), :quarters, quarters, options)
      end

      def plus(year, week, day, :months, months, options) do
        Week.plus(year, week, day, __config__(), :months, months, options)
      end

      def plus(year, month, day, :weeks, weeks, options) do
        Week.plus(year, month, day, __config__(), :weeks, weeks, options)
      end

      def plus(year, week, day, :days, days, options) do
        Week.plus(year, week, day, __config__(), :days, days, options)
      end

      @doc """
      Returns the whole number of `date_part`s from one
      `{year, week, day}` to another — the inverse of `plus/6`.

      `date_part` can be `:years`, `:quarters`, `:months`, `:weeks`
      or `:days`; a month is a period of the calendar's weeks, as
      `plus/6` counts it. The count is the largest number `plus/6`
      can add to the earlier date without passing the later one; it
      is negative when `to` is before `from`.

      """
      @impl true
      def diff(from, to, date_part) do
        Calendrical.Base.Common.diff(__MODULE__, from, to, date_part)
      end

      @doc """
      Adds a :year, :month, :day or time increments

      These functions support CalendarInterval

      """
      def add(year, month, day, hour, minute, second, microsecond, :year, step) do
        {year, month, day} = plus(year, month, day, :years, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      def add(year, month, day, hour, minute, second, microsecond, :quarter, step) do
        {year, month, day} = plus(year, month, day, :quarters, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      def add(year, month, day, hour, minute, second, microsecond, :month, step) do
        {year, month, day} = plus(year, month, day, :months, step)
        {year, month, day, hour, minute, second, microsecond}
      end

      @doc """
      Returns if the given year is a leap year.

      """
      @spec leap_year?(Calendrical.year()) :: boolean()
      @impl true
      def leap_year?(year) do
        Week.long_year?(year, __config__())
      end

      @doc """
      Shifts a date by given duration.

      """
      @spec shift_date(Calendar.year(), Calendar.month(), Calendar.day(), Duration.t()) ::
              {Calendar.year(), Calendar.month(), Calendar.day()}

      @impl Calendar
      def shift_date(year, month, day, duration) do
        Calendrical.shift_date(year, month, day, __MODULE__, duration)
      end

      @doc """
      Shifts a time by given duration.

      """
      @spec shift_time(
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond(),
              Duration.t()
            ) ::
              {Calendar.hour(), Calendar.minute(), Calendar.second(), Calendar.microsecond()}

      @impl Calendar
      def shift_time(hour, minute, second, microsecond, duration) do
        Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)
      end

      @doc """
      Shifts a naive date time by given duration.

      """
      @spec shift_naive_datetime(
              Calendar.year(),
              Calendar.month(),
              Calendar.day(),
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond(),
              Duration.t()
            ) ::
              {
                Calendar.year(),
                Calendar.month(),
                Calendar.day(),
                Calendar.hour(),
                Calendar.minute(),
                Calendar.second(),
                Calendar.microsecond()
              }

      @impl Calendar
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

      @doc """
      Returns the number of days since the calendar
      epoch for a given `year-month-day`

      """
      @impl true
      def date_to_iso_days(year, week, day) do
        Week.date_to_iso_days(year, week, day, __config__())
      end

      @doc """
      Returns `{year, month, day}` calculated from
      the number of `iso_days`.

      """
      @impl true
      def date_from_iso_days(iso_days) do
        Week.date_from_iso_days(iso_days, __config__())
      end

      @doc """
      Returns the number of `iso_days` that is
      the first day of the given
      year for this calendar.

      """
      def first_gregorian_day_of_year(year) do
        Week.first_gregorian_day_of_year(year, __config__())
      end

      @doc """
      Returns the number of `iso_days` that is
      the last day of the given
      year for this calendar.

      """
      def last_gregorian_day_of_year(year) do
        Week.last_gregorian_day_of_year(year, __config__())
      end

      @doc """
      Returns the `t:Calendar.iso_days/0` format of the specified date.

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

      def naive_datetime_to_iso_days(year, week, day, hour, minute, second, microsecond) do
        Week.naive_datetime_to_iso_days(
          year,
          week,
          day,
          hour,
          minute,
          second,
          microsecond,
          __config__()
        )
      end

      @doc """
      Converts the `t:Calendar.iso_days/0` format to the datetime format specified by this calendar.

      """
      @spec naive_datetime_from_iso_days(Calendar.iso_days()) :: {
              Calendar.year(),
              Calendar.month(),
              Calendar.day(),
              Calendar.hour(),
              Calendar.minute(),
              Calendar.second(),
              Calendar.microsecond()
            }
      @impl true
      def naive_datetime_from_iso_days({days, day_fraction}) do
        Week.naive_datetime_from_iso_days({days, day_fraction}, __config__())
      end

      @doc false
      @impl true
      def date_to_string(year, month, day) do
        Week.date_to_string(year, month, day)
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
        Week.datetime_to_string(
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
        Week.naive_datetime_to_string(year, month, day, hour, minute, second, microsecond)
      end

      @doc false
      calendar_impl()

      def parse_date(string) do
        Calendrical.Parse.parse_week_date(string, __MODULE__)
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

      @doc false
      defdelegate parse_time(string), to: Calendar.ISO

      @doc false
      defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

      @doc false
      defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO

      @doc false
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      defdelegate months_in_year(year), to: Calendar.ISO

      @doc false
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO
    end
  end
end
