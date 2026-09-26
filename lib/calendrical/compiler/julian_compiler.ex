defmodule Calendrical.Julian.Compiler do
  @moduledoc false

  # See https://stevemorse.org/jcal/julian.html

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

      @quarters_in_year 4
      @months_in_quarter 3
      @months_in_year Calendrical.Julian.months_in_year(0)

      @doc """
      These dates belong to the prior Julian year

      """
      defguard year_rollover(month, day)
               when month < @new_year_starting_month or
                      (month == @new_year_starting_month and day < @new_year_starting_day)

      # Adjust the year to be a Jan 1st starting year and carry
      # on

      def date_to_iso_days(year, month, day) when year_rollover(month, day) do
        Calendrical.Julian.date_to_iso_days(next_year(year), month, day)
      end

      def date_to_iso_days(year, month, day) do
        Calendrical.Julian.date_to_iso_days(year, month, day)
      end

      # Adjust the year to be this calendars starting year
      def date_from_iso_days(iso_days) do
        {year, month, day} = Calendrical.Julian.date_from_iso_days(iso_days)
        date_from_julian_date(year, month, day)
      end

      def date_from_julian_date(year, month, day) when year_rollover(month, day) do
        {previous_year(year), month, day}
      end

      def date_from_julian_date(year, month, day) do
        {year, month, day}
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

      # Year and month arithmetic is the plain Julian calendar's on the Julian
      # date, relabelled: the label year of the result depends on where the
      # shifted date falls against the new-year day, not on the label year the
      # date started in.
      def plus(year, month, day, date_part, increment, options)
          when date_part in [:years, :quarters, :months] do
        {julian_year, month, day} =
          Calendrical.Julian.plus(
            julian_year(year, month, day),
            month,
            day,
            date_part,
            increment,
            options
          )

        date_from_julian_date(julian_year, month, day)
      end

      def plus(year, month, day, :weeks, weeks, options) do
        plus(year, month, day, :days, weeks * Calendrical.Julian.days_in_week(), options)
      end

      def plus(year, month, day, :days, days, _options) do
        iso_days = date_to_iso_days(year, month, day) + days
        date_from_iso_days(iso_days)
      end

      def days_in_year(year) do
        last_iso_day_of_year(year) - first_iso_day_of_year(year) + 1
      end

      def dates_in_gregorian_year(gregorian_year, month, day) do
        Calendrical.dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)
      end

      # A date's month is its Julian month, so the days of `month` in label
      # `year` are those of that Julian month in the Julian year the label
      # year's `month` falls in. The new-year month holds days 1..(start - 1)
      # of the next Julian year and the rest of this one: its days run to this
      # Julian year's month end.
      defdelegate days_in_month(month), to: Calendrical.Julian

      def days_in_month(year, month) do
        Calendrical.Julian.days_in_month(julian_year(year, month, @new_year_starting_day), month)
      end

      defdelegate days_in_week(), to: Calendrical.Julian

      def year(year) do
        {year, month, day} = first_day_of_year(year)

        with {:ok, first_date} <- Date.new(year, month, day, __MODULE__) do
          Date.range(first_date, date_at(last_iso_day_of_year(year)))
        end
      end

      # Quarters, quadrimesters and semesters count months from the start of
      # the year, as `month/2` and `quarter_of_year/3` do.
      def quarter(year, quarter) do
        Calendrical.Period.date_range(__MODULE__, year, quarter, 3)
      end

      def quadrimester(year, quadrimester) do
        Calendrical.Period.date_range(__MODULE__, year, quadrimester, 4)
      end

      def semester(year, semester) do
        Calendrical.Period.date_range(__MODULE__, year, semester, 6)
      end

      # `month/2` counts months from the start of the year: month 1 runs from
      # the new-year day to the end of its Julian month, and month 12 is long,
      # running on to the day before the next new year.
      def month(_year, ordinal_month) when ordinal_month not in 1..@months_in_year do
        {:error, :invalid_date}
      end

      def month(year, ordinal_month) do
        first_iso_days = ordinal_month_start(year, ordinal_month)

        last_iso_days =
          if ordinal_month == @months_in_year,
            do: first_iso_day_of_year(next_year(year)) - 1,
            else: ordinal_month_start(year, ordinal_month + 1) - 1

        Date.range(date_at(first_iso_days), date_at(last_iso_days))
      end

      defp date_at(iso_days) do
        {year, month, day} = date_from_iso_days(iso_days)
        %Date{year: year, month: month, day: day, calendar: __MODULE__}
      end

      defp ordinal_month_start(year, 1), do: first_iso_day_of_year(year)

      defp ordinal_month_start(year, ordinal_month) do
        month =
          Localize.Utils.Math.amod(ordinal_month + @new_year_starting_month - 1, @months_in_year)

        date_to_iso_days(year, month, 1)
      end

      # Quarters count from the start of the year, as `month/2` counts months.
      def quarter_of_year(_year, month, day) do
        ceil(position_in_year(month, day) / (@months_in_year / @quarters_in_year))
      end

      # A date's month is its Julian month, which names it; `month/2` counts
      # the months from the start of the year instead.
      def month_of_year(_year, month, _day) do
        month
      end

      # The month's place in the year, the new-year month's days before the
      # new-year day ending the year as a long month 12.
      defp position_in_year(month, day)
           when month == @new_year_starting_month and day < @new_year_starting_day do
        @months_in_year
      end

      defp position_in_year(month, _day) do
        Localize.Utils.Math.amod(month - @new_year_starting_month + 1, @months_in_year)
      end

      def day_of_year(year, month, day) do
        first_day = first_iso_day_of_year(year)
        this_day = date_to_iso_days(year, month, day)
        this_day - first_day + 1
      end

      def calendar_year(year, _month, _day) do
        year
      end

      def extended_year(year, month, day) do
        calendar_year(year, month, day)
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
        month = @new_year_starting_month
        day = @new_year_starting_day
        {year, month, day}
      end

      def last_day_of_year(year) do
        last_day = first_iso_day_of_year(next_year(year)) - 1
        date_from_iso_days(last_day)
      end

      def first_iso_day_of_year(year) do
        {year, month, day} = first_day_of_year(year)
        date_to_iso_days(year, month, day)
      end

      def last_iso_day_of_year(year) do
        {year, month, day} = last_day_of_year(year)
        date_to_iso_days(year, month, day)
      end

      def leap_year?(year) do
        last_iso_day_of_year(year) - first_iso_day_of_year(year) + 1 == 366
      end

      # Dates before the variant's new-year day carry the prior label
      # year: their plain-Julian year is `year + 1`. Functions that
      # delegate a `{year, month, day}` to `Calendrical.Julian` must
      # normalize the label year first, otherwise a rollover date such
      # as {2023, 2, 29} in the March1 variant reaches plain Julian as
      # the (invalid) date 2023-02-29 instead of 2024-02-29.
      defp julian_year(year, month, day) when year_rollover(month, day), do: next_year(year)
      defp julian_year(year, _month, _day), do: year

      # A label year is the Julian year its new-year day falls in, and the
      # Julian calendar has no year 0: 1 BC (-1) is followed by AD 1.
      defp next_year(-1), do: 1
      defp next_year(year), do: year + 1

      defp previous_year(1), do: -1
      defp previous_year(year), do: year - 1

      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        Calendrical.Julian.valid_date?(julian_year(year, month, day), month, day)
      end

      def valid_date?(_year, _month, _day), do: false

      def day_of_week(year, month, day, starts_on) do
        Calendrical.Julian.day_of_week(julian_year(year, month, day), month, day, starts_on)
      end

      def day_of_era(year, month, day) do
        Calendrical.Julian.day_of_era(julian_year(year, month, day), month, day)
      end

      def iso_week_of_year(year, month, day) do
        Calendrical.Julian.iso_week_of_year(julian_year(year, month, day), month, day)
      end

      def week_of_year(year, month, day) do
        Calendrical.Julian.week_of_year(julian_year(year, month, day), month, day)
      end

      def year_of_era(year, month, day) do
        Calendrical.Julian.year_of_era(julian_year(year, month, day), month, day)
      end

      defdelegate week(year, week), to: Calendrical.Julian
      defdelegate weeks_in_year(year), to: Calendrical.Julian
      defdelegate months_in_year(year), to: Calendrical.Julian
      defdelegate periods_in_year(year), to: Calendrical.Julian
      # Parsing must validate against this variant's own year labeling
      # (a leap day can be valid here in a different label year than in
      # plain Julian), so parse with this module as the calendar.
      def parse_date(string) do
        Calendrical.Parse.parse_date(string, __MODULE__)
      end

      defdelegate date_to_string(year, month, day), to: Calendrical.Julian
      defdelegate cldr_calendar_type(), to: Calendrical.Julian
      defdelegate calendar_base(), to: Calendrical.Julian

      def week_of_month(year, month, day) do
        Calendrical.Julian.week_of_month(julian_year(year, month, day), month, day)
      end

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
