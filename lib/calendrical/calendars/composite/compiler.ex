defmodule Calendrical.Composite.Compiler do
  @moduledoc false

  defmacro __before_compile__(env) do
    options =
      Module.get_attribute(env.module, :options)
      |> Keyword.put(:calendar, env.module)
      |> Calendrical.Composite.Config.extract_options()

    config = Macro.escape(options)
    segments = options |> Calendrical.Composite.Config.segments() |> Macro.escape()
    transition_months = Calendrical.Composite.Config.transition_months(options)

    Module.put_attribute(env.module, :calendar_config, config)

    quote location: :keep,
          bind_quoted: [
            config: config,
            reverse: Enum.reverse(config),
            segments: segments,
            transition_months: transition_months
          ] do
      @behaviour Calendar
      @behaviour Calendrical

      @type year :: -9999..9999
      @type month :: 1..12
      @type day :: 1..31

      @quarters_in_year 4

      # The member calendars' segments of the time line, in order, and
      # the months a transition cuts short or splits.
      @segments segments
      @transition_months transition_months

      import Localize.Macros

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
      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        calendar = calendar_for_date(year, month, day)

        if calendar.valid_date?(year, month, day) do
          iso_days = date_to_iso_days(year, month, day)
          calendar_for_iso_days(iso_days) == calendar
        else
          false
        end
      end

      def valid_date?(_year, _month, _day), do: false

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
      Calculates the quarter of the year (1..4) for the given date, as
      the calendar in effect on the date counts it.

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
      Calculates the day of the year for the given date, counting from
      the first day that carries the date's year — which, in a year a
      transition shortens or lengthens, need not be 1 January.

      """
      @impl true
      def day_of_year(year, month, day) do
        case year_bounds(year) do
          {first, _last} -> date_to_iso_days(year, month, day) - first + 1
          nil -> {:error, :invalid_date}
        end
      end

      @doc """
      Calculates the day of the week for the given date.

      """
      @impl true
      def day_of_week(year, month, day, starting_on) do
        calendar = calendar_for_date(year, month, day)
        calendar.day_of_week(year, month, day, starting_on)
      end

      @doc """
      Returns the number of periods in the given year.

      """
      @impl true
      def periods_in_year(year), do: months_in_year(year)

      @doc """
      Returns the number of days that carry the given year, which is
      `0` for a year no segment of the calendar labels.

      """
      @impl true
      def days_in_year(year) do
        case year_bounds(year) do
          {first, last} -> last - first + 1
          nil -> 0
        end
      end

      @impl true
      def dates_in_gregorian_year(gregorian_year, month, day) do
        Calendrical.dates_in_gregorian_year(__MODULE__, gregorian_year, month, day)
      end

      # The ISO days of the first and last days labelled `year`, or nil
      # when no day is: each member calendar's year, cut to the segment
      # that calendar governs. The segments' labels only increase, so the
      # days of a year are consecutive — England's 1751 runs from Lady
      # Day, 25 March, and Russia's 1699 from 1 September to 31 December.
      defp year_bounds(year) do
        @segments
        |> Enum.flat_map(&segment_year_bounds(&1, year))
        |> Enum.reduce(nil, fn
          bounds, nil -> bounds
          {first, last}, {earliest, latest} -> {min(first, earliest), max(last, latest)}
        end)
      end

      defp segment_year_bounds(%{first_year: first_year}, year)
           when is_integer(first_year) and year < first_year,
           do: []

      defp segment_year_bounds(%{last_year: last_year}, year)
           when is_integer(last_year) and year > last_year,
           do: []

      defp segment_year_bounds(%{calendar: calendar, first: first, last: last}, year) do
        case calendar.year(year) do
          %Date.Range{first_in_iso_days: year_first, last_in_iso_days: year_last} ->
            year_first = max(year_first, first)
            year_last = if last, do: min(year_last, last), else: year_last
            if year_first <= year_last, do: [{year_first, year_last}], else: []

          _no_such_year ->
            []
        end
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
      Returns the number of days in the given year and month.

      A month a transition cuts short, or splits between two calendars,
      counts only the days that carry its label: England's September
      1752 has 19 days (1 and 2, then 14 to 30).

      """
      @impl true
      def days_in_month(year, month) when {year, month} in @transition_months do
        Enum.count(1..31, &valid_date?(year, month, &1))
      end

      def days_in_month(year, month) do
        calendar_for_date(year, month, 1).days_in_month(year, month)
      end

      @doc """
      Returns the number of months in the given year, as the calendar
      in effect at the start of the year counts them.

      """
      @impl true
      def months_in_year(year) do
        calendar_for_date(year, 1, 1).months_in_year(year)
      end

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
      Returns a `Date.Range` representing a given year: every day that
      carries the year, from whichever day it begins on.

      """
      @impl true
      def year(year) do
        case year_bounds(year) do
          {first, last} -> Date.range(date_at(first), date_at(last))
          nil -> {:error, :invalid_date}
        end
      end

      @doc """
      Returns a `Date.Range` representing a given quarter of a year,
      from the first day of its first month to the last day of its last.
      A year whose months do not divide into four quarters, or that
      begins on a day other than 1 January, has none.

      """
      @impl true
      def quarter(year, quarter) when quarter in 1..@quarters_in_year do
        months_in_year = months_in_year(year)

        if rem(months_in_year, @quarters_in_year) == 0 and january_year?(year) do
          months_in_quarter = div(months_in_year, @quarters_in_year)
          first_month = months_in_quarter * (quarter - 1) + 1

          first_month..(first_month + months_in_quarter - 1)
          |> Enum.map(&month(year, &1))
          |> Enum.filter(&match?(%Date.Range{}, &1))
          |> quarter_range()
        else
          {:error, :not_defined}
        end
      end

      def quarter(_year, _quarter), do: {:error, :invalid_date}

      # A year labelled from a later new-year day (England's Lady Day years)
      # has no quarters, as its Julian year-start calendar has none.
      defp january_year?(year) do
        case year_bounds(year) do
          {first, _last} -> Enum.at(@segments, segment_index(first)).january_year?
          nil -> false
        end
      end

      defp quarter_range([]), do: {:error, :invalid_date}

      defp quarter_range([%Date.Range{first: first} | _] = months) do
        %Date.Range{last: last} = List.last(months)
        Date.range(first, last)
      end

      @doc """
      Returns a `Date.Range` representing a given month of a year.

      A month a transition cuts short starts or ends on the transition,
      and September 1752 in England runs from the 1st to the 30th across
      the eleven dropped days. In a Julian year-start segment the month
      the year begins in carries its label twice, a year apart (25 to 31
      March 1600 and 1 to 24 March 1601 are both March 1600 in England);
      the range is then the part that holds the month's 1st.

      """
      @impl true
      def month(year, month) do
        case first_day_of_month(year, month) do
          nil ->
            {:error, :invalid_date}

          day ->
            first = date_to_iso_days(year, month, day)
            Date.range(date_at(first), date_at(month_end(first, year, month)))
        end
      end

      defp first_day_of_month(year, month) when {year, month} in @transition_months do
        Enum.find(1..31, &valid_date?(year, month, &1))
      end

      defp first_day_of_month(year, month) do
        if valid_date?(year, month, 1), do: 1
      end

      # The last day of the run of days labelled `year` and `month` that
      # starts at `iso_days`: the month's last day, unless the month is
      # cut short, split or has a gap, when the run is followed day by day.
      defp month_end(iso_days, year, month) do
        last = iso_days + days_in_month(year, month) - 1

        if month_run?(last, year, month) and not month_run?(last + 1, year, month) do
          last
        else
          follow_month(iso_days, year, month)
        end
      end

      defp follow_month(iso_days, year, month) do
        if month_run?(iso_days + 1, year, month),
          do: follow_month(iso_days + 1, year, month),
          else: iso_days
      end

      defp month_run?(iso_days, year, month) do
        match?({^year, ^month, _day}, date_from_iso_days(iso_days))
      end

      defp date_at(iso_days) do
        {year, month, day} = date_from_iso_days(iso_days)
        %Date{year: year, month: month, day: day, calendar: __MODULE__}
      end

      @doc """
      Returns a `Date.Range` representing a given week of a year.

      Not all base calendars define weeks; the result depends on the
      calendar in effect on 1 January of the given year.

      """
      @impl true
      def week(year, week) do
        base_calendar = calendar_for_date(year, 1, 1)

        case member_week(base_calendar, year, week) do
          %Date.Range{first_in_iso_days: first_days, last_in_iso_days: last_days} ->
            Date.range(date_at(first_days), date_at(last_days))

          other ->
            other
        end
      end

      # Dispatches `week/2` to the member calendar in effect. The widening
      # spec keeps the `Date.Range` clause in `week/2` reachable for the type
      # checker: composites whose member calendars all return
      # `{:error, :not_defined}` (e.g. a lunisolar base with no week support)
      # would otherwise have that clause flagged as unreachable.
      @spec member_week(module(), Calendar.year(), non_neg_integer()) ::
              Date.Range.t() | {:error, :not_defined}
      defp member_week(calendar, year, week) do
        calendar.week(year, week)
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
      Adds an `increment` number of `date_part`s to the given
      `year-month-day`, always returning a date of this calendar.

      Years, quarters and months are added in the calendar in effect on
      the date. When the result falls under another calendar the months
      are counted on through each calendar's own months, so one month
      after 20 August 1752 in England is 20 September 1752. A day the
      resulting month does not have becomes the month's next day that
      exists, or its last day: one month after 5 August 1752 is
      14 September 1752 and one month after 31 January is the last day
      of February. Weeks and days count days.

      """
      @impl true
      def plus(year, month, day, date_part, increment, options \\ [])

      def plus(year, month, day, :years, years, _options) do
        shift_by(year, month, day, :years, years)
      end

      def plus(year, month, day, :quarters, quarters, _options) do
        shift_by(year, month, day, :months, quarters * 3)
      end

      def plus(year, month, day, :months, months, _options) do
        shift_by(year, month, day, :months, months)
      end

      def plus(year, month, day, :weeks, weeks, _options) do
        shift_days({year, month, day}, weeks * days_in_week())
      end

      def plus(year, month, day, :days, days, _options) do
        shift_days({year, month, day}, days)
      end

      @doc """
      Shifts a date by the given duration: years, then months, then
      weeks and days, as `plus/6` adds them.

      """
      @impl true
      @spec shift_date(year, month, day, Duration.t()) :: {year, month, day}
      def shift_date(year, month, day, duration) do
        Calendrical.shift_date(year, month, day, __MODULE__, duration)
      end

      @doc false
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

      @doc false
      def shift_days({year, month, day}, days) do
        date_to_iso_days(year, month, day)
        |> Kernel.+(days)
        |> date_from_iso_days()
      end

      # Within the segment of the calendar in effect the calendar's own
      # arithmetic is the answer. Otherwise the months are walked across
      # the segments, a year being twelve of them.
      defp shift_by(year, month, day, date_part, increment) do
        calendar = calendar_for_date(year, month, day)

        {new_year, new_month, new_day} =
          calendar.plus(year, month, day, date_part, increment, coerce: true)

        if calendar_for_date(new_year, new_month, new_day) == calendar and
             valid_date?(new_year, new_month, new_day) do
          {new_year, new_month, new_day}
        else
          months = if date_part == :years, do: increment * 12, else: increment
          shift_across_segments(year, month, day, months)
        end
      end

      defp shift_across_segments(year, month, day, months) do
        index = segment_index(date_to_iso_days(year, month, day))
        segment = Enum.at(@segments, index)
        {civil_year, civil_month, _day} = to_civil(segment, year, month, day)
        {index, civil_month} = walk_months(index, {civil_year, civil_month}, months)
        resolve_day(index, civil_month, day)
      end

      defp segment_index(iso_days) do
        Enum.count(@segments, &(&1.first <= iso_days)) - 1
      end

      # A month is walked in the civil numbering of its segment's
      # calendar. A walk that passes a segment's last month continues in
      # the next segment's first, and the two are one month when they
      # carry the same label (England's September 1752).
      defp walk_months(index, civil_month, 0), do: {index, civil_month}

      defp walk_months(index, civil_month, months) when months > 0 do
        %{civil: civil, last_month: last} = Enum.at(@segments, index)
        target = civil_plus(civil, civil_month, months)

        if is_nil(last) or target <= last do
          {index, target}
        else
          used = months_between(civil, civil_month, last, 0, months)
          %{first_month: next} = Enum.at(@segments, index + 1)
          step = if next == last, do: 0, else: 1
          walk_months(index + 1, next, months - used - step)
        end
      end

      defp walk_months(index, civil_month, months) do
        %{civil: civil, first_month: first} = Enum.at(@segments, index)
        target = civil_plus(civil, civil_month, months)

        if is_nil(first) or target >= first do
          {index, target}
        else
          used = months_between(civil, first, civil_month, 0, -months)
          %{last_month: previous} = Enum.at(@segments, index - 1)
          step = if previous == first, do: 0, else: 1
          walk_months(index - 1, previous, months + used + step)
        end
      end

      defp civil_plus(civil, {year, month}, months) do
        {year, month, _day} = civil.plus(year, month, 1, :months, months, coerce: true)
        {year, month}
      end

      # The number of months from one civil month to a later one, no more
      # than `high`.
      defp months_between(_civil, _from, _to, low, high) when low >= high, do: low

      defp months_between(civil, from, to, low, high) do
        middle = div(low + high, 2)

        if civil_plus(civil, from, middle) < to,
          do: months_between(civil, from, to, middle + 1, high),
          else: months_between(civil, from, to, low, middle)
      end

      # The day of a civil month, in the segment the walk ended in or a
      # neighbour sharing the month; failing that, the month's next day
      # that exists, or its last. Where a year-start transition gives two
      # stretches of days the same labels (England's January to March
      # 1155 and 1156) no label names the later stretch alone, and the
      # day is then the one the segment's own calendar names.
      defp resolve_day(index, civil_month, day) do
        segments = sharing_segments(index, civil_month)

        Enum.find_value(day..31//1, &civil_date(segments, civil_month, &1)) ||
          Enum.find_value((day - 1)..1//-1, &civil_date(segments, civil_month, &1)) ||
          segment_date(Enum.at(@segments, index), civil_month, day)
      end

      defp segment_date(%{civil: civil}, {civil_year, civil_month}, day) do
        day = min(day, civil.days_in_month(civil_year, civil_month))
        date_from_iso_days(civil.date_to_iso_days(civil_year, civil_month, day))
      end

      defp sharing_segments(index, civil_month) do
        %{first_month: first, last_month: last} = segment = Enum.at(@segments, index)
        before = if civil_month == first, do: [Enum.at(@segments, index - 1)], else: []
        later = if civil_month == last, do: [Enum.at(@segments, index + 1)], else: []
        [segment | before ++ later]
      end

      defp civil_date(segments, {civil_year, civil_month}, day) do
        Enum.find_value(segments, fn %{calendar: calendar} = segment ->
          {year, month, day} = from_civil(segment, civil_year, civil_month, day)

          if calendar_for_date(year, month, day) == calendar and valid_date?(year, month, day),
            do: {year, month, day}
        end)
      end

      defp to_civil(%{civil: civil, calendar: civil}, year, month, day), do: {year, month, day}

      defp to_civil(%{civil: civil, calendar: calendar}, year, month, day) do
        civil.date_from_iso_days(calendar.date_to_iso_days(year, month, day))
      end

      defp from_civil(%{civil: civil, calendar: civil}, year, month, day), do: {year, month, day}

      defp from_civil(%{calendar: calendar}, year, month, day) do
        calendar.date_from_julian_date(year, month, day)
      end

      @doc false
      @impl Calendar
      defdelegate shift_time(hour, minute, second, microsecond, duration), to: Calendar.ISO

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
