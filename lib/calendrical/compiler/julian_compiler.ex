defmodule Calendrical.Julian.Compiler do
  @moduledoc false

  # See https://stevemorse.org/jcal/julian.html

  # A year-start variant's dates carry counted months: month 1 begins on
  # the new-year day and the months run in the order of time, so a date's
  # fields order as its days do and Elixir's `Date.compare/2`,
  # `Date.beginning_of_month/1` and `days_in_month/2` hold. A variant
  # whose new-year day is the first of a Julian month has twelve counted
  # months, each a whole Julian month; one whose new-year day falls
  # within a Julian month has thirteen, the split month's later days as a
  # short month 1 and its earlier days as a short month 13. The Julian
  # month and day a date names are answered by `month_of_year/3` and
  # `cardinal_day/3`, which name the months and days for localization.

  defmacro __before_compile__(env) do
    options =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Macro.escape()

    quote bind_quoted: [options: options] do
      @behaviour Calendar
      @behaviour Calendrical

      {start_month, start_day} = Keyword.get(options, :new_year_starting_month_and_day, {1, 1})

      @new_year_starting_month start_month
      @new_year_starting_day start_day

      # The Julian year a year takes its number from: the one it begins in,
      # the one it ends in, or the one most of it falls in, which is the
      # first for a year that begins in January to June, as a month or week
      # calendar's `:year` has it. A year that begins on 1 January begins
      # and ends in the same Julian year.
      year_numbering =
        case {Keyword.get(options, :year, :beginning), start_month, start_day} do
          {year, 1, 1} when year in [:beginning, :ending, :majority] ->
            :beginning

          {:majority, month, _day} when month <= 6 ->
            :beginning

          {:majority, _month, _day} ->
            :ending

          {year, _month, _day} when year in [:beginning, :ending] ->
            year

          {year, _month, _day} ->
            raise ArgumentError,
                  ":year must be either :beginning, :ending or :majority. Found #{inspect(year)}."
        end

      # A year that begins within a Julian month splits it: the month's
      # later days begin the year as a short month 1 and its earlier days
      # end it as a short month 13.
      split_months = start_day > 1

      @quarters_in_year 4
      @julian_months_in_year Calendrical.Julian.months_in_year(0)
      @counted_months if(split_months, do: 13, else: 12)

      @doc """
      Whether a Julian month and day come before the new-year day in
      their Julian year.

      """
      defguard year_rollover(month, day)
               when month < @new_year_starting_month or
                      (month == @new_year_starting_month and day < @new_year_starting_day)

      # A counted month's Julian month, the counted month and day of a
      # Julian month and day, and the Julian day a date's day field
      # names. In a split variant counted month 1 begins at the new-year
      # day, so its days are offset; every other month's days are the
      # Julian month's own.
      if split_months do
        defp counted_to_named(1), do: @new_year_starting_month
        defp counted_to_named(@counted_months), do: @new_year_starting_month

        defp counted_to_named(counted) do
          Localize.Utils.Math.amod(@new_year_starting_month + counted - 1, @julian_months_in_year)
        end

        defp named_to_counted(month, day)
             when month == @new_year_starting_month and day >= @new_year_starting_day do
          {1, day - @new_year_starting_day + 1}
        end

        defp named_to_counted(month, day) when month == @new_year_starting_month do
          {@counted_months, day}
        end

        defp named_to_counted(month, day) do
          {Localize.Utils.Math.amod(month - @new_year_starting_month + 1, @julian_months_in_year),
           day}
        end

        defp named_day(1, day), do: day + @new_year_starting_day - 1
        defp named_day(_counted, day), do: day
      else
        defp counted_to_named(counted) do
          Localize.Utils.Math.amod(@new_year_starting_month + counted - 1, @julian_months_in_year)
        end

        defp named_to_counted(month, day) do
          {Localize.Utils.Math.amod(month - @new_year_starting_month + 1, @julian_months_in_year),
           day}
        end

        defp named_day(_counted, day), do: day
      end

      # The Julian year a Julian month and day fall in under this
      # calendar's label year, from where the day stands against the
      # new-year day. In a year numbered by the Julian year it begins in,
      # the days before the new-year day are in the Julian year after; in
      # a year numbered by the Julian year it ends in, the days from the
      # new-year day on are in the Julian year before.
      if year_numbering == :beginning do
        defp julian_year(year, month, day) when year_rollover(month, day), do: next_year(year)
        defp julian_year(year, _month, _day), do: year

        defp label_year_of_julian(year, month, day) when year_rollover(month, day) do
          previous_year(year)
        end

        defp label_year_of_julian(year, _month, _day), do: year
      else
        defp julian_year(year, month, day) when year_rollover(month, day), do: year
        defp julian_year(year, _month, _day), do: previous_year(year)

        defp label_year_of_julian(year, month, day) when year_rollover(month, day), do: year
        defp label_year_of_julian(year, _month, _day), do: next_year(year)
      end

      @doc """
      Returns the Julian calendar's date of a date of this calendar.

      ### Arguments

      * `year`, `month` and `day` are a date of this calendar.

      ### Returns

      * `{julian_year, julian_month, julian_day}` in `Calendrical.Julian`.

      """
      def julian_date(year, month, day) do
        named_month = counted_to_named(month)
        named_day = named_day(month, day)
        {julian_year(year, named_month, named_day), named_month, named_day}
      end

      @doc """
      Returns the date of this calendar that names a Julian date.

      ### Arguments

      * `year`, `month` and `day` are a date of `Calendrical.Julian`.

      ### Returns

      * `{year, month, day}` in this calendar.

      """
      def date_from_julian_date(year, month, day) do
        label_year = label_year_of_julian(year, month, day)
        {counted_month, counted_day} = named_to_counted(month, day)
        {label_year, counted_month, counted_day}
      end

      def date_to_iso_days(year, month, day) do
        {julian_year, julian_month, julian_day} = julian_date(year, month, day)
        Calendrical.Julian.date_to_iso_days(julian_year, julian_month, julian_day)
      end

      def date_from_iso_days(iso_days) do
        {year, month, day} = Calendrical.Julian.date_from_iso_days(iso_days)
        date_from_julian_date(year, month, day)
      end

      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        {date_to_iso_days(year, month, day),
         time_to_day_fraction(hour, minute, second, microsecond)}
      end

      def naive_datetime_from_iso_days({iso_days, day_fraction}) do
        {year, month, day} = date_from_iso_days(iso_days)
        {hour, minute, second, microsecond} = time_from_day_fraction(day_fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      def shift_date(year, month, day, duration) do
        Calendrical.shift_date(year, month, day, __MODULE__, duration)
      end

      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :years, years, options) do
        new_year = skip_year_zero(year + years, year)
        {new_year, month, coerce_day(options, day, new_year, month)}
      end

      def plus(year, month, day, :quarters, quarters, options) do
        plus(year, month, day, :months, quarters * 3, options)
      end

      # Months count on through the years, every year holding the same
      # number, with no year 0: the months index collapses the gap and
      # the new year expands it again.
      def plus(year, month, day, :months, months, options) do
        months_index = collapse_year(year) * @counted_months + (month - 1) + months
        new_year = expand_year(Integer.floor_div(months_index, @counted_months))
        new_month = Integer.mod(months_index, @counted_months) + 1
        {new_year, new_month, coerce_day(options, day, new_year, new_month)}
      end

      def plus(year, month, day, :weeks, weeks, options) do
        plus(year, month, day, :days, weeks * Calendrical.Julian.days_in_week(), options)
      end

      def plus(year, month, day, :days, days, _options) do
        iso_days = date_to_iso_days(year, month, day) + days
        date_from_iso_days(iso_days)
      end

      defp coerce_day(options, day, year, month) do
        if Keyword.get(options, :coerce, false) do
          min(day, days_in_month(year, month))
        else
          day
        end
      end

      def diff(from, to, date_part) do
        Calendrical.Base.Common.diff(__MODULE__, from, to, date_part)
      end

      def days_in_year(year) do
        last_iso_day_of_year(year) - first_iso_day_of_year(year) + 1
      end

      def dates_in_gregorian_year(gregorian_year, month, day) do
        Calendrical.dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)
      end

      # A split variant's month 13 is the new-year month's days before
      # the new-year day, its month 1 the days from it on, and every
      # other month a whole Julian month, so a month's length without a
      # year is ambiguous only where the Julian month's is.
      if split_months do
        def days_in_month(1) do
          case Calendrical.Julian.days_in_month(@new_year_starting_month) do
            days when is_integer(days) ->
              days - @new_year_starting_day + 1

            {:ambiguous, first..last//1} ->
              {:ambiguous,
               (first - @new_year_starting_day + 1)..(last - @new_year_starting_day + 1)//1}
          end
        end

        def days_in_month(@counted_months), do: @new_year_starting_day - 1

        def days_in_month(counted_month) when counted_month in 2..12 do
          Calendrical.Julian.days_in_month(counted_to_named(counted_month))
        end

        def days_in_month(_counted_month), do: {:error, :undefined}

        def days_in_month(year, 1) do
          {julian_year, named_month, _named_day} = julian_date(year, 1, 1)

          Calendrical.Julian.days_in_month(julian_year, named_month) -
            @new_year_starting_day + 1
        end

        def days_in_month(_year, @counted_months), do: @new_year_starting_day - 1

        def days_in_month(year, counted_month) when counted_month in 2..12 do
          {julian_year, named_month, _named_day} = julian_date(year, counted_month, 1)
          Calendrical.Julian.days_in_month(julian_year, named_month)
        end
      else
        def days_in_month(counted_month) when counted_month in 1..@counted_months do
          Calendrical.Julian.days_in_month(counted_to_named(counted_month))
        end

        def days_in_month(_counted_month), do: {:error, :undefined}

        def days_in_month(year, counted_month) when counted_month in 1..@counted_months do
          {julian_year, named_month, _named_day} = julian_date(year, counted_month, 1)
          Calendrical.Julian.days_in_month(julian_year, named_month)
        end
      end

      # A month the year does not have holds no days, as a composite
      # answers for a month a transition leaves empty.
      def days_in_month(_year, _counted_month), do: 0

      defdelegate days_in_week(), to: Calendrical.Julian

      def year(year) do
        with {:ok, first_date} <- Date.new(year, 1, 1, __MODULE__) do
          Date.range(first_date, date_at(last_iso_day_of_year(year)))
        end
      end

      # Quarters, quadrimesters and semesters are runs of counted months,
      # the last period running to the year's last month.
      def quarter(year, quarter) do
        Calendrical.Period.date_range(__MODULE__, year, quarter, 3)
      end

      def quadrimester(year, quadrimester) do
        Calendrical.Period.date_range(__MODULE__, year, quadrimester, 4)
      end

      def semester(year, semester) do
        Calendrical.Period.date_range(__MODULE__, year, semester, 6)
      end

      def month(year, month) when year == 0 or month not in 1..@counted_months do
        {:error, :invalid_date}
      end

      def month(year, month) do
        with {:ok, first} <- Date.new(year, month, 1, __MODULE__),
             {:ok, last} <- Date.new(year, month, days_in_month(year, month), __MODULE__) do
          Date.range(first, last)
        end
      end

      defp date_at(iso_days) do
        {year, month, day} = date_from_iso_days(iso_days)
        %Date{year: year, month: month, day: day, calendar: __MODULE__}
      end

      def quarter_of_year(year, month, _day) do
        Calendrical.Period.period_number_of_month(__MODULE__, year, month, 3)
      end

      # A date's month field counts the year's months from its start; the
      # Julian month names it.
      def month_of_year(_year, month, _day) do
        counted_to_named(month)
      end

      # The Julian month names the CLDR month whichever month the year
      # begins in.
      def cardinal_month(month) do
        counted_to_named(month)
      end

      # The Julian day of the month names the day: in a split variant's
      # month 1 the day field counts from the new-year day.
      def cardinal_day(_year, month, day) do
        named_day(month, day)
      end

      def day_of_year(year, month, day) do
        first_day = first_iso_day_of_year(year)
        this_day = date_to_iso_days(year, month, day)
        this_day - first_day + 1
      end

      def calendar_year(year, _month, _day) do
        year
      end

      # The extended year numbers the label years without the gap at year 0:
      # 1 BC is 0 and 2 BC -1, as the plain Julian calendar counts them.
      def extended_year(year, _month, _day) when year < 0 do
        year + 1
      end

      def extended_year(year, _month, _day) do
        year
      end

      def cyclic_year(year, month, day) do
        calendar_year(year, month, day)
      end

      # Per TR35 the related year is the Gregorian year in which the calendar
      # year begins, the same for every date of the year (as for
      # `Calendrical.Julian`).
      def related_gregorian_year(year, _month, _day) do
        {year, _month, _day} =
          Calendrical.Gregorian.date_from_iso_days(first_iso_day_of_year(year))

        year
      end

      def first_day_of_year(year) do
        {year, 1, 1}
      end

      def last_day_of_year(year) do
        last_day = first_iso_day_of_year(next_year(year)) - 1
        date_from_iso_days(last_day)
      end

      def first_iso_day_of_year(year) do
        date_to_iso_days(year, 1, 1)
      end

      def last_iso_day_of_year(year) do
        {year, month, day} = last_day_of_year(year)
        date_to_iso_days(year, month, day)
      end

      def leap_year?(year) do
        last_iso_day_of_year(year) - first_iso_day_of_year(year) + 1 == 366
      end

      # A label year is the Julian year it begins in, or the one it ends in,
      # and the Julian calendar has no year 0: 1 BC (-1) is followed by AD 1.
      defp next_year(-1), do: 1
      defp next_year(year), do: year + 1

      defp previous_year(1), do: -1
      defp previous_year(year), do: year - 1

      defp skip_year_zero(new_year, original_year)
           when new_year >= 0 and original_year < 0 do
        new_year + 1
      end

      defp skip_year_zero(new_year, original_year)
           when new_year <= 0 and original_year > 0 do
        new_year - 1
      end

      defp skip_year_zero(new_year, _original_year) do
        new_year
      end

      # The label years without the gap at 0, for month arithmetic: label
      # year 1 is 1 and label year -1 is 0.
      defp collapse_year(year) when year < 0, do: year + 1
      defp collapse_year(year), do: year

      defp expand_year(year) when year < 1, do: year - 1
      defp expand_year(year), do: year

      # No year is numbered 0, whichever Julian year a label year 0 would
      # stand for.
      def valid_date?(year, month, day)
          when is_integer(year) and year != 0 and is_integer(month) and
                 month in 1..@counted_months and is_integer(day) and day >= 1 do
        day <= days_in_month(year, month)
      end

      def valid_date?(_year, _month, _day), do: false

      def day_of_week(year, month, day, starts_on) do
        {julian_year, julian_month, julian_day} = julian_date(year, month, day)
        Calendrical.Julian.day_of_week(julian_year, julian_month, julian_day, starts_on)
      end

      # Day 1 of the common era is the first day of label year 1, and
      # the era before it counts back from the day before.
      def day_of_era(year, month, day) do
        {_year, era} = year_of_era(year, month, day)
        days = date_to_iso_days(year, month, day)
        epoch = first_iso_day_of_year(1)

        if era == 1 do
          {days - epoch + 1, era}
        else
          {epoch - days, era}
        end
      end

      def iso_week_of_year(year, month, day) do
        {julian_year, julian_month, julian_day} = julian_date(year, month, day)
        Calendrical.Julian.iso_week_of_year(julian_year, julian_month, julian_day)
      end

      # Weeks are the calendar's own, counted over its own year from its
      # first day, as every calendar without compiled weeks counts them.
      def week_of_year(year, month, day) do
        Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
      end

      # The weeks of a counted month, cut at the month's own boundaries.
      def week_of_month(year, month, day) do
        Calendrical.Base.Common.week_of_month(__MODULE__, year, month, day)
      end

      # The label year names the era: in March25, the days of Julian
      # 1-24 March AD 1 carry the label 1 BC and belong to that era, and
      # in Dec25, those of Julian 25-31 December 1 BC carry the label AD 1.
      def year_of_era(year, _month, _day) do
        Calendrical.Julian.year_of_era(year)
      end

      def week(year, week), do: Calendrical.Base.Common.week(__MODULE__, year, week)
      def weeks_in_year(year), do: Calendrical.Base.Common.weeks_in_year(__MODULE__, year)

      def months_in_year(_year), do: @counted_months
      def months_in_year, do: @counted_months
      def periods_in_year(_year), do: @counted_months

      # Parsing must validate against this variant's own year labeling
      # (a leap day can be valid here in a different label year than in
      # plain Julian), so parse with this module as the calendar.
      def parse_date(string) do
        Calendrical.Parse.parse_date(string, __MODULE__)
      end

      defdelegate date_to_string(year, month, day), to: Calendrical.Julian
      defdelegate cldr_calendar_type(), to: Calendrical.Julian
      defdelegate calendar_from_cldr_calendar_type(calendar_type), to: Calendrical
      defdelegate era_calendar_type(), to: Calendrical.Julian
      defdelegate calendar_base(), to: Calendrical.Julian

      @doc """
      Returns the calendar module a date written for this calendar
      is parsed in: the calendar itself.

      """
      def parsing_calendar, do: __MODULE__

      defdelegate valid_time?(hour, minute, second, millisecond), to: Calendrical.Julian
      defdelegate time_to_string(hour, minute, second, millisecond), to: Calendrical.Julian

      defdelegate time_to_day_fraction(hour, minute, second, millisecond),
        to: Calendrical.Julian

      defdelegate time_from_day_fraction(fraction), to: Calendrical.Julian

      defdelegate shift_time(hour, minute, second, millisecond, duration),
        to: Calendrical.Julian

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

      defdelegate iso_days_to_end_of_day(iso_days), to: Calendrical.Julian
      defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendrical.Julian

      def parse_utc_datetime(string) do
        Calendrical.Parse.parse_utc_datetime(string, __MODULE__)
      end

      defdelegate parse_time(string), to: Calendrical.Julian

      def parse_naive_datetime(string) do
        Calendrical.Parse.parse_naive_datetime(string, __MODULE__)
      end

      defdelegate day_rollover_relative_to_midnight_utc, to: Calendrical.Julian

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
                  to: Calendrical.Julian

      # The /12 target is not a Calendar callback and is hidden on
      # Calendrical.Julian; hide the delegate too so ExDoc does not
      # emit a reference-to-hidden-function warning per variant.
      @doc false
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
                    std_offset,
                    format
                  ),
                  to: Calendrical.Julian

      defdelegate naive_datetime_to_string(year, month, day, hour, minute, second, microsecond),
        to: Calendrical.Julian
    end
  end
end
