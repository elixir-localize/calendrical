defmodule Calendrical.Calendar do
  @moduledoc """
  Makes a hand-written calendar: one whose spine, `date_to_iso_days/3`
  and `date_from_iso_days/1`, the author writes, with `leap_year?/1`,
  `months_in_year/1` and `days_in_month/2`, and `leap_month/1` where the
  calendar has a leap month. Every other answer, from the day of the week
  to the ranges of a quarter, is derived from those and from the facts
  the options state, as `c:Calendrical.info/0` carries them.

  ### Example

      defmodule MyApp.MyCalendar do
        use Calendrical.Calendar,
          epoch: ~D[0001-01-01 Calendar.ISO],
          cldr_calendar_type: :gregorian

        @impl Calendar
        def leap_year?(year), do: rem(year, 4) == 0

        @impl true
        def date_to_iso_days(year, month, day) do
          # ... the calendar's own calculation
        end

        @impl true
        def date_from_iso_days(iso_days) do
          # ... the calendar's own calculation
        end
      end

  ### Options

  * `:epoch` (required) is the first day of the calendar's year 1, as a
    date in a calendar that has already been compiled, such as
    `~D[0622-03-20 Calendrical.Julian]`.

  * `:cldr_calendar_type` is the CLDR calendar whose data names the
    months, days and eras, `:gregorian` by default.

  * `:era_calendar_type` is the CLDR calendar whose eras the calendar
    counts years in, the CLDR calendar type by default.

  * `:months_in_year` is the number of months in a year, or
    `{fewest, most}` where a leap year has more, as the Hebrew calendar's
    `{12, 13}`. The default is `12`.

  * `:weeks` is the rule the calendar's own weeks follow: a keyword list
    with `:first_day`, 1 for Monday to 7 for Sunday, and
    `:min_days_in_first_week`, or `:from_first_day` for weeks counted from
    the first day of the year. The default is Monday and 1.

  * `:year_zero?` is whether the calendar has a year 0, `true` by default;
    a calendar without one goes from year -1 to year 1.

  * `:year_cycle` is the cycle the years run in, as the sexagenary cycle
    of 60, or `nil`.

  * `:years_in_cycle` is the number of years after which the calendar's
    days and weekdays repeat, where they do, for sampling.

  * `:location` is the place an astronomical calendar is reckoned at, a
    function of the ISO day number.

  * `:month_lengths` are the lengths a month can have, by month, where the
    calendar states them rather than having them sampled.

  * `:parsing_calendar` is the calendar a written date is parsed in, the
    calendar itself by default.

  ### Overriding

  The six primitive `Calendar` callbacks, `leap_year?/1`,
  `months_in_year/1`, `days_in_month/2`, `valid_date?/3`, `year_of_era/3`
  and `day_of_era/3`, and the kernel, `leap_month/1`, `written_date/3`,
  `date_from_written_date/3`, `shift/6` and `diff/3`, may be defined by
  the calendar. Every other generated function is a delegation defined
  before the calendar's own code, so a later definition of one is
  unreachable: the compiler warns that its clause can never match, and
  the generated answer stands.

  """

  # The options `use Calendrical.Calendar` reads; any other is refused.
  @known_options [
    :epoch,
    :cldr_calendar_type,
    :era_calendar_type,
    :months_in_year,
    :weeks,
    :year_zero?,
    :year_cycle,
    :years_in_cycle,
    :location,
    :month_lengths,
    :parsing_calendar
  ]

  defmacro __using__(options \\ []) do
    refuse_unknown_options!(options)
    epoch = Keyword.fetch!(options, :epoch)

    {date, []} = Code.eval_quoted(epoch)
    epoch_iso_days = Calendrical.date_to_iso_days(date)
    {first_day_of_week, min_days_in_first_week} = weeks!(options)
    parsing_calendar = Keyword.get(options, :parsing_calendar)
    year_zero? = Keyword.get(options, :year_zero?, true)
    year_cycle = Keyword.get(options, :year_cycle)
    location = Keyword.get(options, :location)
    month_lengths = Keyword.get(options, :month_lengths)
    years_in_cycle = Keyword.get(options, :years_in_cycle)

    cldr_calendar_type = Keyword.get(options, :cldr_calendar_type, :gregorian)
    era_calendar_type = Keyword.get(options, :era_calendar_type, cldr_calendar_type)
    {months_in_ordinary_year, months_in_leap_year} = months_in_year!(options)

    # Each section is an independent quoted block; evaluating the
    # list injects them in order, which matters — the attributes in
    # the prelude are read by later sections, and the overridable
    # declarations must follow every definition. Imports are lexical
    # to their own quote block, so a section that uses an imported
    # macro imports it itself.
    [
      prelude(
        epoch_iso_days,
        first_day_of_week,
        months_in_ordinary_year,
        months_in_leap_year
      ),
      facts(
        min_days_in_first_week: min_days_in_first_week,
        parsing_calendar: parsing_calendar,
        cldr_calendar_type: cldr_calendar_type,
        era_calendar_type: era_calendar_type,
        year_zero?: year_zero?,
        year_cycle: year_cycle,
        location: location,
        month_lengths: month_lengths,
        years_in_cycle: years_in_cycle
      ),
      identity_and_validity(),
      shift_functions(),
      count_functions(),
      range_functions(),
      arithmetic_functions(),
      overridable_declarations()
    ]
  end

  defp refuse_unknown_options!(options) do
    case Keyword.keys(options) -- @known_options do
      [] ->
        :ok

      unknown ->
        raise Calendrical.UnknownOptionError,
          maker: Calendrical.Calendar,
          options: unknown,
          known_options: @known_options
    end
  end

  # The week rule as the day weeks begin on, or `:first` for weeks counted
  # from the year's first day, and the fewest days of the year in week 1.
  defp weeks!(options) do
    case Keyword.get(options, :weeks, []) do
      :from_first_day ->
        {:first, 1}

      rule when is_list(rule) ->
        {Keyword.get(rule, :first_day, 1), Keyword.get(rule, :min_days_in_first_week, 1)}

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :weeks,
          value: other,
          maker: Calendrical.Calendar
    end
  end

  # The months of an ordinary and of a leap year.
  defp months_in_year!(options) do
    case Keyword.get(options, :months_in_year, 12) do
      months when is_integer(months) and months > 0 ->
        {months, months}

      {fewest, most} when is_integer(fewest) and is_integer(most) and most >= fewest ->
        {fewest, most}

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :months_in_year,
          value: other,
          maker: Calendrical.Calendar
    end
  end

  defp prelude(
         epoch_iso_days,
         first_day_of_week,
         months_in_ordinary_year,
         months_in_leap_year
       ) do
    quote location: :keep do
      import Localize.Macros

      @behaviour Calendar
      @behaviour Calendrical
      use Calendrical.Compiler.StandardCallbacks
      @before_compile Calendrical.Compiler.DateCheck

      @epoch unquote(epoch_iso_days)
      @first_day_of_week unquote(first_day_of_week)

      @months_in_ordinary_year unquote(months_in_ordinary_year)
      @months_in_leap_year unquote(months_in_leap_year)
    end
  end

  # The facts a calendar states in its options beyond what the prelude
  # keeps, and the `info/0` that gathers every fact into one struct. The
  # week rule is the day the calendar's weeks begin on, or
  # `:first_day_of_year` where they are counted from the year's first day.
  defp facts(facts) do
    min_days_in_first_week = Keyword.fetch!(facts, :min_days_in_first_week)
    parsing_calendar = Keyword.fetch!(facts, :parsing_calendar)
    cldr_calendar_type = Keyword.fetch!(facts, :cldr_calendar_type)
    era_calendar_type = Keyword.fetch!(facts, :era_calendar_type)
    year_zero? = Keyword.fetch!(facts, :year_zero?)
    year_cycle = Keyword.fetch!(facts, :year_cycle)
    location = Keyword.fetch!(facts, :location)
    month_lengths = Keyword.fetch!(facts, :month_lengths)
    years_in_cycle = Keyword.fetch!(facts, :years_in_cycle)

    quote location: :keep do
      @info Calendrical.Info.new(__MODULE__,
              cldr_calendar_type: unquote(cldr_calendar_type),
              era_calendar_type: unquote(era_calendar_type),
              epoch: @epoch,
              year_zero?: unquote(year_zero?),
              structure: :months,
              months_in_year: {@months_in_ordinary_year, @months_in_leap_year},
              weeks:
                Calendrical.Info.week_rule(@first_day_of_week, unquote(min_days_in_first_week)),
              parsing_calendar: unquote(parsing_calendar),
              years_in_cycle: unquote(years_in_cycle),
              year_cycle: unquote(year_cycle),
              location: unquote(location),
              month_lengths: unquote(month_lengths)
            )

      @doc """
      Returns the static facts about this calendar, as
      `t:Calendrical.Info.t/0`.

      ### Returns

      * A `t:Calendrical.Info.t/0` describing this calendar.

      ### Examples

          iex> #{inspect(__MODULE__)}.info().calendar
          #{inspect(__MODULE__)}

      """
      @impl Calendrical
      def info, do: @info
    end
  end

  defp identity_and_validity do
    quote location: :keep do
      @doc """
      Returns the epoch of this calendar: the ISO day number of
      its first day.

      ### Returns

      * The epoch as an integer number of days since the ISO epoch.

      ### Examples

          iex> #{inspect(__MODULE__)}.epoch() |> is_integer()
          true

      """
      def epoch do
        @epoch
      end

      @doc """
      Determines if the `date` given is valid according to
      this calendar.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * `true` if the year, month and day are a date of this calendar,
        otherwise `false`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.valid_date?(date.year, date.month, date.day)
          true
          iex> #{inspect(__MODULE__)}.valid_date?(date.year, date.month, 0)
          false

      """
      @impl true
      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) and month >= 1 and
                 day >= 1 do
        month <= months_in_year(year) && day <= days_in_month(year, month)
      end

      def valid_date?(_year, _month, _day), do: false
    end
  end

  defp shift_functions do
    quote location: :keep do
    end
  end

  defp count_functions do
    quote location: :keep do
      @doc """
      Returns the number of months in a
      given `year`.

      ### Arguments

      * `year` is the year in this calendar.

      ### Returns

      * The number of months in the year, as a positive integer, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where `year` is `nil`, or

      * `{:error, %Calendrical.InvalidDateError{}}` where `year` is no integer.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.months_in_year(date.year) >= date.month
          true

      """
      # A calendar with as many months in every year answers without asking
      # whether the year is leap, which a calendar reckoned from the sky
      # answers by counting the year's days.
      if @months_in_ordinary_year == @months_in_leap_year do
        @impl true
        def months_in_year(_year), do: @months_in_ordinary_year
      else
        @impl true
        def months_in_year(year) do
          if leap_year?(year), do: @months_in_leap_year, else: @months_in_ordinary_year
        end
      end

      @doc """
      Returns how many days there are in the given year
      and month.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      ### Returns

      * The number of days in the month, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
        does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        month is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.days_in_month(date.year, date.month) >= date.day
          true

      """
      @spec days_in_month(Calendar.year(), Calendar.month()) ::
              Calendar.day() | {:error, Exception.t()}
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
    end
  end

  defp range_functions do
    quote location: :keep do
    end
  end

  defp arithmetic_functions do
    quote location: :keep do
      @doc """
      Returns the date a number of years, quarters, months, weeks or days
      on from a date of this calendar, by position, with the traditional
      month kept across years and a day the resulting month lacks clamped
      to its last day unless `clamp: false` (`Calendrical.Shift.shift/7`).

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      * `increment` is the number of units, which may be negative.

      * `options` is a keyword list of options.

      ### Options

      * `:clamp` is whether a day the resulting month lacks becomes its
        last day. The default is `true`.

      ### Returns

      * `{year, month, day}` of this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` where `year`, `month` and
        `day` are no date of this calendar, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where a field is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.shift(date.year, date.month, date.day, :days, 0)
          {date.year, date.month, date.day}

      """
      @impl true
      def shift(year, month, day, date_part, increment, options \\ []) do
        Calendrical.Shift.shift(__MODULE__, year, month, day, date_part, increment, options)
      end
    end
  end

  defp overridable_declarations do
    quote location: :keep do
      defoverridable info: 0
      defoverridable valid_date?: 3

      defoverridable months_in_year: 1
      defoverridable days_in_month: 2

      defoverridable shift: 5
      defoverridable shift: 6

      defoverridable epoch: 0
    end
  end
end
