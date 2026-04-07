defmodule Calendrical.Behaviour do
  @moduledoc """
  Provides default implementations of the `Calendar` and `Calendrical`
  callbacks for algorithmic calendars.

  A calendar that `use`s this module gets a complete `Calendar` and
  `Calendrical` implementation derived from a small number of options
  plus two functions the calendar must define itself:

  * `date_to_iso_days/3` — convert a calendar `{year, month, day}` to
    an integer ISO day number.
  * `date_from_iso_days/1` — convert an integer ISO day number back to
    a calendar `{year, month, day}`.

  Every other callback is generated with a sensible default that the
  calendar can override with `defoverridable` (all callbacks are made
  overridable automatically).

  ## Example

      defmodule MyApp.MyCalendar do
        use Calendrical.Behaviour,
          epoch: ~D[0001-01-01 Calendar.ISO],
          cldr_calendar_type: :gregorian

        @impl true
        def leap_year?(year), do: rem(year, 4) == 0

        def date_to_iso_days(year, month, day) do
          # ... calendar-specific calculation
        end

        def date_from_iso_days(iso_days) do
          # ... calendar-specific calculation
        end
      end

  ## Options

  * `:epoch` (required) — the epoch of the calendar as a `t:Date.t/0`
    sigil literal in any calendar that has already been compiled
    (typically `Calendar.ISO`, `Calendrical.Gregorian`, or
    `Calendrical.Julian`). The epoch is converted to ISO days at compile
    time and made available via the generated `epoch/0` function. Example:
    `epoch: ~D[0622-03-20 Calendrical.Julian]`.

  * `:cldr_calendar_type` — the CLDR calendar type used to look up
    locale data (era names, month names, day names, etc.) via
    `Localize.Calendar`. Must be one of the values listed in
    `Calendrical.cldr_calendar_type/0`. Defaults to `:gregorian`.
    Example: `cldr_calendar_type: :persian`.

  * `:cldr_calendar_base` — whether the calendar is `:month`-based or
    `:week`-based. Returned by the generated `calendar_base/0` function.
    Defaults to `:month`.

  * `:days_in_week` — the number of days in a week. Returned by the
    generated `days_in_week/0` function and used to compute
    `last_day_of_week/0`. Defaults to `7`.

  * `:first_day_of_week` — the day-of-week ordinal (1..7) on which the
    week begins, where `1` is Monday and `7` is Sunday. The special value
    `:first` causes `day_of_week/4` to use the first day of the calendar
    year as the start of each week (used by some week-based calendars).
    Defaults to `1` (Monday).

  * `:months_in_ordinary_year` — the number of months in a non-leap
    year. Returned by `months_in_ordinary_year/0` and used as the default
    return value of `months_in_year/1` for non-leap years. Defaults to
    `12`.

  * `:months_in_leap_year` — the number of months in a leap year.
    Returned by `months_in_leap_year/0` and used as the default return
    value of `months_in_year/1` for leap years. Defaults to the value of
    `:months_in_ordinary_year`. Calendars with a leap month (such as the
    Hebrew calendar) should set this to one more than
    `:months_in_ordinary_year`.

  ## Generated functions

  After `use Calendrical.Behaviour, ...`, the following functions are
  available in the calling module and may be overridden:

  * Identity / configuration: `epoch/0`, `epoch_day_of_week/0`,
    `first_day_of_week/0`, `last_day_of_week/0`, `cldr_calendar_type/0`,
    `calendar_base/0`, `days_in_week/0`, `months_in_ordinary_year/0`,
    `months_in_leap_year/0`.

  * Validity: `valid_date?/3`, `valid_time?/4`.

  * Year/era: `year_of_era/1`, `year_of_era/3`, `calendar_year/3`,
    `extended_year/3`, `related_gregorian_year/3`, `cyclic_year/3`,
    `day_of_era/3`.

  * Periods: `quarter_of_year/3`, `month_of_year/3`, `week_of_year/3`,
    `iso_week_of_year/3`, `week_of_month/3`, `day_of_year/3`,
    `day_of_week/4`.

  * Counts: `months_in_year/1`, `weeks_in_year/1`, `days_in_year/1`,
    `days_in_month/1`, `days_in_month/2`, `periods_in_year/1`.

  * Ranges: `year/1`, `quarter/2`, `month/2`, `week/2`.

  * Arithmetic: `plus/5`, `plus/6`, `shift_date/4`, `shift_time/5`,
    `shift_naive_datetime/8`.

  * Conversion: `naive_datetime_to_iso_days/7`,
    `naive_datetime_from_iso_days/1`,
    `iso_days_to_beginning_of_day/1`, `iso_days_to_end_of_day/1`.

  * Parsing/formatting: `parse_date/1`, `parse_time/1`,
    `parse_naive_datetime/1`, `parse_utc_datetime/1`,
    `date_to_string/3`, `time_to_string/4`, `naive_datetime_to_string/7`,
    `datetime_to_string/11`, `time_to_day_fraction/4`,
    `time_from_day_fraction/1`, `day_rollover_relative_to_midnight_utc/0`.

  ## Era support

  When the using module is compiled, an `@after_compile` hook calls
  `Calendrical.Era.define_era_module/1` which generates a
  `Calendrical.Era.<CalendarType>` module from CLDR era data and uses it
  to implement the default `year_of_era/{1, 3}` and `day_of_era/3`
  functions. Calendars whose era logic does not match the CLDR data can
  override these callbacks directly.

  """

  defmacro __using__(opts \\ []) do
    epoch = Keyword.fetch!(opts, :epoch)

    {date, []} = Code.eval_quoted(epoch)
    epoch_iso_days = Calendrical.date_to_iso_days(date)
    epoch_day_of_week = date |> Date.convert!(Calendar.ISO) |> Date.day_of_week()
    days_in_week = Keyword.get(opts, :days_in_week, 7)
    first_day_of_week = Keyword.get(opts, :first_day_of_week, 1)

    cldr_calendar_type = Keyword.get(opts, :cldr_calendar_type, :gregorian)
    cldr_calendar_base = Keyword.get(opts, :cldr_calendar_base, :month)
    months_in_ordinary_year = Keyword.get(opts, :months_in_ordinary_year, 12)
    months_in_leap_year = Keyword.get(opts, :months_in_leap_year, months_in_ordinary_year)

    quote do
      import Localize.Macros

      @behaviour Calendar
      @behaviour Calendrical

      @after_compile Calendrical.Behaviour

      @days_in_week unquote(days_in_week)
      @quarters_in_year 4

      @epoch unquote(epoch_iso_days)
      @epoch_day_of_week unquote(epoch_day_of_week)
      @first_day_of_week unquote(first_day_of_week)
      @last_day_of_week Localize.Utils.Math.amod(
                          @first_day_of_week + @days_in_week - 1,
                          @days_in_week
                        )

      @months_in_ordinary_year unquote(months_in_ordinary_year)
      @months_in_leap_year unquote(months_in_leap_year)

      def epoch do
        @epoch
      end

      def epoch_day_of_week do
        @epoch_day_of_week
      end

      def first_day_of_week do
        @first_day_of_week
      end

      def last_day_of_week do
        @last_day_of_week
      end

      @doc """
      Defines the CLDR calendar type for this calendar.

      This type is used in support of `Calendrical.
      localize/3`.

      """
      @impl true
      def cldr_calendar_type do
        unquote(cldr_calendar_type)
      end

      @doc """
      Identifies whether this calendar is month
      or week based.

      """
      @impl true
      def calendar_base do
        unquote(cldr_calendar_base)
      end

      @doc """
      Determines if the `date` given is valid according to
      this calendar.

      """
      @impl true
      def valid_date?(year, month, day) do
        month <= months_in_year(year) && day <= days_in_month(year, month)
      end

      @doc """
      Returns the number of months in a normal year.

      """
      def months_in_ordinary_year do
        @months_in_ordinary_year
      end

      @doc """
      Returns the number of months in a leap year.

      """
      def months_in_leap_year do
        @months_in_leap_year
      end

      @doc """
      Calculates the year and era from the given `year`.

      """

      @era_module Calendrical.Era.era_module(unquote(cldr_calendar_type))

      @spec year_of_era(Calendar.year()) :: {year :: Calendar.year(), era :: Calendar.era()}

      def year_of_era(year) do
        iso_days = date_to_iso_days(year, 1, 1)
        @era_module.year_of_era(iso_days, year)
      end

      @doc """
      Calculates the year and era from the given `date`.

      """
      @spec year_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {year :: Calendar.year(), era :: Calendar.era()}

      @impl true
      def year_of_era(year, month, day) do
        iso_days = date_to_iso_days(year, month, day)
        @era_module.year_of_era(iso_days, year)
      end

      @doc """
      Returns the calendar year as displayed
      on rendered calendars.

      """
      @spec calendar_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def calendar_year(year, month, day) do
        year
      end

      @doc """
      Returns the related gregorain year as displayed
      on rendered calendars.

      """
      @spec related_gregorian_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.year()

      @impl true
      def related_gregorian_year(year, month, day) do
        year
      end

      @doc """
      Returns the extended year as displayed
      on rendered calendars.

      """
      @spec extended_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()

      @impl true
      def extended_year(year, month, day) do
        year
      end

      @doc """
      Returns the cyclic year as displayed
      on rendered calendars.

      """
      @spec cyclic_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()

      @impl true
      def cyclic_year(year, month, day) do
        year
      end

      @doc """
      Returns the quarter of the year from the given
      `year`, `month`, and `day`.

      """
      @spec quarter_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendrical.quarter()

      @impl true
      def quarter_of_year(year, month, day) do
        ceil(month / (months_in_year(year) / @quarters_in_year))
      end

      @doc """
      Returns the month of the year from the given
      `year`, `month`, and `day`.

      """
      @spec month_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.month() | {Calendar.month(), Calendrical.leap_month?()}

      @impl true
      def month_of_year(_year, month, _day) do
        month
      end

      @doc """
      Calculates the week of the year from the given
      `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {:error, :not_defined}

      @impl true
      def week_of_year(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the ISO week of the year from the
      given `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec iso_week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {:error, :not_defined}

      @impl true
      def iso_week_of_year(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the week of the year from the given
      `year`, `month`, and `day`.

      By default this function always returns
      `{:error, :not_defined}`.

      """
      @spec week_of_month(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {pos_integer(), pos_integer()} | {:error, :not_defined}

      @impl true
      def week_of_month(_year, _month, _day) do
        {:error, :not_defined}
      end

      @doc """
      Calculates the day and era from the given
      `year`, `month`, and `day`.

      By default we consider on two eras: before the epoch
      and on-or-after the epoch.

      """
      @spec day_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
              {day :: Calendar.day(), era :: Calendar.era()}

      @impl true
      def day_of_era(year, month, day) do
        iso_days = date_to_iso_days(year, month, day)
        @era_module.day_of_era(iso_days)
      end

      @doc """
      Calculates the day of the year from the given
      `year`, `month`, and `day`.

      """
      @spec day_of_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.day()

      @impl true
      def day_of_year(year, month, day) do
        first_day = date_to_iso_days(year, 1, 1)
        this_day = date_to_iso_days(year, month, day)
        this_day - first_day + 1
      end

      @impl true

      @spec day_of_week(Calendar.year(), Calendar.month(), Calendar.day(), :default | atom()) ::
              {Calendar.day_of_week(), first_day_of_week :: non_neg_integer(),
               last_day_of_week :: non_neg_integer()}

      if @first_day_of_week == :first do
        def day_of_week(year, month, day, :default = starting_on) do
          iso_days = date_to_iso_days(year, month, day)
          first_day_of_year = date_to_iso_days(year, 1, 1)
          day_of_week = Integer.mod(iso_days - first_day_of_year, 7) + 1
          {day_of_week, 1, 7}
        end
      else
        def day_of_week(year, month, day, starting_on) do
          iso_days = date_to_iso_days(year, month, day)

          day_of_week =
            Integer.mod(iso_days + day_of_week_offset(starting_on, @first_day_of_week), 7) + 1

          {day_of_week, 1, 7}
        end
      end

      # The offset here is based upon the epoch being
      # 0000-01-01 which is a saturday=6. Therefore the offset
      # is what we add to the iso_days to get to 6.

      @doc false
      def day_of_week_offset(:default, first_day_of_week), do: 6 - first_day_of_week
      def day_of_week_offset(:monday, _first_day_of_week), do: 5
      def day_of_week_offset(:tuesday, _first_day_of_week), do: 4
      def day_of_week_offset(:wednesday, _first_day_of_week), do: 3
      def day_of_week_offset(:thursday, _first_day_of_week), do: 2
      def day_of_week_offset(:friday, _first_day_of_week), do: 1
      def day_of_week_offset(:saturday, _first_day_of_week), do: 0
      def day_of_week_offset(:sunday, _first_day_of_week), do: 6

      def day_of_week_offset(starting_on, _first_day_of_week) do
        raise ArgumentError,
              "starting_on #{inspect(starting_on)} is not supported for #{inspect(__MODULE__)}"
      end

      defoverridable day_of_week: 4

      @impl true
      def shift_date(year, month, day, duration) do
        Calendrical.shift_date(year, month, day, __MODULE__, duration)
      end

      @impl true
      def shift_time(hour, minute, second, microsecond, duration) do
        Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)
      end

      @impl true
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
      Returns the number of periods in a given
      `year`. A period corresponds to a month
      in month-based calendars and a week in
      week-based calendars.

      """
      @impl true

      def periods_in_year(year) do
        months_in_year(year)
      end

      @doc """
      Returns the number of months in a
      given `year`.

      """
      @impl true

      def months_in_year(year) do
        if leap_year?(year), do: @months_in_leap_year, else: @months_in_ordinary_year
      end

      @doc """
      Returns the number of weeks in a
      given `year`.

      """
      @impl true

      def weeks_in_year(_year) do
        {:error, :not_defined}
      end

      @doc """
      Returns the number days in a given year.

      The year is the number of years since the
      epoch.

      """
      @impl true

      def days_in_year(year) do
        this_year = date_to_iso_days(year, 1, 1)
        next_year = date_to_iso_days(year + 1, 1, 1)
        next_year - this_year + 1
      end

      @doc """
      Returns how many days there are in the given year
      and month.

      """
      @spec days_in_month(Calendar.year(), Calendar.month()) :: Calendar.month()
      @impl true

      def days_in_month(year, month) do
        start_of_this_month =
          date_to_iso_days(year, month, 1)

        start_of_next_month =
          if month == months_in_year(year) do
            date_to_iso_days(year + 1, 1, 1)
          else
            date_to_iso_days(year, month + 1, 1)
          end

        start_of_next_month - start_of_this_month
      end

      @doc """
      Returns how many days there are in the given month.

      Must be implemented in derived calendars because
      we cannot know what the calendar format is.

      """
      @spec days_in_month(Calendar.month()) ::
              Calendar.month() | {:ambiguous, Range.t() | [pos_integer()]} | {:error, :undefined}
      @impl true

      def days_in_month(month) do
        {:error, :undefined}
      end

      @doc """
      Returns the number days in a a week.

      """
      def days_in_week do
        @days_in_week
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given year.

      """
      @impl true

      def year(year) do
        last_month = months_in_year(year)
        days_in_last_month = days_in_month(year, last_month)

        with {:ok, start_date} <- Date.new(year, 1, 1, __MODULE__),
             {:ok, end_date} <- Date.new(year, last_month, days_in_last_month, __MODULE__) do
          Date.range(start_date, end_date)
        end
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given quarter of a year.

      """
      @impl true

      def quarter(_year, _quarter) do
        {:error, :not_defined}
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given month of a year.

      """
      @impl true

      def month(year, month) do
        starting_day = 1
        ending_day = days_in_month(year, month)

        with {:ok, start_date} <- Date.new(year, month, starting_day, __MODULE__),
             {:ok, end_date} <- Date.new(year, month, ending_day, __MODULE__) do
          Date.range(start_date, end_date)
        end
      end

      @doc """
      Returns a `Date.Range.t` representing
      a given week of a year.

      """
      @impl true

      def week(_year, _week) do
        {:error, :not_defined}
      end

      @doc """
      Adds an `increment` number of `date_part`s
      to a `year-month-day`.

      `date_part` can be `:months` only.

      """
      @impl true

      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :months, months, options) do
        months_in_year = months_in_year(year)
        {year_increment, new_month} = Localize.Utils.Math.div_amod(month + months, months_in_year)
        new_year = year + year_increment

        new_day =
          if Keyword.get(options, :coerce, false) do
            max_new_day = days_in_month(new_year, new_month)
            min(day, max_new_day)
          else
            day
          end

        {new_year, new_month, new_day}
      end

      @doc """
      Returns the `t:Calendar.iso_days` format of
      the specified date.

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
        {date_to_iso_days(year, month, day),
         time_to_day_fraction(hour, minute, second, microsecond)}
      end

      @doc """
      Converts the `t:Calendar.iso_days` format to the
      datetime format specified by this calendar.

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
        {year, month, day} = date_from_iso_days(days)
        {hour, minute, second, microsecond} = time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
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

      @doc false
      @impl Calendar
      defdelegate parse_time(string), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate date_to_string(year, month, day), to: Calendar.ISO

      @doc false
      @impl Calendar
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
      @impl Calendar
      defdelegate naive_datetime_to_string(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                    microsecond
                  ),
                  to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl Calendar
      defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO

      @doc false
      @impl true
      defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

      @doc false
      @impl true
      defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO

      defoverridable valid_date?: 3
      defoverridable valid_time?: 4
      defoverridable naive_datetime_to_string: 7
      defoverridable date_to_string: 3
      defoverridable time_to_day_fraction: 4
      defoverridable time_from_day_fraction: 1
      defoverridable day_rollover_relative_to_midnight_utc: 0
      defoverridable parse_time: 1
      defoverridable parse_naive_datetime: 1
      defoverridable parse_utc_datetime: 1
      defoverridable parse_date: 1
      defoverridable naive_datetime_from_iso_days: 1
      defoverridable naive_datetime_to_iso_days: 7

      defoverridable year_of_era: 1
      defoverridable year_of_era: 3
      defoverridable quarter_of_year: 3
      defoverridable month_of_year: 3
      defoverridable week_of_year: 3
      defoverridable iso_week_of_year: 3
      defoverridable week_of_month: 3
      defoverridable day_of_era: 3
      defoverridable day_of_year: 3

      defoverridable periods_in_year: 1
      defoverridable months_in_year: 1
      defoverridable weeks_in_year: 1
      defoverridable days_in_year: 1
      defoverridable days_in_month: 2
      defoverridable days_in_month: 1
      defoverridable days_in_week: 0

      defoverridable year: 1
      defoverridable quarter: 2
      defoverridable month: 2
      defoverridable week: 2
      defoverridable plus: 5
      defoverridable plus: 6

      defoverridable epoch: 0
      defoverridable cldr_calendar_type: 0
      defoverridable calendar_base: 0

      defoverridable calendar_year: 3
      defoverridable extended_year: 3
      defoverridable related_gregorian_year: 3
      defoverridable cyclic_year: 3
    end
  end

  def __after_compile__(env, _bytecode) do
    Calendrical.Era.define_era_module(env.module)
  end
end
