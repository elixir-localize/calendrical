defmodule Calendrical.Compiler.Week do
  @moduledoc false

  defmacro __before_compile__(env) do
    config =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Calendrical.Config.extract_options()
      |> Calendrical.Config.validate_config!(:week)

    Module.put_attribute(env.module, :calendar_config, config)

    # A year that ends on its configured day of the week begins, and its
    # weeks begin, on the day after.
    week_first_day =
      if config.first_or_last == :last and is_integer(config.day_of_week),
        do: Integer.mod(config.day_of_week, 7) + 1,
        else: config.day_of_week

    Module.put_attribute(env.module, :week_first_day, week_first_day)

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
      Returns the static facts about this calendar, as
      `t:Calendrical.Info.t/0`.

      """
      @impl true
      def info do
        config = __config__()

        Calendrical.Info.new(__MODULE__,
          cldr_calendar_type: :generic,
          era_calendar_type: config.cldr_calendar_type,
          structure: :weeks,
          months_in_year: {12, 12},
          years_in_cycle: 400,
          parsing_calendar: Calendar.ISO,
          epoch: date_to_iso_days(1, 1, 1),
          weeks: Calendrical.Info.week_rule(@week_first_day, config.min_days_in_first_week)
        )
      end

      @doc """
      Determines if the date given is valid according to the this calendar.

      """
      @impl true
      def valid_date?(year, month, day) do
        Week.valid_date?(year, month, day, __config__())
      end

      @doc """
      Returns the figures a date is written with: its week year, the
      Gregorian month that names its month, and its day of the month.

      """
      @impl true
      def written_date(year, month, day) do
        {year, Week.cardinal_month(month, __config__()), day}
      end

      @doc """
      Returns the date of this calendar that written figures name: the
      month of the year the named month is, with the year and the day as
      written, where they are a date.

      """
      @impl true
      def date_from_written_date(year, named_month, day) do
        Calendrical.Base.Written.own_date(
          __MODULE__,
          year,
          Week.month_from_cardinal_month(named_month, __config__()),
          day
        )
      end

      @doc """
      Calculates the day and era from the given `year`, `month`, and `day`.

      """
      @spec day_of_era(Calendrical.year(), Calendrical.month(), Calendrical.day()) ::
              {day :: Calendrical.day(), era :: Calendrical.era()}
              | Calendrical.date_error()

      @impl true
      def day_of_era(year, month, day) do
        {year, week, day} = Week.week_date(year, month, day, __config__())
        Week.day_of_era(year, week, day, __config__())
      end

      @doc """
      Returns how many days there are in the given month of a year.

      A month of this calendar is four or five weeks, as its pattern of weeks gives it (4-4-5 and its kin), and the last month of a year of 53 weeks has one week more.

      ### Arguments

      * `year` is any year.

      * `month` is a month of that year, from 1 to 12.

      ### Returns

      * The number of days, a multiple of seven, or

      * `{:error, :invalid_date}` for a month the year does not have.

      """
      @spec days_in_month(year :: Calendrical.year(), month :: Calendrical.month()) ::
              days ::
              Calendar.day()
              | {:error, :invalid_date | Exception.t()}

      @impl true
      def days_in_month(year, month) do
        Week.days_in_month(year, month, __config__())
      end

      @doc """
      Adds an `increment` number of `date_part`s
      to a `year-month-day`.

      `date_part` can be `:years`, `:quarters`,
      `:months` or `days`.

      """
      @impl true
      def shift(year, month, day, date_part, increment, options \\ [])

      def shift(year, month, day, date_part, increment, options)
          when date_part in [:years, :quarters, :months, :weeks, :days] do
        {year, week, day} = Week.week_date(year, month, day, __config__())

        {year, week, day} =
          Week.shift(year, week, day, __config__(), date_part, increment, options)

        Week.month_date(year, week, day, __config__())
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
      Returns the number of days since the calendar
      epoch for a given `year-month-day`

      """
      @impl true
      def date_to_iso_days(year, month, day) do
        {year, week, day} = Week.week_date(year, month, day, __config__())
        Week.date_to_iso_days(year, week, day, __config__())
      end

      @doc """
      Returns `{year, month, day}` calculated from
      the number of `iso_days`.

      """
      @impl true
      def date_from_iso_days(iso_days) do
        {year, week, day} = Week.date_from_iso_days(iso_days, __config__())
        Week.month_date(year, week, day, __config__())
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

      @doc false
      @impl true
      defdelegate months_in_year(year), to: Calendar.ISO
    end
  end
end
