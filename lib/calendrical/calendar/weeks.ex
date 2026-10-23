defmodule Calendrical.Calendar.Weeks do
  @moduledoc """
  Makes a calendar of whole weeks: a year of 52 or 53 weeks that begins
  or ends on a weekday near a day of the Gregorian year, cut into twelve
  months of four or five weeks by a pattern, as retail and other fiscal
  calendars count them and as the ISO week year does.

  A date of the calendar is a month of the pattern and a day of it, so a
  month of four weeks has days 1 to 28 and one of five weeks days 1 to
  35; a long year's last month holds the fifty-third week.

  ### Options

  * `:pattern` is the weeks in the three months of a quarter, one of
    `[4, 4, 5]`, `[4, 5, 4]` and `[5, 4, 4]`. The default is `[4, 5, 4]`.

  * `:year_begins` is the rule the year begins by:
    `{weekday, :on_or_before, {month, day}}`, the weekday on or before a
    day of a Gregorian month, the day being 1 to 7, so the year's first
    week holds that day, or `{weekday, :nearest, {month, 4}}`, the weekday
    nearest the fourth, which is the same rule. The ISO week year begins
    `{:monday, :on_or_before, {1, 4}}`. The default is `{:monday, :on_or_before, {1, 1}}`.

  * `:year_ends` is the rule the year ends by, instead of `:year_begins`:
    `{weekday, :on_or_after, {month, day}}`, the weekday on or after a day
    within the last seven days of a Gregorian month, so the year's last
    week holds that day, or `{weekday, :nearest, {month, last_day}}`, the
    weekday nearest the month's last day. The NRF 4-5-4 year ends
    `{:saturday, :nearest, {1, 31}}`.

  * `:year_number` is the Gregorian year the year takes its number from:
    `:beginning`, the one it begins in, `:ending`, the one it ends in, or
    `:majority`, the one most of it falls in, which is the default.

  * `:cldr_calendar_type` is the CLDR calendar whose data names the
    months and days, `:gregorian` by default.

  ### Examples

      defmodule Retail do
        use Calendrical.Calendar.Weeks,
          pattern: [4, 5, 4],
          year_ends: {:saturday, :nearest, {1, 31}}
      end

      defmodule WeekYear do
        use Calendrical.Calendar.Weeks, year_begins: {:monday, :on_or_before, {1, 4}}
      end

  The calendar is its options: the first day of a year is found from the
  rule, a month is the weeks of the pattern before it, and every other
  answer follows from those two.

  """

  @known_options [:pattern, :year_begins, :year_ends, :year_number, :cldr_calendar_type]
  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
  @patterns [[4, 4, 5], [4, 5, 4], [5, 4, 4]]
  @year_numbers [:beginning, :ending, :majority]
  @cldr_calendar_types [:gregorian, :japanese]
  @days_in_week 7
  @weeks_in_quarter 13
  @months_in_quarter 3
  @months_in_year 12
  @weeks_in_long_year 53
  @days_in_long_year 371
  @month_lengths %{
    1 => 31,
    2 => 28,
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31
  }

  defmacro __using__(options) do
    [facts(options), structure(), months(), kernel(), written(), shift()]
  end

  # The options as attributes and `info/0`.
  defp facts(options) do
    quote bind_quoted: [options: options, known_options: @known_options] do
      Calendrical.Calendar.Weeks.refuse_unknown_options!(options, known_options)

      @behaviour Calendar
      @behaviour Calendrical
      use Calendrical.Compiler.StandardCallbacks, impl: false
      @before_compile Calendrical.Compiler.DateCheck

      # The rule the year begins or ends by: the weekday, 1 (Monday) to 7,
      # on or before a day of a Gregorian month for a year that begins, and
      # on or after one for a year that ends.
      {anchor, weekday, month, day} = Calendrical.Calendar.Weeks.anchor!(options)
      @anchor anchor
      @anchor_weekday weekday
      @anchor_month month
      @anchor_day day
      @pattern Calendrical.Calendar.Weeks.pattern!(options)
      @year_number Calendrical.Calendar.Weeks.year_number!(options)
      @cldr_calendar_type Calendrical.Calendar.Weeks.cldr_calendar_type!(options)

      # The Gregorian year the rule's day falls in, counted from the
      # calendar year: the year the calendar year begins in for a year
      # that begins by its rule, and the one it ends in otherwise.
      @anchor_year_offset Calendrical.Calendar.Weeks.anchor_year_offset(
                            @anchor,
                            @anchor_month,
                            @year_number
                          )

      # The weeks begin on the rule's weekday, or the day after it where
      # the year ends on the weekday; week 1 holds the rule's day, so the
      # fewest of its days in the year are the days from the month's first
      # day, or to its last.
      @week_first_day Calendrical.Calendar.Weeks.week_first_day(@anchor, @anchor_weekday)
      @min_days_in_first_week Calendrical.Calendar.Weeks.min_days_in_first_week(
                                @anchor,
                                @anchor_month,
                                @anchor_day
                              )

      # The month that names each month of the pattern, the weeks of the
      # year before each month, the days of each month in a short year, and
      # the month each week of the year falls in, worked out once from the
      # pattern.
      @naming_months Calendrical.Calendar.Weeks.naming_months(@anchor_month)
      @weeks_before_month Calendrical.Calendar.Weeks.weeks_before_month(@pattern)
      @days_in_pattern_month Calendrical.Calendar.Weeks.days_in_pattern_month(@pattern)
      @month_of_week Calendrical.Calendar.Weeks.month_of_week(@pattern)

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
          cldr_calendar_type: :generic,
          era_calendar_type: @cldr_calendar_type,
          structure: :weeks,
          months_in_year: {12, 12},
          years_in_cycle: 400,
          parsing_calendar: Calendar.ISO,
          epoch: date_to_iso_days(1, 1, 1),
          weeks: Calendrical.Info.week_rule(@week_first_day, @min_days_in_first_week)
        )
      end
    end
  end

  # The years and the months: where a year begins and ends, whether it is
  # long, and the days of its months.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp structure do
    quote location: :keep do
      @doc """
      Returns the number of `iso_days` that is the first day of a year of
      this calendar: the rule's weekday on or before its day for a year
      that begins by the rule, and the day after the year before ends for
      one that ends by it.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The ISO day number of the day.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> first = #{inspect(__MODULE__)}.first_gregorian_day_of_year(today.year)
          iex> last = #{inspect(__MODULE__)}.last_gregorian_day_of_year(today.year)
          iex> rem(last - first + 1, 7)
          0

      """
      if @anchor == :begins do
        def first_gregorian_day_of_year(year) when is_integer(year) do
          anchor =
            Calendrical.Calendar.Weeks.anchor_day(
              year + @anchor_year_offset,
              @anchor_month,
              @anchor_day
            )

          anchor -
            Integer.mod(Calendrical.Calendar.Weeks.day_of_week(anchor) - @anchor_weekday, 7)
        end

        @doc """
        Returns the number of `iso_days` that is the last day of a year of
        this calendar: the day before the next year begins.

        ### Arguments

        * `year` is a year of this calendar.

        ### Returns

        * The ISO day number of the day.

        ### Examples

            iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
            iex> last = #{inspect(__MODULE__)}.last_gregorian_day_of_year(today.year)
            iex> #{inspect(__MODULE__)}.first_gregorian_day_of_year(today.year + 1) - last
            1

        """
        def last_gregorian_day_of_year(year) when is_integer(year) do
          first_gregorian_day_of_year(year + 1) - 1
        end
      else
        def first_gregorian_day_of_year(year) when is_integer(year) do
          last_gregorian_day_of_year(year - 1) + 1
        end

        @doc """
        Returns the number of `iso_days` that is the last day of a year of
        this calendar: the rule's weekday on or after its day.

        ### Arguments

        * `year` is a year of this calendar.

        ### Returns

        * The ISO day number of the day.

        ### Examples

            iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
            iex> last = #{inspect(__MODULE__)}.last_gregorian_day_of_year(today.year)
            iex> #{inspect(__MODULE__)}.first_gregorian_day_of_year(today.year + 1) - last
            1

        """
        def last_gregorian_day_of_year(year) when is_integer(year) do
          anchor =
            Calendrical.Calendar.Weeks.anchor_day(
              year + @anchor_year_offset,
              @anchor_month,
              @anchor_day
            )

          anchor +
            Integer.mod(@anchor_weekday - Calendrical.Calendar.Weeks.day_of_week(anchor), 7)
        end
      end
    end
  end

  # Whether a year is long, the days of its months and the valid dates.
  # The generated definitions branch on the options once, at compile time.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp months do
    quote location: :keep do
      @doc """
      Returns whether a year is a long year, one of fifty-three weeks.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * `true` if the year has fifty-three weeks, otherwise `false`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> first = #{inspect(__MODULE__)}.first_gregorian_day_of_year(today.year)
          iex> last = #{inspect(__MODULE__)}.last_gregorian_day_of_year(today.year)
          iex> #{inspect(__MODULE__)}.leap_year?(today.year) == (last - first + 1 == 371)
          true

      """
      def leap_year?(year) when is_integer(year) do
        last_gregorian_day_of_year(year) - first_gregorian_day_of_year(year) + 1 ==
          unquote(@days_in_long_year)
      end

      @doc false
      defdelegate months_in_year(year), to: Calendar.ISO

      @doc """
      Returns how many days there are in the given month of a year: the
      days of its weeks, as the pattern gives them, and one week more in
      the last month of a long year.

      ### Arguments

      * `year` is any year.

      * `month` is a month of that year, from 1 to 12.

      ### Returns

      * The number of days, a multiple of seven, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
        does not have, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        month is `nil`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> rem(#{inspect(__MODULE__)}.days_in_month(today.year, today.month), 7)
          0

      """
      @spec days_in_month(year :: Calendrical.year(), month :: Calendrical.month()) ::
              days ::
              Calendar.day()
              | {:error, Exception.t()}
      def days_in_month(year, unquote(@months_in_year)) when is_integer(year) do
        long_week = if leap_year?(year), do: unquote(@days_in_week), else: 0
        elem(@days_in_pattern_month, unquote(@months_in_year) - 1) + long_week
      end

      # A month the year does not have, and a field that is not an integer,
      # are answered before this by `Calendrical.Compiler.DateCheck`.
      def days_in_month(_year, month), do: elem(@days_in_pattern_month, month - 1)

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
          iex> #{inspect(__MODULE__)}.valid_date?(today.year, 13, 1)
          false

      """
      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) and
                 month in 1..unquote(@months_in_year)//1 and day >= 1 do
        day <= days_in_month(year, month)
      end

      def valid_date?(_year, _month, _day), do: false
    end
  end

  # The spine: a date to its ISO day number and back.
  defp kernel do
    quote location: :keep do
      @doc """
      Returns the number of days since the calendar epoch for a date: the
      year's first day, the weeks of the months before the month, and the
      day.

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
      def date_to_iso_days(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        first_gregorian_day_of_year(year) +
          elem(@weeks_before_month, month - 1) * unquote(@days_in_week) + day - 1
      end

      @doc """
      Returns `{year, month, day}` calculated from the number of
      `iso_days`: the year whose days hold it, and the month of the
      pattern its week of the year falls in.

      ### Arguments

      * `iso_days` is an ISO day number.

      ### Returns

      * `{year, month, day}` in this calendar.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_from_iso_days(Date.to_gregorian_days(~D[2024-06-01]))
          {today.year, today.month, today.day}

      """
      def date_from_iso_days(iso_days) when is_integer(iso_days) do
        {gregorian_year, _month, _day} = Calendar.ISO.date_from_iso_days(iso_days)
        year = year_holding(iso_days, gregorian_year)
        day_of_year = iso_days - first_gregorian_day_of_year(year)
        month = elem(@month_of_week, div(day_of_year, unquote(@days_in_week)))
        days_before = elem(@weeks_before_month, month - 1) * unquote(@days_in_week)
        {year, month, day_of_year - days_before + 1}
      end

      # The year of this calendar a day falls in: the Gregorian year's, or
      # the one before or after it, since a year begins within a year of
      # its own number.
      defp year_holding(iso_days, year) do
        cond do
          iso_days < first_gregorian_day_of_year(year) -> year - 1
          iso_days > last_gregorian_day_of_year(year) -> year + 1
          true -> year
        end
      end
    end
  end

  # The written date and the day of era: the clauses of three functions,
  # each simple on its own.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp written do
    quote location: :keep do
      @doc """
      Returns the figures a date is written with: its year, the Gregorian
      month that names its month, and its day of the month.

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
      def written_date(year, month, day)
          when is_integer(month) and month in 1..unquote(@months_in_year)//1 do
        {year, elem(@naming_months, month - 1), day}
      end

      def written_date(year, month, day), do: {year, month, day}

      @doc """
      Returns the date of this calendar that written figures name: the
      month of the year the named month is, with the year and the day as
      written, where they are a date.

      ### Arguments

      * `year`, `named_month` and `day` are the written figures of a date.

      ### Returns

      * `{:ok, {year, month, day}}` in this calendar.

      * `{:error, :invalid_date}` for figures that name no date, an atom as
        `c:Calendrical.date_from_written_date/3` answers.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
          {:ok, {today.year, today.month, today.day}}

      """
      def date_from_written_date(year, named_month, day)
          when is_integer(named_month) and named_month in 1..unquote(@months_in_year)//1 do
        month = Calendrical.Calendar.Weeks.month_named(named_month, @anchor_month)
        Calendrical.Base.Written.own_date(__MODULE__, year, month, day)
      end

      # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
      # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
      def date_from_written_date(_year, _named_month, _day), do: {:error, :invalid_date}

      @doc """
      Returns the day of era of a date: counted from the first day of
      year 1, and back from the last day of year 0 for the era before.

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
      def day_of_era(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        iso_days = date_to_iso_days(year, month, day)

        if year >= 1,
          do: {iso_days - first_gregorian_day_of_year(1) + 1, 1},
          else: {last_gregorian_day_of_year(0) - iso_days + 1, 0}
      end
    end
  end

  # The arithmetic: the clauses of `shift/6`, one a date part, each simple
  # on its own.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp shift do
    quote location: :keep do
      @doc """
      Returns the date a number of years, quarters, months, weeks or days
      from a date. A year on, a day keeps its week of the year and its day
      of the week; a month on, its day of the month; a week or a day on is
      a count of days.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      * `increment` is the number of units, which may be negative.

      * `options` is a keyword list of options.

      ### Options

      * `:clamp` brings a fifty-third week into the last week of a year
        of fifty-two, and a day the month reached lacks to its last day.
        The default is `true`.

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

      def shift(year, month, day, :years, years, options) do
        week = elem(@weeks_before_month, month - 1) + div(day - 1, unquote(@days_in_week)) + 1
        weekday = rem(day - 1, unquote(@days_in_week)) + 1
        new_year = year + years

        week =
          if clamp?(options) and week == unquote(@weeks_in_long_year) and not leap_year?(new_year),
            do: week - 1,
            else: week

        new_month = elem(@month_of_week, week - 1)
        weeks_before = elem(@weeks_before_month, new_month - 1)
        {new_year, new_month, (week - 1 - weeks_before) * unquote(@days_in_week) + weekday}
      end

      def shift(year, month, day, :quarters, quarters, options),
        do: shift(year, month, day, :months, quarters * unquote(@months_in_quarter), options)

      def shift(year, month, day, :months, months, options) do
        months_from_zero = year * unquote(@months_in_year) + month - 1 + months
        new_year = Integer.floor_div(months_from_zero, unquote(@months_in_year))
        new_month = Integer.mod(months_from_zero, unquote(@months_in_year)) + 1

        days =
          if clamp?(options),
            do: min(day, days_in_month(new_year, new_month)) - 1,
            else: day - 1

        date_from_iso_days(date_to_iso_days(new_year, new_month, 1) + days)
      end

      def shift(year, month, day, :weeks, weeks, _options) do
        date_from_iso_days(date_to_iso_days(year, month, day) + weeks * unquote(@days_in_week))
      end

      def shift(year, month, day, :days, days, _options) do
        date_from_iso_days(date_to_iso_days(year, month, day) + days)
      end

      defp clamp?(options), do: Keyword.get(options, :clamp, Calendrical.default_clamp())
    end
  end

  @doc false
  def refuse_unknown_options!(options, known_options) do
    case Keyword.keys(options) -- known_options do
      [] ->
        :ok

      unknown ->
        raise Calendrical.UnknownOptionError,
          maker: Calendrical.Calendar.Weeks,
          options: unknown,
          known_options: known_options
    end
  end

  @doc false
  # The rule the year begins or ends by, as `{:begins | :ends, weekday,
  # month, day}`: the weekday 1 (Monday) to 7, on or before the day of the
  # Gregorian month for a year that begins, on or after it for one that ends.
  def anchor!(options) do
    case {Keyword.fetch(options, :year_begins), Keyword.fetch(options, :year_ends)} do
      {{:ok, _begins}, {:ok, _ends}} ->
        raise Calendrical.InvalidOptionValueError,
          option: [:year_begins, :year_ends],
          value: nil,
          maker: Calendrical.Calendar.Weeks

      {:error, {:ok, ends}} ->
        year_ends!(ends)

      {{:ok, begins}, :error} ->
        year_begins!(begins)

      {:error, :error} ->
        year_begins!({:monday, :on_or_before, {1, 1}})
    end
  end

  defp year_begins!({weekday, :nearest, {month, 4}}),
    do: year_begins!({weekday, :on_or_before, {month, 4}})

  defp year_begins!({weekday, :on_or_before, {month, day}})
       when weekday in @weekdays and is_integer(month) and month in 1..@months_in_year//1 and
              is_integer(day) and day in 1..@days_in_week//1 do
    {:begins, weekday_number(weekday), month, day}
  end

  defp year_begins!(other) do
    raise Calendrical.InvalidOptionValueError,
      option: :year_begins,
      value: other,
      maker: Calendrical.Calendar.Weeks
  end

  defp year_ends!({weekday, :nearest, {month, day}} = rule) when is_integer(month) do
    if Map.get(@month_lengths, month) == day,
      do: year_ends!({weekday, :on_or_after, {month, day - 3}}),
      else: raise(year_ends_error(rule))
  end

  defp year_ends!({weekday, :on_or_after, {month, day}} = rule)
       when weekday in @weekdays and is_integer(month) and month in 1..@months_in_year//1 and
              is_integer(day) do
    length = Map.fetch!(@month_lengths, month)

    if day >= length - @days_in_week + 1 and day <= length,
      do: {:ends, weekday_number(weekday), month, day},
      else: raise(year_ends_error(rule))
  end

  defp year_ends!(other), do: raise(year_ends_error(other))

  defp year_ends_error(rule) do
    Calendrical.InvalidOptionValueError.exception(
      option: :year_ends,
      value: rule,
      maker: Calendrical.Calendar.Weeks
    )
  end

  defp weekday_number(weekday), do: Enum.find_index(@weekdays, &(&1 == weekday)) + 1

  @doc false
  def pattern!(options) do
    case Keyword.get(options, :pattern, [4, 5, 4]) do
      pattern when pattern in @patterns ->
        pattern

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :pattern,
          value: other,
          maker: Calendrical.Calendar.Weeks
    end
  end

  @doc false
  def year_number!(options) do
    case Keyword.get(options, :year_number, :majority) do
      year_number when year_number in @year_numbers ->
        year_number

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :year_number,
          value: other,
          maker: Calendrical.Calendar.Weeks
    end
  end

  @doc false
  def cldr_calendar_type!(options) do
    case Keyword.get(options, :cldr_calendar_type, :gregorian) do
      type when type in @cldr_calendar_types ->
        type

      other ->
        raise Calendrical.InvalidOptionValueError,
          option: :cldr_calendar_type,
          value: other,
          maker: Calendrical.Calendar.Weeks
    end
  end

  @doc false
  # The Gregorian year the rule's day falls in, as an offset from the
  # calendar year: a year that begins in January, or ends in December, has
  # its number; one numbered by `:majority` takes the Gregorian year that
  # holds seven or more of its months.
  def anchor_year_offset(:begins, 1, _year_number), do: 0
  def anchor_year_offset(:ends, @months_in_year, _year_number), do: 0
  def anchor_year_offset(:begins, month, :majority), do: if(month <= 6, do: 0, else: -1)
  def anchor_year_offset(:ends, month, :majority), do: if(month > 6, do: 0, else: 1)
  def anchor_year_offset(:begins, _month, :beginning), do: 0
  def anchor_year_offset(:begins, _month, :ending), do: -1
  def anchor_year_offset(:ends, _month, :beginning), do: 1
  def anchor_year_offset(:ends, _month, :ending), do: 0

  @doc false
  # The weeks begin on the rule's weekday, or the day after it where the
  # year ends on the weekday.
  def week_first_day(:begins, weekday), do: weekday
  def week_first_day(:ends, weekday), do: Integer.mod(weekday, @days_in_week) + 1

  @doc false
  # The fewest days of week 1 that are the year's: the rule's day holds
  # them, from the month's first day where the year begins, and to its
  # last where it ends.
  def min_days_in_first_week(:begins, _month, day), do: day

  def min_days_in_first_week(:ends, month, day),
    do: Map.fetch!(@month_lengths, month) - day + 1

  @doc false
  # The Gregorian month that names each month of the pattern: a year
  # begun or ended in another month than January numbers its months from
  # there.
  def naming_months(anchor_month) do
    List.to_tuple(
      for month <- 1..@months_in_year do
        Localize.Utils.Math.amod(month + anchor_month - 1, @months_in_year)
      end
    )
  end

  @doc false
  # The month of the pattern a Gregorian month names: the inverse of
  # `naming_months/1`.
  def month_named(named_month, anchor_month),
    do: Localize.Utils.Math.amod(named_month - anchor_month + 1, @months_in_year)

  @doc false
  # The weeks of the year before each month: the quarters before it and
  # the months of the pattern before it in its own quarter.
  def weeks_before_month(pattern) do
    List.to_tuple(
      for month <- 1..@months_in_year do
        quarters_before = div(month - 1, @months_in_quarter)
        months_before = rem(month - 1, @months_in_quarter)
        quarters_before * @weeks_in_quarter + Enum.sum(Enum.take(pattern, months_before))
      end
    )
  end

  @doc false
  # The days of each month of the pattern in a short year.
  def days_in_pattern_month(pattern) do
    List.to_tuple(
      for month <- 1..@months_in_year do
        Enum.at(pattern, rem(month - 1, @months_in_quarter)) * @days_in_week
      end
    )
  end

  @doc false
  # The month each week of the year falls in, the fifty-third in the last.
  def month_of_week(pattern) do
    weeks_before = weeks_before_month(pattern)

    List.to_tuple(
      for week <- 1..@weeks_in_long_year do
        Enum.find(@months_in_year..1//-1, fn month -> week > elem(weeks_before, month - 1) end)
      end
    )
  end

  @doc false
  def anchor_day(gregorian_year, month, day),
    do: Calendar.ISO.date_to_iso_days(gregorian_year, month, day)

  @doc false
  # The day of the week of an ISO day number, 1 (Monday) to 7: day 0 is a
  # Saturday.
  def day_of_week(iso_days), do: Integer.mod(iso_days + 5, @days_in_week) + 1
end
