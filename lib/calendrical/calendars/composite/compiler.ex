defmodule Calendrical.Composite.Compiler do
  @moduledoc false

  defmacro __before_compile__(env) do
    start_astro!()

    options =
      Module.get_attribute(env.module, :options)
      |> Calendrical.Composite.Config.extract_options()

    config = Macro.escape(options)
    segments = options |> Calendrical.Composite.Config.segments() |> Macro.escape()
    transition_months = Calendrical.Composite.Config.transition_months(options)

    quote location: :keep,
          bind_quoted: [
            config: config,
            segments: segments,
            transition_months: transition_months
          ] do
      @behaviour Calendar
      @behaviour Calendrical
      use Calendrical.Compiler.StandardCallbacks

      @type year :: -9999..9999
      @type month :: 1..12
      @type day :: 1..31

      @quarters_in_year 4

      # The member calendars' segments of the time line, in order, and
      # the months a transition cuts short or splits.
      @segments segments
      @segment_calendars segments |> Enum.map(& &1.calendar) |> List.to_tuple()

      # The last year the base calendar alone has days in.
      @base_last_year hd(segments).last_year

      @member_calendars config |> Enum.map(&elem(&1, 4)) |> Enum.uniq()

      # The CLDR calendar that names the months and days where no date is
      # given, as in parsing: the one the member calendars share, and
      # otherwise the last member's, the calendar in effect today.
      @cldr_calendar_type (case Enum.uniq(Enum.map(@member_calendars, & &1.cldr_calendar_type())) do
                             [cldr_calendar_type] ->
                               cldr_calendar_type

                             _cldr_calendar_types ->
                               config |> List.last() |> elem(4) |> then(& &1.cldr_calendar_type())
                           end)
      @transition_months transition_months

      # The first day of each member calendar after the base calendar.
      # Only a day within two years of one can be a day whose date names
      # another day.
      @change_days segments |> Enum.map(& &1.first) |> Enum.reject(&is_nil/1)
      @change_reach 800

      # The years a change of calendar falls in, as each member labels
      # them: the only years with other months, or other days of a month,
      # than a member's own years have.
      @transition_years segments
                        |> Enum.flat_map(&[&1.first_year, &1.last_year])
                        |> Enum.reject(&is_nil/1)
                        |> Enum.uniq()

      import Localize.Macros

      # The CLDR calendar that names the eras: the one the members share,
      # and otherwise the one that names the months and days.
      defp era_of_members do
        @member_calendars
        |> Enum.map(& &1.info().era_calendar_type)
        |> Enum.uniq()
        |> case do
          [era_calendar_type] -> era_calendar_type
          _era_calendar_types -> @cldr_calendar_type
        end
      end

      # The fewest and the most months a year of any member has.
      defp months_of_members do
        bounds = Enum.map(@member_calendars, & &1.info().months_in_year)

        {bounds |> Enum.map(&elem(&1, 0)) |> Enum.min(),
         bounds |> Enum.map(&elem(&1, 1)) |> Enum.max()}
      end

      @doc """
      Returns the static facts about this calendar, as
      `t:Calendrical.Info.t/0`: its members, each with the first day it
      is in effect on, its base member's year 0 and the weeks of the
      member in effect last.

      ### Returns

      * A `t:Calendrical.Info.t/0` describing this calendar, whose
        `:members` are `{first_iso_day, calendar}` tuples in the order the
        member calendars take effect, the base calendar's first day being
        `nil`.

      ### Examples

          iex> #{inspect(__MODULE__)}.info().calendar
          #{inspect(__MODULE__)}
          iex> match?([{nil, _base_calendar} | _], #{inspect(__MODULE__)}.info().members)
          true

      """
      @impl true
      def info do
        base = elem(@segment_calendars, 0)
        last = elem(@segment_calendars, tuple_size(@segment_calendars) - 1)

        Calendrical.Info.new(__MODULE__,
          cldr_calendar_type: @cldr_calendar_type,
          era_calendar_type: era_of_members(),
          structure: :months,
          months_in_year: months_of_members(),
          parsing_calendar: __MODULE__,
          epoch: nil,
          year_zero?: base.info().year_zero?,
          weeks: last.info().weeks,
          members: Enum.map(@segments, &{&1.first, &1.calendar})
        )
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

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * The member calendar module in effect on the date.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> calendar = #{inspect(__MODULE__)}.calendar_for_date(date.year, date.month, date.day)
          iex> calendar in Enum.map(#{inspect(__MODULE__)}.info().members, &elem(&1, 1))
          true

      """
      def calendar_for_date(year, month, day) do
        elem(@segment_calendars, segment_for_date(year, month, day))
      end

      @doc """
      Identify the member calendar in effect on a given date struct.

      A date of this calendar is looked up by its year, month and day. A
      date of any other calendar is first converted to this calendar.

      ### Arguments

      * `date` is any date map with `:year`, `:month`, `:day` and
        `:calendar` fields, such as a `t:Date.t/0`.

      ### Returns

      * The member calendar module in effect on the date.

      * Raises if a date of another calendar cannot be converted to
        this calendar.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.calendar_for_date(date) ==
          ...>   #{inspect(__MODULE__)}.calendar_for_date(date.year, date.month, date.day)
          true
          iex> #{inspect(__MODULE__)}.calendar_for_date(~D[2024-06-01]) ==
          ...>   #{inspect(__MODULE__)}.calendar_for_date(date)
          true

      """
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

      ### Arguments

      * `iso_days` is an integer number of days since the ISO epoch.

      ### Returns

      * The member calendar module in effect on that day.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> iso_days = Date.to_gregorian_days(~D[2024-06-01])
          iex> #{inspect(__MODULE__)}.calendar_for_iso_days(iso_days) ==
          ...>   #{inspect(__MODULE__)}.calendar_for_date(date.year, date.month, date.day)
          true

      """
      def calendar_for_iso_days(iso_days) do
        elem(@segment_calendars, segment_index(iso_days))
      end

      @doc """
      Determines if the date given is valid according to this calendar.

      A date is valid when the member calendar in effect on it accepts it
      and the day it names is one that calendar governs, so a date a
      change of calendar took out is not valid.

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
          when is_integer(year) and is_integer(month) and is_integer(day) do
        index = segment_for_date(year, month, day)
        calendar = elem(@segment_calendars, index)

        calendar.valid_date?(year, month, day) and
          segment_index(calendar.date_to_iso_days(year, month, day)) == index
      end

      def valid_date?(_year, _month, _day), do: false

      defp member_cardinal_month(calendar, {month, :leap}) when is_integer(month) do
        {calendar.cardinal_month(month), :leap}
      end

      defp member_cardinal_month(calendar, month) when is_integer(month) do
        calendar.cardinal_month(month)
      end

      defp member_cardinal_month(_calendar, other), do: other

      @doc """
      Calculates the year and era from the given `year`, `month`,
      and `day`. The result is in the context of the calendar in
      effect on that date.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * `{year_of_era, era}` where `year_of_era` is the year within the
        era and `era` is the era's index, as the member calendar in effect
        on the date gives them.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year_of_era, era} = #{inspect(__MODULE__)}.year_of_era(date.year, date.month, date.day)
          iex> is_integer(year_of_era) and is_integer(era)
          true

      """
      @spec year_of_era(year, month, day) :: {year, era :: non_neg_integer}
      @impl true
      def year_of_era(year, month, day) do
        calendar = calendar_for_date(year, month, day)
        calendar.year_of_era(year, month, day)
      end

      @doc """
      Calculates the day and era for the given date.

      The era is the one the calendar in effect on the date gives, and
      its days are counted in one count through every change of calendar
      the era runs through: that of the calendar in effect where the era
      begins, or where it ends for an era whose days are counted back from
      its last. So the day after 2 September 1752 in England, 14
      September, is the next day of the era.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * `{day_of_era, era}` where `day_of_era` is the day within the era
        and `era` is the era's index, the same era `year_of_era/3` gives.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {day_of_era, era} = #{inspect(__MODULE__)}.day_of_era(date.year, date.month, date.day)
          iex> {_year_of_era, year_era} = #{inspect(__MODULE__)}.year_of_era(date.year, date.month, date.day)
          iex> day_of_era >= 1 and era == year_era
          true

      """
      @impl true
      def day_of_era(year, month, day) do
        index = segment_for_date(year, month, day)
        Calendrical.Composite.Era.day_of_era(@segments, index, year, month, day)
      end

      @doc """
      Returns the whole number of `date_part`s from one
      `{year, month, day}` to another, as `shift/6` adds them,
      counted through each calendar a span crosses.

      ### Arguments

      * `from` is the `{year, month, day}` the count starts from.

      * `to` is the `{year, month, day}` the count ends at.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      ### Returns

      * The largest whole number of `date_part`s `shift/6` can add to the
        earlier date without passing the later one, as an integer. It is
        negative when `to` is before `from`.

      * `{:error, %Calendrical.InvalidDateError{}}` for a `from` or `to` the
        calendar does not have, `{:error, %Calendrical.MissingFieldsError{}}`
        for one missing a field, or `{:error, %Calendrical.InvalidPartError{}}`
        for a `date_part` other than the five.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> from = {date.year, date.month, date.day}
          iex> to = #{inspect(__MODULE__)}.shift(date.year, date.month, date.day, :months, 3)
          iex> #{inspect(__MODULE__)}.diff(from, to, :months)
          3
          iex> #{inspect(__MODULE__)}.diff(to, from, :months)
          -3

      """
      @impl true
      def diff(from, to, date_part) do
        Calendrical.Composite.Diff.diff(__MODULE__, from, to, date_part)
      end

      @doc """
      Returns the figures a date is written with: the member calendar's.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * `{year, month, day}` as the member calendar in effect on the date
        writes it, where `month` may be `{number, :leap}` for the leap
        month of a lunisolar member.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
          {:ok, {date.year, date.month, date.day}}

      """
      @impl true
      def written_date(year, month, day) do
        calendar_for_date(year, month, day).written_date(year, month, day)
      end

      @doc """
      Returns the date of this calendar that written figures name: the
      date of the member calendar in effect on the day they name, in this
      calendar's own fields.

      ### Arguments

      * `year` is the written year.

      * `month` is the written month, an integer or `{number, :leap}`
        for the leap month of a lunisolar member.

      * `day` is the written day.

      ### Returns

      * `{:ok, {year, month, day}}` with the date of this calendar the
        figures name.

      * `{:error, :invalid_date}` if no member calendar in effect on the day
        reads the figures as a date, an atom as
        `c:Calendrical.date_from_written_date/3` answers.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(date.year, date.month, date.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
          {:ok, {date.year, date.month, date.day}}
          iex> #{inspect(__MODULE__)}.date_from_written_date(date.year, 13, 40)
          {:error, :invalid_date}

      """
      @impl true
      def date_from_written_date(year, month, day) do
        Enum.find_value(
          @member_calendars,
          # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
          # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
          {:error, :invalid_date},
          &written_in(&1, year, month, day)
        )
      end

      # The date, in this calendar's fields, of the day a member reads the
      # written figures as, where that member is the one in effect on it.
      defp written_in(member, year, month, day) do
        case member.date_from_written_date(year, month, day) do
          {:ok, {member_year, member_month, member_day}} ->
            iso_days = member.date_to_iso_days(member_year, member_month, member_day)

            if calendar_for_iso_days(iso_days) == member,
              do: {:ok, date_from_iso_days(iso_days)},
              else: nil

          {:error, :invalid_date} ->
            nil
        end
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

            if year_first <= year_last and dated?(calendar, year_last),
              do: [{year_first, year_last}],
              else: []

          _no_such_year ->
            []
        end
      end

      # Whether a day's date in its segment's calendar is its own: where
      # a change of the day a year begins on gives a calendar's last
      # stretch of days the labels the calendar after claims, the whole
      # stretch has no dates of its own and no day of the year.
      defp dated?(calendar, iso_days) do
        {year, month, day} = calendar.date_from_iso_days(iso_days)
        valid_date?(year, month, day) and date_to_iso_days(year, month, day) == iso_days
      end

      @doc """
      Returns the number of days in the given year and month.

      A month a transition cuts short, or splits between two calendars,
      counts only the days that carry its label: England's September
      1752 has 19 days (1 and 2, then 14 to 30). A month no day carries
      has none: England's January and February 1751, since its 1751 began
      on 25 March.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      ### Returns

      * The number of days that carry the label of `year` and `month`, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month no day
        carries, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where `year` or
        `month` is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.days_in_month(date.year, date.month) >= date.day
          true
          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:error, %Calendrical.InvalidMonthError{month: 0}} = #{inspect(__MODULE__)}.days_in_month(date.year, 0)

      """
      @impl true
      @spec days_in_month(Calendar.year(), Calendar.month()) ::
              Calendar.day() | {:error, Exception.t()}
      def days_in_month(year, month) when is_integer(year) and is_integer(month) do
        case days_carried(year, month) do
          0 -> no_days(year, month)
          days -> days
        end
      end

      def days_in_month(year, month) when is_nil(year) or is_nil(month) do
        {:error,
         Calendrical.MissingFieldsError.exception(
           function: "days_in_month",
           fields: [year: year, month: month]
         )}
      end

      def days_in_month(year, month) do
        {:error,
         Calendrical.InvalidMonthError.exception(calendar: __MODULE__, year: year, month: month)}
      end

      # A month no day carries: a year the calendar in effect cannot reckon
      # is that calendar's range error, named for this one, and any other is
      # a month the year does not have.
      defp no_days(year, month) do
        case Calendrical.Info.in_effect(__MODULE__, year, month, 1) do
          __MODULE__ -> no_such_month(year, month)
          member -> member_no_days(member.days_in_month(year, month), year, month)
        end
      end

      defp member_no_days(
             {:error, %Calendrical.UnsupportedDateRangeError{} = error},
             _year,
             _month
           ),
           do: {:error, %{error | calendar: __MODULE__}}

      defp member_no_days(_member_answer, year, month), do: no_such_month(year, month)

      defp no_such_month(year, month) do
        {:error,
         Calendrical.InvalidMonthError.exception(calendar: __MODULE__, year: year, month: month)}
      end

      # The days that carry the label of `year` and `month`: 0 for a month
      # no day carries, which is how the months of a year are counted.
      defp days_carried(year, month) do
        cond do
          transition_month?(year, month) ->
            Enum.count(1..31, &valid_date?(year, month, &1))

          valid_date?(year, month, 1) ->
            calendar_for_date(year, month, 1).days_in_month(year, month)

          true ->
            0
        end
      end

      @doc """
      Returns the number of the last month of the given year that has
      days, which is the number of months in a year a transition does not
      cut short.

      England's 1751, which began on 25 March, has months 3 to 12 and
      answers 12; Russia's 1492, which ended on 31 August, answers 8. A
      year no day carries answers `0`.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The number of the last month of the year that has days, as a
        non-negative integer. It is `0` for a year no day carries, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where `year` is `nil`, or

      * `{:error, %Calendrical.InvalidDateError{}}` where `year` is no integer.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.months_in_year(date.year) >= date.month
          true

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
        if days_carried(year, month) > 0,
          do: month,
          else: last_month_with_days(month - 1, year)
      end

      defp first_day_of_month(year, month) do
        cond do
          transition_month?(year, month) -> Enum.find(1..31, &valid_date?(year, month, &1))
          valid_date?(year, month, 1) -> 1
          true -> nil
        end
      end

      # A month a change of calendar cuts short or splits, whose days are
      # counted one by one. A runtime test rather than a guard, since a
      # composite of its base calendar alone has none and a guard over an
      # empty list never succeeds.
      defp transition_month?(year, month), do: Enum.member?(@transition_months, {year, month})

      # The last day of the run of days labelled `year` and `month` that
      # starts at `iso_days`: the month's last day, unless the month is
      # cut short, split or has a gap, when the run is followed day by day.
      defp month_end(iso_days, year, month) do
        last = iso_days + days_carried(year, month) - 1

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
      Returns whether the given year is a leap year: the calendar in
      effect on its first day counts it one, and the day the leap year
      adds is a date of this calendar.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * `true` if the member calendar in effect on the first day of
        `year` counts it a leap year and the day its leap year adds, the
        last day of a lengthened month or the first day of a leap month,
        is a date of this calendar; otherwise `false`, as for a year with
        no days of its own (`months_in_year/1` is `0`) and for a year a
        change of calendar took the leap day from, as Sweden's 1700 has
        no 29 February.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> calendar = #{inspect(__MODULE__)}.calendar_for_date(date.year, 1, 1)
          iex> #{inspect(__MODULE__)}.leap_year?(date.year) == calendar.leap_year?(date.year)
          true

      """
      @impl true
      def leap_year?(year) when is_integer(year) do
        if months_in_year(year) == 0 do
          false
        else
          calendar = calendar_for_date(year, 1, 1)
          calendar.leap_year?(year) and leap_day_present?(calendar, year)
        end
      end

      # The day the member's leap year adds is a date of this calendar: the
      # first day of the leap month in a lunisolar member, and in a member
      # of months the last day of each month that is as long as it ever is,
      # where its length varies. A reform that took the day out, as
      # Sweden's 1700 lost its 29 February, leaves the year no leap year.
      defp leap_day_present?(calendar, year) do
        case calendar.leap_month(year) do
          nil ->
            Enum.all?(
              lengthened_months(calendar, year),
              &valid_date?(year, elem(&1, 0), elem(&1, 1))
            )

          month ->
            valid_date?(year, month, 1)
        end
      end

      defp lengthened_months(calendar, year) do
        for month <- 1..calendar.months_in_year(year)//1,
            {fewest, most} = calendar.days_in_month_bounds(month),
            is_integer(fewest) and is_integer(most) and fewest < most,
            days = calendar.days_in_month(year, month),
            days == most,
            do: {month, days}
      end

      @doc """
      Returns the number of days since the ISO epoch for the
      given `year-month-day`.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      ### Returns

      * The number of days since the ISO epoch, as an integer, computed by
        the member calendar in effect on the date.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_to_iso_days(date.year, date.month, date.day) ==
          ...>   Date.to_gregorian_days(~D[2024-06-01])
          true

      """
      @impl true
      def date_to_iso_days(year, month, day) do
        calendar_for_date(year, month, day).date_to_iso_days(year, month, day)
      end

      @doc """
      Returns `{year, month, day}` calculated from the number of
      `iso_days`.

      A day whose date is another day's, where two stretches of days carry
      the same dates, has no date of its own and is written as the first
      later day that has one, as a shift into the days a reform took out
      reaches the day after them: England's 1 January to 24 March 1156,
      whose dates are 1155's, are written as 25 March 1156.

      ### Arguments

      * `iso_days` is an integer number of days since the ISO epoch.

      ### Returns

      * `{year, month, day}`, the date of this calendar for the day, as
        the member calendar in effect on it writes it.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.date_from_iso_days(Date.to_gregorian_days(~D[2024-06-01]))
          {date.year, date.month, date.day}

      """
      @impl true
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

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is a month of the year.

      * `day` is a day of the month.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      * `increment` is the positive or negative integer number of
        `date_part`s to add.

      * `options` is a keyword list of options.

      ### Options

      * `:clamp` is accepted for the `c:Calendrical.shift/6` callback but
        has no effect: a day the resulting month does not have is always
        brought into it as described above.

      ### Returns

      * `{year, month, day}`, the date of this calendar reached, or

      * `{:error, %Calendrical.InvalidDateError{}}` where `year`, `month` and
        `day` are no date of this calendar, or

      * `{:error, %Calendrical.MissingFieldsError{}}` where a field is `nil`.

      ### Examples

          iex> {:ok, date} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.shift(date.year, date.month, date.day, :days, 10)
          iex> #{inspect(__MODULE__)}.date_to_iso_days(year, month, day) -
          ...>   #{inspect(__MODULE__)}.date_to_iso_days(date.year, date.month, date.day)
          10
          iex> to = #{inspect(__MODULE__)}.shift(date.year, date.month, date.day, :years, 1)
          iex> #{inspect(__MODULE__)}.diff({date.year, date.month, date.day}, to, :years)
          1

      """
      @impl true
      def shift(year, month, day, date_part, increment, options \\ [])

      def shift(year, month, day, :years, years, _options) do
        shift_by(year, month, day, :years, years)
      end

      def shift(year, month, day, :quarters, quarters, _options) do
        shift_by(year, month, day, :months, quarters * 3)
      end

      def shift(year, month, day, :months, months, _options) do
        shift_by(year, month, day, :months, months)
      end

      def shift(year, month, day, :weeks, weeks, _options) do
        shift_days({year, month, day}, weeks * days_in_week())
      end

      def shift(year, month, day, :days, days, _options) do
        shift_days({year, month, day}, days)
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
          months = civil_months(year, month, day, duration)
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
      # `shift/6` writes the day as a date; `Calendrical.Composite.Diff`
      # compares it as a day, since the date of a day with none of its own
      # names another day.
      @doc false
      def reach(year, month, day, date_part, increment) do
        calendar = calendar_for_date(year, month, day)

        {new_year, new_month, new_day} =
          calendar.shift(year, month, day, date_part, increment, clamp: true)

        if calendar_for_date(new_year, new_month, new_day) == calendar and
             valid_date?(new_year, new_month, new_day) do
          calendar.date_to_iso_days(new_year, new_month, new_day)
        else
          months = civil_months(year, month, day, date_part, increment)
          reach_across_segments(year, month, day, months)
        end
      end

      # The months are walked from the date's civil month, and the day
      # reached is its civil day: a Julian year-start variant's 25 March is
      # its month 1 day 1, and is walked as the Julian 25 March.
      defp reach_across_segments(year, month, day, months) do
        index = segment_index(date_to_iso_days(year, month, day))
        segment = Enum.at(@segments, index)
        {civil_year, civil_month, civil_day} = to_civil(segment, year, month, day)
        {index, civil_month} = walk_months(index, {civil_year, civil_month}, months)
        resolve_day(index, civil_month, civil_day)
      end

      # The months a shift of years and months walks, counted as the
      # segment's civil calendar counts them: twelve to a year reckoned
      # from 25 March, which names twelve months, not the thirteen it
      # counts.
      defp civil_months(year, month, day, duration_or_part, increment \\ nil) do
        segment = Enum.at(@segments, segment_index(date_to_iso_days(year, month, day)))
        {civil_year, civil_month, _day} = to_civil(segment, year, month, day)

        case duration_or_part do
          %Duration{} = duration ->
            Calendrical.Composite.Shift.months(segment.civil, civil_year, civil_month, duration)

          date_part ->
            Calendrical.Composite.Shift.months(
              segment.civil,
              civil_year,
              civil_month,
              date_part,
              increment
            )
        end
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
        {year, month, _day} = civil.shift(year, month, 1, :months, months, clamp: true)
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

      # A month is shared with a neighbouring segment only when both
      # label the same month — a change within a month, as England's
      # September 1752. A neighbour whose months are its own, as a
      # year-start calendar's counted months, shares none.
      defp sharing_segments(index, civil_month) do
        %{first_month: first, last_month: last} = segment = Enum.at(@segments, index)

        before =
          shared_neighbour(
            civil_month == first,
            Enum.at(@segments, index - 1),
            :last_month,
            civil_month
          )

        later =
          shared_neighbour(
            civil_month == last,
            Enum.at(@segments, index + 1),
            :first_month,
            civil_month
          )

        [segment | before ++ later]
      end

      # The neighbouring segment, as a list, where the month is at this
      # segment's edge and the neighbour labels its own edge month the same.
      defp shared_neighbour(true, %{} = neighbour, edge, civil_month) do
        if Map.fetch!(neighbour, edge) == civil_month, do: [neighbour], else: []
      end

      defp shared_neighbour(_at_edge?, _neighbour, _edge, _civil_month), do: []

      defp civil_day(segments, {civil_year, civil_month}, day) do
        Enum.find_value(segments, fn %{calendar: calendar} = segment ->
          {year, month, day} = from_civil(segment, civil_year, civil_month, day)

          if calendar_for_date(year, month, day) == calendar and valid_date?(year, month, day),
            do: calendar.date_to_iso_days(year, month, day)
        end)
      end

      # A member whose civil calendar is another — a Julian year-start
      # variant, walked in Julian months — has its date given as the
      # Julian date it is, and read back from one. Any other member is its
      # own civil calendar.
      defp to_civil(%{civil: civil, calendar: civil}, year, month, day), do: {year, month, day}

      defp to_civil(%{civil: civil, calendar: calendar}, year, month, day) do
        civil.date_from_iso_days(calendar.date_to_iso_days(year, month, day))
      end

      defp from_civil(%{civil: civil, calendar: civil}, year, month, day), do: {year, month, day}

      defp from_civil(%{calendar: calendar}, year, month, day) do
        calendar.date_from_base_date(year, month, day)
      end
    end
  end

  # A composite calendar finds the day each of its calendars takes effect
  # on as it compiles, and an astronomical calendar such as
  # `Calendrical.LunarJapanese` finds a date from the JPL ephemeris, which
  # Astro loads when its application starts. Starting it here, which does
  # nothing when it has started, gives the composite's calendars the
  # ephemeris at compile time as they have it at run time.
  defp start_astro! do
    case Application.ensure_all_started(:astro) do
      {:ok, _started} ->
        :ok

      {:error, reason} ->
        raise CompileError,
          description:
            "a composite calendar compiles its calendars' dates with Astro, " <>
              "which could not start: #{inspect(reason)}"
    end
  end
end
