defmodule Calendrical.Calendar.Shifted do
  @moduledoc """
  Makes a calendar whose year begins elsewhere in a base calendar's year:
  a fiscal year beginning in July, a year counted from Lady Day as the
  Old Style did, or any year begun on a day of a calendar of months.

  A date of the calendar is a counted month and a day of it, so dates
  order by time. A year that begins on the first day of a base month has
  the base's months counted from that month; a year that begins within a
  base month has a short month 1, from the day it begins on to the end of
  that base month, and a short last month, the days of that base month
  before it, so a year begun on 25 March has thirteen months, of which
  month 1 is 25 to 31 March and month 13 is 1 to 24 March.

  The kernel falls out of the base: a date is the base's date relabelled,
  a month's length is the base month's, and `shift/6` is the base's
  arithmetic on the base date, relabelled.

  ### Options

  * `:base` is the calendar of months the year is cut from, a calendar
    with as many months in every year. The default is
    `Calendrical.Gregorian`.

  * `:year_begins` is `{month, day}` of the base calendar the year begins
    on. The default is `{1, 1}`.

  * `:year_number` is the base year the year takes its number from:
    `:beginning`, the one it begins in, `:ending`, the one it ends in, or
    `:majority`, the one most of it falls in, which is the default.

  * `:written_year` is the year a date is written with: `:base`, the base
    calendar's year the day falls in, as a fiscal date is written with the
    Gregorian year, which is the default, or `:label`, the calendar's own
    year, as the Old Style wrote its dates.

  * `:weeks` is the rule the calendar's own weeks follow: a keyword list
    with `:first_day`, 1 for Monday to 7 for Sunday, and
    `:min_days_in_first_week`, or `:from_first_day` for weeks counted from
    the first day of the year. The default is Monday and 1.

  * `:cldr_calendar_type`, `:era_calendar_type` and `:years_in_cycle` are
    facts for `c:Calendrical.info/0`, each defaulting to the base
    calendar's, and `:parsing_calendar` names the calendar a written date
    is parsed in, the calendar itself by default.

  ### Examples

      defmodule FiscalFromJuly do
        use Calendrical.Calendar.Shifted, year_begins: {7, 1}, year_number: :ending
      end

      defmodule LadyDay do
        use Calendrical.Calendar.Shifted,
          base: Calendrical.Julian,
          year_begins: {3, 25},
          year_number: :beginning,
          written_year: :label
      end

  """

  @known_options [
    :base,
    :year_begins,
    :year_number,
    :written_year,
    :weeks,
    :cldr_calendar_type,
    :era_calendar_type,
    :parsing_calendar,
    :years_in_cycle
  ]

  @year_numbers [:beginning, :ending, :majority]
  @written_years [:base, :label]

  defmacro __using__(options) do
    [facts(options), naming(), kernel(), months(), written_and_shift(), shift()]
  end

  # The options as attributes, `info/0` and `base/0`.
  defp facts(options) do
    quote bind_quoted: [options: options, known_options: @known_options] do
      Calendrical.Calendar.Shifted.refuse_unknown_options!(options, known_options)

      @behaviour Calendar
      @behaviour Calendrical
      use Calendrical.Compiler.StandardCallbacks, impl: false
      @before_compile Calendrical.Compiler.DateCheck

      @base Keyword.get(options, :base, Calendrical.Gregorian)
      @base_info @base.info()
      @base_months Calendrical.Calendar.Shifted.base_months!(@base, @base_info)
      @year_zero? @base_info.year_zero?

      {year_begins_month, year_begins_day} =
        Calendrical.Calendar.Shifted.year_begins!(options, @base_months)

      @year_begins_month year_begins_month
      @year_begins_day year_begins_day
      @split_months year_begins_day > 1
      @counted_months if(@split_months, do: @base_months + 1, else: @base_months)
      @year_number Calendrical.Calendar.Shifted.year_number!(
                     options,
                     @year_begins_month,
                     @year_begins_day,
                     @base_months
                   )
      @written_year Calendrical.Calendar.Shifted.written_year!(options)
      @weeks Calendrical.Calendar.Shifted.weeks!(options)
      @cldr_calendar_type Keyword.get(options, :cldr_calendar_type, @base_info.cldr_calendar_type)
      @era_calendar_type Keyword.get(options, :era_calendar_type, @base_info.era_calendar_type)
      @parsing_calendar Keyword.get(options, :parsing_calendar, __MODULE__)
      @years_in_cycle Keyword.get(options, :years_in_cycle, @base_info.years_in_cycle)

      @doc """
      Returns the static facts about this calendar, as
      `t:Calendrical.Info.t/0`.

      ### Returns

      * A `t:Calendrical.Info.t/0` describing this calendar.

      ### Examples

          iex> #{inspect(__MODULE__)}.info().calendar
          #{inspect(__MODULE__)}

      """
      def info do
        Calendrical.Info.new(__MODULE__,
          cldr_calendar_type: @cldr_calendar_type,
          era_calendar_type: @era_calendar_type,
          structure: :months,
          months_in_year: {@counted_months, @counted_months},
          years_in_cycle: @years_in_cycle,
          parsing_calendar: @parsing_calendar,
          epoch: date_to_iso_days(1, 1, 1),
          year_zero?: @year_zero?,
          weeks: @weeks
        )
      end

      @doc """
      Returns the base calendar this calendar's years are cut from.

      ### Returns

      * The base calendar module.

      ### Examples

          iex> #{inspect(__MODULE__)}.base() |> Code.ensure_loaded?()
          true

      """
      def base, do: @base
    end
  end

  # A counted month and its base month, and a year and its base years.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp naming do
    quote location: :keep do
      # Whether a base month and day come before the day the year begins
      # on in their base year.
      defguardp year_rollover(month, day)
                when month < @year_begins_month or
                       (month == @year_begins_month and day < @year_begins_day)

      # A counted month's base month, the counted month and day of a base
      # month and day, and the base day a date's day field names. In a
      # split year counted month 1 begins on the day the year begins on, so
      # its days are offset; every other month's days are the base month's.
      if @split_months do
        defp counted_to_named(1), do: @year_begins_month
        defp counted_to_named(@counted_months), do: @year_begins_month

        defp counted_to_named(counted) do
          Localize.Utils.Math.amod(@year_begins_month + counted - 1, @base_months)
        end

        defp named_to_counted(month, day)
             when month == @year_begins_month and day >= @year_begins_day do
          {1, day - @year_begins_day + 1}
        end

        defp named_to_counted(month, day) when month == @year_begins_month do
          {@counted_months, day}
        end

        defp named_to_counted(month, day) do
          {Localize.Utils.Math.amod(month - @year_begins_month + 1, @base_months), day}
        end

        defp named_day(1, day), do: day + @year_begins_day - 1
        defp named_day(_counted, day), do: day
      else
        defp counted_to_named(counted) do
          Localize.Utils.Math.amod(@year_begins_month + counted - 1, @base_months)
        end

        defp named_to_counted(month, day) do
          {Localize.Utils.Math.amod(month - @year_begins_month + 1, @base_months), day}
        end

        defp named_day(_counted, day), do: day
      end

      # The base month of a partial date's counted month, where it is given.
      defp partial_named_month(month) when is_integer(month), do: counted_to_named(month)
      defp partial_named_month(_month), do: nil

      # The base year a base month and day fall in under this calendar's
      # year, from where the day stands against the day the year begins
      # on: in a year numbered by the base year it begins in, the days
      # before that day are in the base year after; in a year numbered by
      # the base year it ends in, the days from that day on are in the base
      # year before.
      if @year_number == :beginning do
        defp base_year(year, month, day) when year_rollover(month, day), do: next_year(year)
        defp base_year(year, _month, _day), do: year

        defp year_of_base(year, month, day) when year_rollover(month, day),
          do: previous_year(year)

        defp year_of_base(year, _month, _day), do: year
      else
        defp base_year(year, month, day) when year_rollover(month, day), do: year
        defp base_year(year, _month, _day), do: previous_year(year)
        defp year_of_base(year, month, day) when year_rollover(month, day), do: year
        defp year_of_base(year, _month, _day), do: next_year(year)
      end

      # The years run on without a 0 where the base has none.
      if @year_zero? do
        defp next_year(year), do: year + 1
        defp previous_year(year), do: year - 1
      else
        defp next_year(-1), do: 1
        defp next_year(year), do: year + 1
        defp previous_year(1), do: -1
        defp previous_year(year), do: year - 1
      end
    end
  end

  # The kernel: the spine, the shape and the validity of a date.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp kernel do
    quote location: :keep do
      @doc """
      Returns the base calendar's date of a date of this calendar.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{year, month, day}` in the base calendar. For a partial date,
        a field that depends on a missing one is `nil`: the base month
        needs the month, the base day the month and the day, and the
        base year all three.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.base_date(today.year, today.month, today.day)
          iex> #{inspect(__MODULE__)}.date_from_base_date(year, month, day)
          {today.year, today.month, today.day}

          iex> #{inspect(__MODULE__)}.base_date(2024, nil, nil)
          {nil, nil, nil}

      """
      def base_date(_year, month, day) when not (is_integer(month) and is_integer(day)),
        do: {nil, partial_named_month(month), nil}

      def base_date(year, month, day) when not is_integer(year),
        do: {nil, counted_to_named(month), named_day(month, day)}

      def base_date(year, month, day) do
        named_month = counted_to_named(month)
        named_day = named_day(month, day)
        {base_year(year, named_month, named_day), named_month, named_day}
      end

      @doc """
      Returns the date of this calendar that names a date of the base
      calendar.

      ### Arguments

      * `year`, `month` and `day` are a date of the base calendar.

      ### Returns

      * `{year, month, day}` in this calendar. For a partial date, whose
        counted month, day and year each depend on the base month and
        day, every field is `nil` unless all three are given.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.base_date(today.year, today.month, today.day)
          iex> #{inspect(__MODULE__)}.date_from_base_date(year, month, day)
          {today.year, today.month, today.day}

          iex> #{inspect(__MODULE__)}.date_from_base_date(2024, nil, 1)
          {nil, nil, nil}

      """
      def date_from_base_date(year, month, day)
          when not (is_integer(year) and is_integer(month) and is_integer(day)),
          do: {nil, nil, nil}

      def date_from_base_date(year, month, day) do
        {counted_month, counted_day} = named_to_counted(month, day)
        {year_of_base(year, month, day), counted_month, counted_day}
      end

      @doc """
      Returns the ISO day number of a date of this calendar.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * The ISO day number.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_to_iso_days(today.year, today.month, today.day) ==
          ...>   Date.to_gregorian_days(~D[2024-06-01])
          true

      """
      def date_to_iso_days(year, month, day) do
        {base_year, base_month, base_day} = base_date(year, month, day)
        @base.date_to_iso_days(base_year, base_month, base_day)
      end

      @doc """
      Returns the date of this calendar of an ISO day number.

      ### Arguments

      * `iso_days` is an ISO day number.

      ### Returns

      * `{year, month, day}` in this calendar.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_from_iso_days(Date.to_gregorian_days(~D[2024-06-01]))
          {today.year, today.month, today.day}

      """
      def date_from_iso_days(iso_days) do
        {year, month, day} = @base.date_from_iso_days(iso_days)
        date_from_base_date(year, month, day)
      end

      @doc """
      Returns the number of months in a year: the base calendar's, and one
      more where the year begins within a base month.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The number of months.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.months_in_year(today.year) in [12, 13]
          true

      """
      def months_in_year(_year), do: @counted_months
    end
  end

  # The days of the months, leap years and the valid dates.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp months do
    quote location: :keep do
      @doc """
      Returns the number of days in a month of a year: the base month's,
      and a part of it for the two months a year begun within a base month
      splits it into.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      ### Returns

      * The number of days, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
        does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        month is `nil`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.days_in_month(today.year, today.month) >= today.day
          true

      """
      @spec days_in_month(Calendar.year(), Calendar.month()) ::
              Calendar.day() | {:error, Exception.t()}
      if @split_months do
        def days_in_month(year, 1) when is_integer(year) do
          {base_year, base_month, _day} = base_date(year, 1, 1)
          @base.days_in_month(base_year, base_month) - @year_begins_day + 1
        end

        def days_in_month(year, @counted_months) when is_integer(year), do: @year_begins_day - 1
      end

      # A month the year does not have, and a field that is not an integer,
      # are answered before this by `Calendrical.Compiler.DateCheck`.
      def days_in_month(year, month) do
        {base_year, base_month, _day} = base_date(year, month, 1)
        @base.days_in_month(base_year, base_month)
      end

      @doc """
      Returns whether a year is a leap year: whether it holds 366 days.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * `true` if the year holds 366 days, otherwise `false`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.leap_year?(today.year) in [true, false]
          true

      """
      def leap_year?(year) when is_integer(year) do
        Calendrical.Period.days_in_year(__MODULE__, year) == 366
      end

      @doc """
      Returns whether a year, month and day are a date of this calendar.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `true` if they are a date of this calendar, otherwise `false`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.valid_date?(today.year, today.month, today.day)
          true
          iex> #{inspect(__MODULE__)}.valid_date?(today.year, today.month, 0)
          false

      """
      if @year_zero? do
        def valid_date?(year, month, day)
            when is_integer(year) and is_integer(month) and is_integer(day) and
                   month in 1..@counted_months//1 and day >= 1 do
          day <= days_in_month(year, month)
        end
      else
        def valid_date?(year, month, day)
            when is_integer(year) and is_integer(month) and is_integer(day) and
                   month in 1..@counted_months//1 and day >= 1 and year != 0 do
          day <= days_in_month(year, month)
        end
      end

      def valid_date?(_year, _month, _day), do: false
    end
  end

  # The written date and the day of era.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp written_and_shift do
    quote location: :keep do
      @doc """
      Returns the figures a date is written with: the base month and day
      that name it, with the base year or this calendar's own year as
      `:written_year` says.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{year, month, day}` as the date is written.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
          {:ok, {today.year, today.month, today.day}}

      """
      if @written_year == :base do
        def written_date(year, month, day), do: base_date(year, month, day)

        @doc """
        Returns the date of this calendar that written figures name: the
        inverse of `written_date/3`.

        ### Arguments

        * `year`, `month` and `day` are the written figures of a date.

        ### Returns

        * `{:ok, {year, month, day}}` in this calendar.

        * `{:error, :invalid_date}` for figures that name no date, an atom
          as `c:Calendrical.date_from_written_date/3` answers.

        ### Examples

            iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
            iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
            iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
            {:ok, {today.year, today.month, today.day}}

        """
        def date_from_written_date(year, month, day)
            when is_integer(year) and is_integer(month) and is_integer(day) and
                   month in 1..@base_months//1 do
          if @base.valid_date?(year, month, day),
            do: {:ok, date_from_iso_days(@base.date_to_iso_days(year, month, day))},
            # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
            # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
            else: {:error, :invalid_date}
        end
      else
        # The written year is the counted year itself, so it is known
        # whatever the month and day; the base month and day follow
        # base_date/3.
        def written_date(year, month, day) do
          {_base_year, base_month, base_day} = base_date(year, month, day)
          {year, base_month, base_day}
        end

        @doc """
        Returns the date of this calendar that written figures name: the
        inverse of `written_date/3`.

        ### Arguments

        * `year`, `month` and `day` are the written figures of a date.

        ### Returns

        * `{:ok, {year, month, day}}` in this calendar.

        * `{:error, :invalid_date}` for figures that name no date, an atom
          as `c:Calendrical.date_from_written_date/3` answers.

        ### Examples

            iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
            iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
            iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
            {:ok, {today.year, today.month, today.day}}

        """
        def date_from_written_date(year, month, day)
            when is_integer(year) and is_integer(month) and is_integer(day) and
                   month in 1..@base_months//1 do
          {counted_month, counted_day} = named_to_counted(month, day)

          if valid_date?(year, counted_month, counted_day),
            do: {:ok, {year, counted_month, counted_day}},
            # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
            # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
            else: {:error, :invalid_date}
        end
      end

      # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
      # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
      def date_from_written_date(_year, _month, _day), do: {:error, :invalid_date}

      @doc """
      Returns the day of era of a date: counted from the first day of this
      calendar's year 1, and back from the day before it for the era
      before.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{day, era}`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {day, 1} = #{inspect(__MODULE__)}.day_of_era(today.year, today.month, today.day)
          iex> day > 0
          true

      """
      def day_of_era(year, month, day) do
        {_year, era} = year_of_era(year, month, day)
        days = date_to_iso_days(year, month, day)
        epoch = date_to_iso_days(1, 1, 1)
        if era == 1, do: {days - epoch + 1, era}, else: {epoch - days, era}
      end
    end
  end

  # Shifting a date by years, months, weeks or days.
  defp shift do
    quote location: :keep do
      @doc """
      Returns the date a number of years, quarters, months, weeks or days
      from a date: the base calendar's arithmetic on the base date,
      relabelled, for years, quarters and months, and a count of days
      otherwise.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      * `increment` is the number of units, which may be negative.

      * `options` is a keyword list of options.

      ### Options

      * `:clamp` keeps a day the month reached lacks as its last day, as
        the base calendar's `shift/6` does. The default is `true`.

      ### Returns

      * `{year, month, day}` of this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` where `year`, `month` and
        `day` are no date of this calendar, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where a field is `nil`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.shift(today.year, today.month, today.day, :days, 0)
          {today.year, today.month, today.day}

      """
      def shift(year, month, day, date_part, increment, options \\ [])

      def shift(year, month, day, date_part, increment, options)
          when date_part in [:years, :quarters, :months] do
        {base_year, base_month, base_day} = base_date(year, month, day)

        {new_year, new_month, new_day} =
          @base.shift(base_year, base_month, base_day, date_part, increment, options)

        date_from_base_date(new_year, new_month, new_day)
      end

      def shift(year, month, day, :weeks, weeks, options) do
        shift(year, month, day, :days, weeks * 7, options)
      end

      def shift(year, month, day, :days, days, _options) do
        date_from_iso_days(date_to_iso_days(year, month, day) + days)
      end
    end
  end

  @doc false
  def refuse_unknown_options!(options, known_options) do
    case Keyword.keys(options) -- known_options do
      [] ->
        :ok

      unknown ->
        raise Calendrical.UnknownOptionError,
          maker: Calendrical.Calendar.Shifted,
          options: unknown,
          known_options: known_options
    end
  end

  @doc false
  # The months of the base's year, which must be the same in every year.
  def base_months!(base, info) do
    case info.months_in_year do
      {months, months} ->
        months

      {_fewest, _most} ->
        raise Calendrical.InvalidOptionValueError,
          option: :base,
          value: base,
          maker: Calendrical.Calendar.Shifted
    end
  end

  @doc false
  def year_begins!(options, base_months) do
    case Keyword.get(options, :year_begins, {1, 1}) do
      {month, day} = year_begins
      when is_integer(month) and month in 1..base_months//1 and is_integer(day) and day >= 1 ->
        year_begins

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :year_begins,
          value: other,
          maker: Calendrical.Calendar.Shifted
    end
  end

  @doc false
  # The base year a year is numbered by: `:majority` is the year it begins
  # in where it begins in the first half of the base year, and the year it
  # ends in otherwise; a year that begins on the base's first day begins
  # and ends in one base year.
  def year_number!(options, month, day, base_months) do
    case {Keyword.get(options, :year_number, :majority), month, day} do
      {number, 1, 1} when number in @year_numbers ->
        :beginning

      {:majority, month, _day} when month <= div(base_months, 2) ->
        :beginning

      {:majority, _month, _day} ->
        :ending

      {number, _month, _day} when number in [:beginning, :ending] ->
        number

      {other, _month, _day} ->
        raise Calendrical.InvalidOptionValueError,
          option: :year_number,
          value: other,
          maker: Calendrical.Calendar.Shifted
    end
  end

  @doc false
  def written_year!(options) do
    case Keyword.get(options, :written_year, :base) do
      written when written in @written_years ->
        written

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :written_year,
          value: other,
          maker: Calendrical.Calendar.Shifted
    end
  end

  @doc false
  def weeks!(options) do
    case Keyword.get(options, :weeks, []) do
      :from_first_day ->
        Calendrical.Info.week_rule(:first, 1)

      rule when is_list(rule) ->
        Calendrical.Info.week_rule(
          Keyword.get(rule, :first_day, 1),
          Keyword.get(rule, :min_days_in_first_week, 1)
        )

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :weeks,
          value: other,
          maker: Calendrical.Calendar.Shifted
    end
  end
end
