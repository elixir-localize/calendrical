defmodule Calendrical.Interval do
  @moduledoc """
  Constructs and compares date intervals for any Calendrical calendar.

  An interval is represented as an Elixir `t:Date.Range.t/0` whose `:first` and
  `:last` dates are in the desired calendar. Ranges produced by this module
  are enumerable and have the day as their unit of precision.

  The constructor functions cover the standard calendrical units: `year/2`,
  `quarter/3`, `month/3`, `week/3`, and `day/3`. Each one also accepts a
  single `t:Calendar.date/0` argument and returns the interval that contains
  that date.

  `compare/2` and the corresponding `relation/2` (re-exported from
  `Calendrical.IntervalRelation`) implement
  [Allen's interval algebra](https://en.wikipedia.org/wiki/Allen%27s_interval_algebra),
  returning one of 13 atoms describing how two ranges relate.

  """

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `year`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `year`.

  ### Examples

      iex> Calendrical.Interval.year 2019, Calendrical.Fiscal.UK
      Date.range(~D[2019-01-01 Calendrical.Fiscal.UK], ~D[2019-12-31 Calendrical.Fiscal.UK])

      iex> Calendrical.Interval.year 2019, Calendrical.NRF
      Date.range(~D[2019-W01-1 Calendrical.NRF], ~D[2019-W52-7 Calendrical.NRF])

  """
  @spec year(Calendar.year(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  @spec year(Date.t()) :: Date.Range.t() | {:error, :not_defined | :invalid_date}

  def year(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> year
    |> coerce_iso_calendar
  end

  def year(%{year: _, month: _, day: _} = date) do
    year(date.year, date.calendar)
  end

  def year(year, calendar \\ Calendrical.Gregorian) do
    calendar.year(year)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `quarter`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `quarter` is any `quarter` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `quarter`.

  ### Examples

      iex> Calendrical.Interval.quarter 2019, 2, Calendrical.Fiscal.UK
      Date.range(~D[2019-04-01 Calendrical.Fiscal.UK], ~D[2019-06-30 Calendrical.Fiscal.UK])

      iex> Calendrical.Interval.quarter 2019, 2, Calendrical.ISOWeek
      Date.range(~D[2019-W14-1 Calendrical.ISOWeek], ~D[2019-W26-7 Calendrical.ISOWeek])

  """
  @spec quarter(Calendar.year(), Calendrical.quarter(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  @spec quarter(Date.t()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date} | {:error, Exception.t()}

  def quarter(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> quarter
    |> coerce_iso_calendar
  end

  def quarter(date) do
    case Calendrical.quarter_of_year(date) do
      quarter when is_integer(quarter) -> quarter(date.year, quarter, date.calendar)
      {:error, _reason} = error -> error
    end
  end

  def quarter(year, quarter, calendar \\ Calendrical.Gregorian) do
    calendar.quarter(year, quarter)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `quadrimester`
  (third of the year).

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `quadrimester` is `1`, `2` or `3`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    `quadrimester`, or

  * `{:error, reason}` when the calendar has no such quadrimester.

  ### Examples

      iex> Calendrical.Interval.quadrimester 2026, 2
      Date.range(~D[2026-05-01 Calendrical.Gregorian], ~D[2026-08-31 Calendrical.Gregorian])

  """
  @spec quadrimester(Calendar.year(), Calendrical.quadrimester(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  def quadrimester(year, quadrimester, calendar \\ Calendrical.Gregorian) do
    calendar.quadrimester(year, quadrimester)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `semester`
  (half of the year).

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `semester` is `1` or `2`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    `semester`, or

  * `{:error, reason}` when the calendar has no such semester.

  ### Examples

      iex> Calendrical.Interval.semester 2026, 2
      Date.range(~D[2026-07-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

  """
  @spec semester(Calendar.year(), Calendrical.semester(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  def semester(year, semester, calendar \\ Calendrical.Gregorian) do
    calendar.semester(year, semester)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `month`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `month` is any `month` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `month`.

  ### Examples

      iex> Calendrical.Interval.month 2019, 3, Calendrical.Fiscal.UK
      Date.range(~D[2019-03-01 Calendrical.Fiscal.UK], ~D[2019-03-30 Calendrical.Fiscal.UK])

      iex> Calendrical.Interval.month 2019, 3, Calendrical.Fiscal.US
      Date.range(~D[2019-03-01 Calendrical.Fiscal.US], ~D[2019-03-31 Calendrical.Fiscal.US])

  """
  @spec month(Calendar.year(), Calendar.month(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  @spec month(Date.t()) :: Date.Range.t() | {:error, :invalid_date}

  def month(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> month
    |> coerce_iso_calendar
  end

  # `month/2` counts a calendar's months as `month_of_year/1` numbers them
  # (a fiscal month in a week-based calendar), as the date does (the
  # ordinal month of a lunisolar calendar, whose `month_of_year/1` is the
  # traditional month) or from the start of the year (a Julian new-year
  # variant). The month is the one that holds the date.
  def month(date) do
    iso_days = Date.to_gregorian_days(date)
    candidates = Enum.uniq([Calendrical.month_of_year(date), date.month])

    Enum.find_value(candidates, &holding_month(date, &1, iso_days)) ||
      Enum.find_value(1..months_in_year(date)//1, &holding_month(date, &1, iso_days)) ||
      {:error, :invalid_date}
  end

  defp holding_month(date, month, iso_days) do
    range = month(date.year, month, date.calendar)
    if holds?(range, iso_days), do: range
  end

  defp months_in_year(%{year: year, calendar: calendar}) do
    case calendar.months_in_year(year) do
      months when is_integer(months) -> months
      _undefined -> 0
    end
  end

  def month(year, month, calendar \\ Calendrical.Gregorian) do
    calendar.month(year, month)
  end

  defp holds?(%Date.Range{first_in_iso_days: first, last_in_iso_days: last}, iso_days),
    do: first <= iso_days and iso_days <= last

  defp holds?(_not_a_range, _iso_days), do: false

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `week`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `week` is any `week` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `week`, or

  * `{:error, :not_defined}` if the calendar does not support the concept of
    weeks.

  ### Examples

      iex> Calendrical.Interval.week 2019, 52, Calendrical.Fiscal.US
      Date.range(~D[2019-12-22 Calendrical.Fiscal.US], ~D[2019-12-28 Calendrical.Fiscal.US])

      iex> Calendrical.Interval.week 2019, 52, Calendrical.NRF
      Date.range(~D[2019-W52-1 Calendrical.NRF], ~D[2019-W52-7 Calendrical.NRF])

      iex> Calendrical.Interval.week 2019, 52, Calendrical.ISOWeek
      Date.range(~D[2019-W52-1 Calendrical.ISOWeek], ~D[2019-W52-7 Calendrical.ISOWeek])

      iex> Calendrical.Interval.week 2019, 52, Calendrical.Julian
      Date.range(~D[2019-12-24 Calendrical.Julian], ~D[2019-12-30 Calendrical.Julian])

  """
  @spec week(Calendar.year(), Calendrical.week(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  @spec week(Date.t()) :: Date.Range.t() | {:error, :not_defined | :invalid_date}

  def week(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> week
    |> coerce_iso_calendar
  end

  def week(date) do
    case Calendrical.week_of_year(date) do
      {year, week} when is_integer(year) and is_integer(week) -> week(year, week, date.calendar)
      {:error, _reason} = error -> error
    end
  end

  def week(year, week, calendar \\ Calendrical.Gregorian) do
    calendar.week(year, week)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the nth week of a month.

  The weeks of a month are the weeks `week_of_month/3` of the
  calendar names for it: week 1 is the month's first week under the
  calendar's week configuration, which may begin in the month before,
  and the last week may run into the month after. The range is
  enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `month` is any `month` in the `year` for `calendar`.

  * `nth` is the week of the `month`, a positive integer.

  * `calendar` is any module that implements the `Calendar` and
    `Calendrical` behaviours.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days of the week, or

  * `{:error, :invalid_date}` when the month has no `nth` week, or

  * `{:error, :not_defined}` if the calendar does not support the
    concept of weeks.

  ### Examples

      iex> Calendrical.Interval.week 2026, 5, 1, Calendrical.Gregorian
      Date.range(~D[2026-04-27 Calendrical.Gregorian], ~D[2026-05-03 Calendrical.Gregorian])

      iex> Calendrical.Interval.week 2026, 5, 5, Calendrical.Gregorian
      Date.range(~D[2026-05-25 Calendrical.Gregorian], ~D[2026-05-31 Calendrical.Gregorian])

      iex> Calendrical.Interval.week 2026, 5, 6, Calendrical.Gregorian
      {:error, :invalid_date}

  """
  @spec week(Calendar.year(), Calendar.month(), pos_integer(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  def week(year, month, nth, calendar) when is_integer(nth) and nth >= 1 do
    with {_first, _second, _end_of_weeks, _weeks} = month_weeks <-
           month_weeks(year, month, calendar) do
      nth_week(nth, month_weeks, calendar)
    end
  end

  defp nth_week(nth, {_first, _second, _end_of_weeks, weeks}, _calendar) when nth > weeks do
    {:error, :invalid_date}
  end

  defp nth_week(1, {first_week_start, _second, end_of_weeks, 1}, calendar) do
    iso_days_to_range(first_week_start, end_of_weeks, calendar)
  end

  defp nth_week(1, {first_week_start, second_week_start, _end_of_weeks, _weeks}, calendar) do
    iso_days_to_range(first_week_start, second_week_start - 1, calendar)
  end

  defp nth_week(nth, {_first, second_week_start, end_of_weeks, _weeks}, calendar) do
    days_in_week = calendar.days_in_week()
    first = second_week_start + (nth - 2) * days_in_week
    iso_days_to_range(first, min(first + days_in_week - 1, end_of_weeks), calendar)
  end

  @doc """
  Returns the number of weeks in a month.

  The weeks of a month are the weeks `week_of_month/3` of the
  calendar names for it: week 1 is the month's first week under the
  calendar's week configuration, which may begin in the month before,
  and the last week may run into the month after.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `month` is any `month` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and
    `Calendrical` behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * The number of weeks as a positive integer, or

  * `{:error, :invalid_date}` when the year has no such month, or

  * `{:error, :not_defined}` if the calendar does not support the
    concept of weeks.

  ### Examples

      iex> Calendrical.Interval.weeks_in_month 2026, 5
      5

      # Under the default one-day minimum first week, the week of
      # 23 February to 1 March 2026 is March's week 1, so February
      # has four weeks
      iex> Calendrical.Interval.weeks_in_month 2026, 2
      4

      # The NRF calendar's months are 4, 5 or 4 weeks of a quarter
      iex> Calendrical.Interval.weeks_in_month 2019, 2, Calendrical.NRF
      5

  """
  @spec weeks_in_month(Calendar.year(), Calendar.month(), Calendrical.calendar()) ::
          pos_integer() | {:error, :not_defined | :invalid_date}
  def weeks_in_month(year, month, calendar \\ Calendrical.Gregorian) do
    with {_first_week_start, _second_week_start, _end_of_weeks, weeks} <-
           month_weeks(year, month, calendar) do
      weeks
    end
  end

  # The month's weeks in iso days: the first day of its week 1, the first
  # day of its week 2, the last day of its last week and the week count.
  # `week_of_month/3` is the authority on which week a day is in; the
  # walks are bounded by the days in a week. Week 1 may be short when a
  # calendar's weeks do not cross its months, so weeks are blocks of
  # `days_in_week/0` days from the start of week 2, not of week 1.
  defp month_weeks(year, month, calendar) do
    with %Date.Range{first_in_iso_days: first, last_in_iso_days: last} <-
           month(year, month, calendar) do
      case week_of_month(first, calendar) do
        {:error, _reason} = error ->
          error

        {_month, _week} ->
          days_in_week = calendar.days_in_week()
          first_week_start = start_of_first_week(first, month, days_in_week, calendar)
          {end_of_weeks, weeks} = end_of_last_week(last, month, days_in_week, calendar)
          second_week_start = start_of_second_week(first_week_start, month, weeks, calendar)
          {first_week_start, second_week_start, end_of_weeks, weeks}
      end
    end
  end

  defp start_of_second_week(_first_week_start, _month, 1 = _weeks, _calendar), do: nil

  defp start_of_second_week(first_week_start, month, _weeks, calendar) do
    first_not_in_week_1 =
      Enum.find(
        (first_week_start + 1)..(first_week_start + calendar.days_in_week())//1,
        &(week_of_month(&1, calendar) != {month, 1})
      )

    {^month, 2} = week_of_month(first_not_in_week_1, calendar)
    first_not_in_week_1
  end

  defp week_of_month(iso_days, calendar) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    calendar.week_of_month(year, month, day)
  end

  # The first day of the month's week 1. When the month's first day is
  # already in week 1 that week may have begun in the month before, so
  # walk back through its days; otherwise the first day belongs to the
  # month before's last week and week 1 begins within the first week of
  # days.
  defp start_of_first_week(first, month, days_in_week, calendar) do
    if week_of_month(first, calendar) == {month, 1} do
      back_to_start_of_week(first, month, first - days_in_week + 1, calendar)
    else
      Enum.find(
        (first + 1)..(first + days_in_week - 1)//1,
        &(week_of_month(&1, calendar) == {month, 1})
      )
    end
  end

  defp back_to_start_of_week(iso_days, month, floor, calendar) do
    if iso_days > floor and week_of_month(iso_days - 1, calendar) == {month, 1} do
      back_to_start_of_week(iso_days - 1, month, floor, calendar)
    else
      iso_days
    end
  end

  # The last day of the month's last week and the week count. When the
  # month's last day is in one of its own weeks that week may run into
  # the month after, so walk forward through its days; otherwise the
  # last day belongs to the month after's week 1, and the month's last
  # week ends within the last week of days.
  defp end_of_last_week(last, month, days_in_week, calendar) do
    case week_of_month(last, calendar) do
      {^month, weeks} ->
        {forward_to_end_of_week(last, month, weeks, last + days_in_week - 1, calendar), weeks}

      {_other_month, _week} ->
        (last - 1)..(last - days_in_week + 1)//-1
        |> Enum.find(&match?({^month, _week}, week_of_month(&1, calendar)))
        |> then(fn end_of_weeks ->
          {^month, weeks} = week_of_month(end_of_weeks, calendar)
          {end_of_weeks, weeks}
        end)
    end
  end

  defp forward_to_end_of_week(iso_days, month, weeks, ceiling, calendar) do
    if iso_days < ceiling and week_of_month(iso_days + 1, calendar) == {month, weeks} do
      forward_to_end_of_week(iso_days + 1, month, weeks, ceiling, calendar)
    else
      iso_days
    end
  end

  defp iso_days_to_range(first, last, calendar) do
    {first_year, first_month, first_day} = calendar.date_from_iso_days(first)
    {last_year, last_month, last_day} = calendar.date_from_iso_days(last)

    with {:ok, first_date} <- Date.new(first_year, first_month, first_day, calendar),
         {:ok, last_date} <- Date.new(last_year, last_month, last_day, calendar) do
      Date.range(first_date, last_date)
    end
  end

  @doc """
  Returns a `t:Date.Range.t/0` containing a single `day`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `day` is any `day` in the `year` for `calendar` (the ordinal day of year).

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` containing the single requested day, or

  * `{:error, :invalid_date}` if `day` is greater than the number of days in
    the year.

  ### Examples

      iex> Calendrical.Interval.day 2019, 52, Calendrical.Fiscal.US
      Date.range(~D[2019-02-21 Calendrical.Fiscal.US], ~D[2019-02-21 Calendrical.Fiscal.US])

      iex> Calendrical.Interval.day 2019, 92, Calendrical.NRF
      Date.range(~D[2019-W14-1 Calendrical.NRF], ~D[2019-W14-1 Calendrical.NRF])

      iex> Calendrical.Interval.day 2019, 8, Calendrical.ISOWeek
      Date.range(~D[2019-W02-1 Calendrical.ISOWeek], ~D[2019-W02-1 Calendrical.ISOWeek])

  """
  @spec day(Calendar.year(), Calendar.day(), Calendrical.calendar()) ::
          Date.Range.t() | {:error, :invalid_date}
  @spec day(Date.t()) :: Date.Range.t()

  def day(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> day()
    |> coerce_iso_calendar()
  end

  def day(date) do
    Date.range(date, date)
  end

  # The day is counted through the year's own range, which every
  # calendar answers, where `first_gregorian_day_of_year/1` is only the
  # month and week compilers' own.
  def day(year, day, calendar \\ Calendrical.Gregorian) do
    with %Date.Range{first_in_iso_days: first, last_in_iso_days: last} <- calendar.year(year) do
      day_of_the_year(first + day - 1, day, last, calendar)
    end
  end

  defp day_of_the_year(iso_days, day, last, calendar) when day >= 1 and iso_days <= last do
    {year, month, day} = calendar.date_from_iso_days(iso_days)

    with {:ok, date} <- Date.new(year, month, day, calendar) do
      day(date)
    end
  end

  defp day_of_the_year(_iso_days, _day, _last, _calendar), do: {:error, :invalid_date}

  @doc """
  Compares two date ranges and returns the Allen-algebra relation between
  them.

  Uses [Allen's Interval Algebra](https://en.wikipedia.org/wiki/Allen%27s_interval_algebra)
  to return one of 13 different relationships:

  Relation       | Converse
  -------------- | --------------
  `:precedes`    | `:preceded_by`
  `:meets`       | `:met_by`
  `:overlaps`    | `:overlapped_by`
  `:finished_by` | `:finishes`
  `:contains`    | `:during`
  `:starts`      | `:started_by`
  `:equals`      | `:equals`

  ### Arguments

  * `range_1` is a `t:Date.Range.t/0`.

  * `range_2` is a `t:Date.Range.t/0`.

  ### Returns

  * An atom representing the relationship of `range_1` to `range_2`.

  ### Examples

      iex> Calendrical.Interval.compare Calendrical.Interval.day(~D[2019-01-01]),
      ...> Calendrical.Interval.day(~D[2019-01-02])
      :meets

      iex> Calendrical.Interval.compare Calendrical.Interval.day(~D[2019-01-01]),
      ...> Calendrical.Interval.day(~D[2019-01-03])
      :precedes

      iex> Calendrical.Interval.compare Calendrical.Interval.day(~D[2019-01-03]),
      ...> Calendrical.Interval.day(~D[2019-01-01])
      :preceded_by

      iex> Calendrical.Interval.compare Calendrical.Interval.day(~D[2019-01-02]),
      ...> Calendrical.Interval.day(~D[2019-01-01])
      :met_by

      iex> Calendrical.Interval.compare Calendrical.Interval.day(~D[2019-01-02]),
      ...> Calendrical.Interval.day(~D[2019-01-02])
      :equals

  """
  @spec compare(range_1 :: Date.Range.t(), range_2 :: Date.Range.t()) ::
          Calendrical.interval_relation()

  def compare(
        %Date.Range{first_in_iso_days: first, last_in_iso_days: last},
        %Date.Range{first_in_iso_days: first, last_in_iso_days: last}
      ) do
    :equals
  end

  def compare(%Date.Range{} = r1, %Date.Range{} = r2) do
    cond do
      r1.last_in_iso_days - r2.first_in_iso_days < -1 ->
        :precedes

      r1.last_in_iso_days - r2.first_in_iso_days == -1 ->
        :meets

      r1.first_in_iso_days < r2.first_in_iso_days && r1.last_in_iso_days > r2.last_in_iso_days ->
        :contains

      r1.last_in_iso_days == r2.last_in_iso_days && r1.first_in_iso_days < r2.first_in_iso_days ->
        :finished_by

      r1.first_in_iso_days == r2.first_in_iso_days && r1.last_in_iso_days < r2.last_in_iso_days ->
        :starts

      r2.last_in_iso_days - r1.first_in_iso_days < -1 ->
        :preceded_by

      r2.last_in_iso_days - r1.first_in_iso_days == -1 ->
        :met_by

      r2.last_in_iso_days == r1.last_in_iso_days && r2.first_in_iso_days < r1.first_in_iso_days ->
        :finishes

      r1.first_in_iso_days > r2.first_in_iso_days && r1.last_in_iso_days < r2.last_in_iso_days ->
        :during

      r2.first_in_iso_days == r1.first_in_iso_days && r1.last_in_iso_days > r2.last_in_iso_days ->
        :started_by

      r1.first_in_iso_days < r2.first_in_iso_days && r1.last_in_iso_days >= r2.first_in_iso_days ->
        :overlaps

      r2.last_in_iso_days >= r1.first_in_iso_days && r2.last_in_iso_days < r1.last_in_iso_days ->
        :overlapped_by
    end
  end

  @doc false
  def to_iso_calendar(%Date.Range{first: first, last: last}) do
    Date.range(Date.convert!(first, Calendar.ISO), Date.convert!(last, Calendar.ISO))
  end

  @doc false
  def coerce_iso_calendar(%Date.Range{first: first, last: last}) do
    first = %{first | calendar: Calendar.ISO}
    last = %{last | calendar: Calendar.ISO}
    Date.range(first, last)
  end
end
