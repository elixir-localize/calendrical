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

    Module.put_attribute(env.module, :calendar_config, options)

    quote location: :keep,
          bind_quoted: [
            config: config,
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
      @segment_calendars segments |> Enum.map(& &1.calendar) |> List.to_tuple()
      @transition_months transition_months

      # The first day of each member calendar after the base calendar.
      # Only a day within two years of one can be a day whose date names
      # another day.
      @change_days segments |> Enum.map(& &1.first) |> Enum.reject(&is_nil/1)
      @change_reach 800

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

      @member_calendars config |> Enum.map(&elem(&1, 4)) |> Enum.uniq()

      # The CLDR calendar whose era names the member calendars share:
      # `Calendrical.Reform.Japan`'s lunisolar and Gregorian members both
      # name their eras from the Japanese calendar. Members that name
      # them from different calendars leave `cldr_calendar_type/0`.
      @doc false
      @impl Calendrical
      def era_calendar_type do
        @member_calendars
        |> Enum.map(& &1.era_calendar_type())
        |> Enum.uniq()
        |> case do
          [era_calendar_type] -> era_calendar_type
          _era_calendar_types -> cldr_calendar_type()
        end
      end

      @doc """
      Returns the calendar module a date written for this calendar
      is parsed in: the calendar itself.

      """
      @impl Calendrical
      def parsing_calendar do
        __MODULE__
      end

      # The place among `@segments` of the segment a date is read in. A
      # date falls, by the order of its year, month and day, in the segment
      # of the last change of calendar whose first day's it is not before,
      # and it is read there when that segment has days of its year: its
      # years begin with that of its first day, so only its last is asked.
      # Where the segment has no day of the year,
      # `Calendrical.Composite.Label` finds the segment that has. The base
      # calendar has no first day.
      for {{{_iso_days, y, m, d, _calendar}, %{last_year: last_year}}, index} <-
            config |> Enum.zip(segments) |> Enum.with_index() |> Enum.drop(1) |> Enum.reverse() do
        if last_year do
          defp segment_for_date(year, month, day)
               when year <= unquote(last_year) and
                      (year > unquote(y) or
                         (year >= unquote(y) and month > unquote(m)) or
                         (year >= unquote(y) and month >= unquote(m) and day >= unquote(d))) do
            unquote(index)
          end

          defp segment_for_date(year, month, day)
               when year > unquote(y) or
                      (year >= unquote(y) and month > unquote(m)) or
                      (year >= unquote(y) and month >= unquote(m) and day >= unquote(d)) do
            Calendrical.Composite.Label.segment(@segments, unquote(index), year, month, day)
          end
        else
          defp segment_for_date(year, month, day)
               when year > unquote(y) or
                      (year >= unquote(y) and month > unquote(m)) or
                      (year >= unquote(y) and month >= unquote(m) and day >= unquote(d)) do
            unquote(index)
          end
        end
      end

      @base_last_year hd(segments).last_year

      defp segment_for_date(year, _month, _day) when year <= @base_last_year, do: 0

      defp segment_for_date(year, month, day) do
        Calendrical.Composite.Label.segment(@segments, 0, year, month, day)
      end

      # The place among `@segments` of the segment a day is in.
      for {{iso_days, _y, _m, _d, _calendar}, index} <-
            config |> Enum.with_index() |> Enum.drop(1) |> Enum.reverse() do
        defp segment_index(iso_days) when iso_days >= unquote(iso_days), do: unquote(index)
      end

      defp segment_index(_iso_days), do: 0

      @doc """
      Identify the base calendar for a given date.

      This function derives the calendar we delegate to for a given
      date based upon the configuration.

      """
      def calendar_for_date(year, month, day) do
        elem(@segment_calendars, segment_for_date(year, month, day))
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
      def calendar_for_iso_days(iso_days) do
        elem(@segment_calendars, segment_index(iso_days))
      end

      @doc """
      Determines if the date given is valid according to this calendar.

      """
      @impl true
      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        index = segment_for_date(year, month, day)
        calendar = elem(@segment_calendars, index)

        calendar.valid_date?(year, month, day) and
          segment_index(calendar.date_to_iso_days(year, month, day)) == index
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
      Returns the calendar year as displayed on rendered calendars,
      as the calendar in effect on the date gives it.

      """
      @spec calendar_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def calendar_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.calendar_year(year, month, day)
      end

      @doc """
      Returns the related Gregorian year, as the calendar in effect
      on the date gives it.

      """
      @spec related_gregorian_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
              Calendar.year()
      @impl true
      def related_gregorian_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.related_gregorian_year(year, month, day)
      end

      @doc """
      Returns the extended year, as the calendar in effect on the
      date gives it.

      """
      @spec extended_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def extended_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.extended_year(year, month, day)
      end

      @doc """
      Returns the cyclic year, as the calendar in effect on the date
      gives it.

      """
      @spec cyclic_year(Calendar.year(), Calendar.month(), Calendar.day()) :: Calendar.year()
      @impl true
      def cyclic_year(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.cyclic_year(year, month, day)
      end

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
      Returns the month of the CLDR calendar that a month of
      the year names: its member calendars' months are the
      CLDR calendar's.

      """
      @impl true
      def cardinal_month(month) do
        month
      end

      @doc """
      Calculates the week of the year for the given date: the member
      calendar's week in a year one member governs throughout, and in a
      year a transition falls in, the composite's own calendar-aligned
      week, cut to the year.

      """
      @impl true
      def week_of_year(year, month, day) do
        case year_calendar(year) do
          nil -> Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
          calendar -> calendar.week_of_year(year, month, day)
        end
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
      Calculates the week of the month for the given date, as the
      calendar in effect on that date numbers it, or in a month a
      transition cuts short or splits, as the composite's own
      calendar-aligned weeks number it.

      """
      @impl true
      def week_of_month(year, month, day) when {year, month} in @transition_months do
        Calendrical.Base.Common.week_of_month(__MODULE__, year, month, day)
      end

      def week_of_month(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.week_of_month(year, month, day)
      end

      @doc """
      Calculates the day and era for the given date.

      The era is the one the calendar in effect on the date gives, and
      its days are counted in one count through every change of calendar
      the era runs through: that of the calendar in effect where the era
      begins, or where it ends for an era whose days are counted back from
      its last. So the day after 2 September 1752 in England, 14
      September, is the next day of the era.

      """
      @impl true
      def day_of_era(year, month, day) do
        index = segment_for_date(year, month, day)
        Calendrical.Composite.Era.day_of_era(@segments, index, year, month, day)
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
      # Day, 25 March, and Russia's 1492, the last reckoned from 1 March,
      # from 1 March to 31 August. `Calendrical`'s functions of a year ask
      # for these days: where two stretches of days carry the same dates
      # one has none of its own, and `year/1` runs between the dates of the
      # other.
      @doc false
      def year_bounds(year) do
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
            year_first = if first, do: max(year_first, first), else: year_first
            year_last = if last, do: min(year_last, last), else: year_last
            if year_first <= year_last, do: [{year_first, year_last}], else: []

          _no_such_year ->
            []
        end
      end

      @doc """
      Returns the number of weeks in the given year, as
      `week_of_year/3` counts them.

      """
      @impl true
      def weeks_in_year(year) do
        case year_calendar(year) do
          nil -> Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
          calendar -> calendar.weeks_in_year(year)
        end
      end

      # The member calendar that governs every day of `year`, or nil for
      # a year a transition falls in or cuts short, whose weeks are the
      # composite's own.
      defp year_calendar(year) when is_integer(year) do
        case year_bounds(year) do
          {first, last} ->
            whole_year_calendar(
              calendar_for_iso_days(first),
              calendar_for_iso_days(last),
              year,
              first,
              last
            )

          nil ->
            nil
        end
      end

      defp year_calendar(_year), do: nil

      defp whole_year_calendar(calendar, calendar, year, first, last) do
        case calendar.year(year) do
          %Date.Range{first_in_iso_days: ^first, last_in_iso_days: ^last} -> calendar
          _cut_short -> nil
        end
      end

      defp whole_year_calendar(_calendar, _other_calendar, _year, _first, _last), do: nil

      @doc """
      Returns the number of days in the given year and month.

      A month a transition cuts short, or splits between two calendars,
      counts only the days that carry its label: England's September
      1752 has 19 days (1 and 2, then 14 to 30). A month no day carries
      has none: England's January and February 1751, since its 1751 began
      on 25 March.

      """
      @impl true
      def days_in_month(year, month) when {year, month} in @transition_months do
        Enum.count(1..31, &valid_date?(year, month, &1))
      end

      def days_in_month(year, month) do
        if valid_date?(year, month, 1),
          do: calendar_for_date(year, month, 1).days_in_month(year, month),
          else: 0
      end

      @doc """
      Returns the number of the last month of the given year that has
      days, which is the number of months in a year a transition does not
      cut short.

      England's 1751, which began on 25 March, has months 3 to 12 and
      answers 12; Russia's 1492, which ended on 31 August, answers 8. A
      year no day carries answers `0`.

      """
      @impl true
      def months_in_year(year) do
        year
        |> year_calendars()
        |> Enum.map(& &1.months_in_year(year))
        |> Enum.max(fn -> 0 end)
        |> last_month_with_days(year)
      end

      # The member calendars that label some day of `year`.
      defp year_calendars(year) do
        for segment <- @segments, segment_year_bounds(segment, year) != [], do: segment.calendar
      end

      defp last_month_with_days(0, _year), do: 0

      defp last_month_with_days(month, year) do
        if days_in_month(year, month) > 0,
          do: month,
          else: last_month_with_days(month - 1, year)
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
      Returns a `Date.Range` representing a given year: from the first
      to the last of its days that has a date of its own, from whichever
      day it begins on.

      Where a change of the day a year begins on gives two stretches of a
      year's days the same dates, one of them has no dates of its own and
      the range runs between the dates of the other: England's 1155 is 1
      January to 31 December, although its days ran on to 24 March 1156.
      `days_in_year/1` counts every day of the year.

      """
      @impl true
      def year(year) do
        with {first, last} <- year_bounds(year),
             {first, last} <- Calendrical.Base.Common.dated_days(__MODULE__, first, last) do
          Date.range(date_at(first), date_at(last))
        else
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
        period_of_year(year, quarter, @quarters_in_year)
      end

      def quarter(_year, _quarter), do: {:error, :invalid_date}

      @doc """
      Returns a `Date.Range` representing a given quadrimester (third)
      of a year, on the rules `quarter/2` follows.

      """
      @impl true
      def quadrimester(year, quadrimester) when quadrimester in 1..3 do
        period_of_year(year, quadrimester, 3)
      end

      def quadrimester(_year, _quadrimester), do: {:error, :invalid_date}

      @doc """
      Returns a `Date.Range` representing a given semester (half) of a
      year, on the rules `quarter/2` follows.

      """
      @impl true
      def semester(year, semester) when semester in 1..2 do
        period_of_year(year, semester, 2)
      end

      def semester(_year, _semester), do: {:error, :invalid_date}

      defp period_of_year(year, period, periods_in_year) do
        months_in_year = months_in_year(year)

        if rem(months_in_year, periods_in_year) == 0 and january_year?(year) do
          months_in_period = div(months_in_year, periods_in_year)
          first_month = months_in_period * (period - 1) + 1

          first_month..(first_month + months_in_period - 1)
          |> Enum.map(&month(year, &1))
          |> Enum.filter(&match?(%Date.Range{}, &1))
          |> quarter_range()
        else
          {:error, :not_defined}
        end
      end

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
      Returns a `Date.Range` representing a given week of a year, as
      `week_of_year/3` numbers weeks.

      """
      @impl true
      def week(year, week) do
        case year_calendar(year) do
          nil -> Calendrical.Base.Common.week(__MODULE__, year, week)
          calendar -> calendar |> member_week(year, week) |> week_in_composite()
        end
      end

      defp week_in_composite(%Date.Range{
             first_in_iso_days: first_days,
             last_in_iso_days: last_days
           }),
           do: Date.range(date_at(first_days), date_at(last_days))

      defp week_in_composite(other), do: other

      # Dispatches `week/2` to the member calendar in effect. The widening
      # spec keeps the `Date.Range` clause in `week/2` reachable for the type
      # checker whatever week support the member calendars have: a
      # composite of calendars that return `{:error, :not_defined}` (a
      # consumer's calendar without weeks) would otherwise have that clause
      # flagged as unreachable.
      @spec member_week(module(), Calendar.year(), non_neg_integer()) ::
              Date.Range.t() | {:error, :not_defined | :invalid_date}
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
      def date_to_iso_days(year, month, day) do
        calendar_for_date(year, month, day).date_to_iso_days(year, month, day)
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

      A day whose date is another day's, where two stretches of days carry
      the same dates, has no date of its own and is written as the first
      later day that has one, as a shift into the days a reform took out
      reaches the day after them: England's 1 January to 24 March 1156,
      whose dates are 1155's, are written as 25 March 1156.

      """
      def date_from_iso_days(iso_days) do
        date = calendar_for_iso_days(iso_days).date_from_iso_days(iso_days)

        if near_change?(iso_days),
          do: own_date(date, iso_days),
          else: date
      end

      defp own_date({year, month, day} = date, iso_days) do
        if date_to_iso_days(year, month, day) == iso_days,
          do: date,
          else: date_from_iso_days(iso_days + 1)
      end

      defp near_change?(iso_days) do
        Enum.any?(@change_days, &(abs(iso_days - &1) <= @change_reach))
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
      the date, a year being as many months as that calendar counts.
      When the result falls under another calendar the months
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
      Returns the whole number of `date_part`s from one
      `{year, month, day}` to another — the inverse of `plus/6`,
      counted through each calendar a span crosses.

      """
      @impl true
      def diff(from, to, date_part) do
        Calendrical.Composite.Diff.diff(__MODULE__, from, to, date_part)
      end

      @doc """
      Shifts a date by the given duration: the years and months
      together, as `plus/6` adds months, and then the weeks and days.

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

      # Years and months added together, the day brought into the month
      # reached once, for `Calendrical.shift_date/5`: the answer of the
      # calendar in effect on the date while the date reached is under it
      # too, and otherwise the months walked across the segments, as many
      # as that calendar counts (`Calendrical.Composite.Shift`). The
      # first of the month in this calendar is no reference here, as it is
      # for other calendars: a change of calendar can begin a month part
      # of the way through (England's March 1751 begins on the 25th), and
      # a year reckoned from 25 March has its 1 March eleven months after
      # its 25 March.
      @doc false
      def shift_months(year, month, day, years, months) do
        calendar = calendar_for_date(year, month, day)
        duration = Duration.new!(year: years, month: months)
        {new_year, new_month, new_day} = calendar.shift_date(year, month, day, duration)

        if calendar_for_date(new_year, new_month, new_day) == calendar and
             valid_date?(new_year, new_month, new_day) do
          {new_year, new_month, new_day}
        else
          months = Calendrical.Composite.Shift.months(calendar, year, month, duration)
          date_from_iso_days(reach_across_segments(year, month, day, months))
        end
      end

      defp shift_by(year, month, day, date_part, increment) do
        date_from_iso_days(reach(year, month, day, date_part, increment))
      end

      # The day a count of years or months reaches from a date, in ISO days.
      # Within the segment of the calendar in effect the calendar's own
      # arithmetic is the answer. Otherwise the months are walked across
      # the segments, a year being as many of them as that calendar counts.
      # `plus/6` writes the day as a date; `Calendrical.Composite.Diff`
      # compares it as a day, since the date of a day with none of its own
      # names another day.
      @doc false
      def reach(year, month, day, date_part, increment) do
        calendar = calendar_for_date(year, month, day)

        {new_year, new_month, new_day} =
          calendar.plus(year, month, day, date_part, increment, coerce: true)

        if calendar_for_date(new_year, new_month, new_day) == calendar and
             valid_date?(new_year, new_month, new_day) do
          calendar.date_to_iso_days(new_year, new_month, new_day)
        else
          months = Calendrical.Composite.Shift.months(calendar, year, month, date_part, increment)
          reach_across_segments(year, month, day, months)
        end
      end

      defp reach_across_segments(year, month, day, months) do
        index = segment_index(date_to_iso_days(year, month, day))
        segment = Enum.at(@segments, index)
        {civil_year, civil_month, _day} = to_civil(segment, year, month, day)
        {index, civil_month} = walk_months(index, {civil_year, civil_month}, months)
        resolve_day(index, civil_month, day)
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

      # The day of a civil month, in ISO days: in the segment the walk
      # ended in or a neighbour sharing the month; failing that, the
      # month's next day that exists, or its last. Where a year-start
      # transition gives two stretches of days the same labels (England's
      # January to March 1155 and 1156) no label names the later stretch
      # alone, and the day is then the one the segment's own calendar
      # names.
      defp resolve_day(index, civil_month, day) do
        segments = sharing_segments(index, civil_month)

        Enum.find_value(day..31//1, &civil_day(segments, civil_month, &1)) ||
          Enum.find_value((day - 1)..1//-1, &civil_day(segments, civil_month, &1)) ||
          segment_day(Enum.at(@segments, index), civil_month, day)
      end

      defp segment_day(%{civil: civil}, {civil_year, civil_month}, day) do
        day = min(day, civil.days_in_month(civil_year, civil_month))
        civil.date_to_iso_days(civil_year, civil_month, day)
      end

      defp sharing_segments(index, civil_month) do
        %{first_month: first, last_month: last} = segment = Enum.at(@segments, index)
        before = if civil_month == first, do: [Enum.at(@segments, index - 1)], else: []
        later = if civil_month == last, do: [Enum.at(@segments, index + 1)], else: []
        [segment | before ++ later]
      end

      defp civil_day(segments, {civil_year, civil_month}, day) do
        Enum.find_value(segments, fn %{calendar: calendar} = segment ->
          {year, month, day} = from_civil(segment, civil_year, civil_month, day)

          if calendar_for_date(year, month, day) == calendar and valid_date?(year, month, day),
            do: calendar.date_to_iso_days(year, month, day)
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
