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
  Returns a `t:Date.Range.t/0` that represents the year containing
  `date`.

  The range is enumerable.

  ### Arguments

  * `date` is any `t:Calendar.date/0`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    year containing `date`, in `date`'s calendar, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` for a date with no
    year.

  ### Examples

      iex> Calendrical.Interval.year(~D[2019-06-15])
      Date.range(~D[2019-01-01], ~D[2019-12-31])

  """
  @spec year(Date.t()) :: Date.Range.t() | Calendrical.date_error()

  def year(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> year
    |> coerce_iso_calendar
  end

  # A year needs only the date's year, so a partial date has its year; a
  # whole date is first checked to be one its calendar has.
  def year(%{year: year, month: month, day: day, calendar: calendar}) do
    if is_integer(year) and is_integer(month) and is_integer(day) and
         not calendar.valid_date?(year, month, day),
       do: invalid_date(calendar, {year, month, day}),
       else: year(year, calendar)
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `year`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `year`.

  ### Examples

      iex> {:ok, _} = Calendrical.new(MyApp.FiscalUK, :month, year_begins: {4, 1}, year_number: :majority)
      iex> Calendrical.Interval.year 2019, MyApp.FiscalUK
      Date.range(Date.new!(2019, 1, 1, MyApp.FiscalUK), Date.new!(2019, 12, 31, MyApp.FiscalUK))

      iex> Calendrical.Interval.year 2019, Calendrical.NRF
      Date.range(~D[2019-W01-1 Calendrical.NRF], ~D[2019-W52-7 Calendrical.NRF])

  """
  @spec year(Calendar.year(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def year(year, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.year(year))
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the quarter containing
  `date`.

  The range is enumerable.

  ### Arguments

  * `date` is any `t:Calendar.date/0`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    quarter containing `date`, in `date`'s calendar.

  * `{:error, exception}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Interval.quarter(~D[2019-06-15])
      Date.range(~D[2019-04-01], ~D[2019-06-30])

  """
  @spec quarter(Date.t()) ::
          Date.Range.t() | Calendrical.date_error()

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

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `quarter`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `quarter` is any `quarter` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `quarter`.

  ### Examples

      iex> {:ok, _} = Calendrical.new(MyApp.FiscalUK, :month, year_begins: {4, 1}, year_number: :majority)
      iex> Calendrical.Interval.quarter 2019, 2, MyApp.FiscalUK
      Date.range(Date.new!(2019, 4, 1, MyApp.FiscalUK), Date.new!(2019, 6, 30, MyApp.FiscalUK))

      iex> Calendrical.Interval.quarter 2019, 2, Calendrical.ISOWeek
      Date.range(~D[2019-W14-1 Calendrical.ISOWeek], ~D[2019-W26-7 Calendrical.ISOWeek])

  """
  @spec quarter(Calendar.year(), Calendrical.quarter(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def quarter(year, quarter, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.quarter(year, quarter))
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `quadrimester`
  (third of the year).

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `quadrimester` is `1`, `2` or `3`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    `quadrimester`, or

  * `{:error, exception}` for a quadrimester the year does not have.

  ### Examples

      iex> Calendrical.Interval.quadrimester 2026, 2
      Date.range(~D[2026-05-01 Calendrical.Gregorian], ~D[2026-08-31 Calendrical.Gregorian])

  """
  @spec quadrimester(Calendar.year(), Calendrical.quadrimester(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def quadrimester(year, quadrimester, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.quadrimester(year, quadrimester))
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `semester`
  (half of the year).

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `semester` is `1` or `2`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    `semester`, or

  * `{:error, exception}` for a semester the year does not have.

  ### Examples

      iex> Calendrical.Interval.semester 2026, 2
      Date.range(~D[2026-07-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

  """
  @spec semester(Calendar.year(), Calendrical.semester(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def semester(year, semester, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.semester(year, semester))
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the month containing
  `date`.

  The range is enumerable.

  ### Arguments

  * `date` is any `t:Calendar.date/0`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    month containing `date`, in `date`'s calendar.

  * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` for a date missing a
    field.

  ### Examples

      iex> Calendrical.Interval.month(~D[2019-06-15])
      Date.range(~D[2019-06-01], ~D[2019-06-30])

  """
  @spec month(Date.t()) :: Date.Range.t() | Calendrical.date_error()

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
    with :ok <- whole_date(date, "month") do
      iso_days = Date.to_gregorian_days(date)
      candidates = Enum.uniq([Calendrical.month_of_year(date), date.month])

      Enum.find_value(candidates, &holding_month(date, &1, iso_days)) ||
        Enum.find_value(1..months_in_year(date)//1, &holding_month(date, &1, iso_days)) ||
        invalid_date(date.calendar, {date.year, date.month, date.day})
    end
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

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `month`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `month` is any `month` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `month`.

  ### Examples

      iex> {:ok, _} = Calendrical.new(MyApp.FiscalUK, :month, year_begins: {4, 1}, year_number: :majority)
      iex> Calendrical.Interval.month 2019, 3, MyApp.FiscalUK
      Date.range(Date.new!(2019, 3, 1, MyApp.FiscalUK), Date.new!(2019, 3, 30, MyApp.FiscalUK))

      iex> {:ok, _} =
      ...>   Calendrical.new(MyApp.FiscalUS, :month,
      ...>     year_begins: {10, 1},
      ...>     year_number: :majority,
      ...>     weeks: [first_day: 7, min_days_in_first_week: 4]
      ...>   )
      iex> Calendrical.Interval.month 2019, 3, MyApp.FiscalUS
      Date.range(Date.new!(2019, 3, 1, MyApp.FiscalUS), Date.new!(2019, 3, 31, MyApp.FiscalUS))

  """
  @spec month(Calendar.year(), Calendar.month(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def month(year, month, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.month(year, month))
  end

  defp holds?(%Date.Range{first_in_iso_days: first, last_in_iso_days: last}, iso_days),
    do: first <= iso_days and iso_days <= last

  defp holds?(_not_a_range, _iso_days), do: false

  @doc """
  Returns a `t:Date.Range.t/0` that represents the week containing
  `date`.

  The range is enumerable.

  ### Arguments

  * `date` is any `t:Calendar.date/0`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    week containing `date`, in `date`'s calendar.

  * `{:error, exception}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Interval.week(~D[2019-06-15])
      Date.range(~D[2019-06-10], ~D[2019-06-16])

  """
  @spec week(Date.t()) :: Date.Range.t() | Calendrical.date_error()

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

  @doc """
  Returns a `t:Date.Range.t/0` that represents the `week`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `week` is any `week` in the `year` for `calendar`.

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the `week`, or

  * `{:error, exception}` for a week the year does not have.

  ### Examples

      iex> {:ok, _} =
      ...>   Calendrical.new(MyApp.FiscalUS, :month,
      ...>     year_begins: {10, 1},
      ...>     year_number: :majority,
      ...>     weeks: [first_day: 7, min_days_in_first_week: 4]
      ...>   )
      iex> Calendrical.Interval.week 2019, 52, MyApp.FiscalUS
      Date.range(Date.new!(2019, 12, 22, MyApp.FiscalUS), Date.new!(2019, 12, 28, MyApp.FiscalUS))

      iex> Calendrical.Interval.week 2019, 52, Calendrical.NRF
      Date.range(~D[2019-W52-1 Calendrical.NRF], ~D[2019-W52-7 Calendrical.NRF])

      iex> Calendrical.Interval.week 2019, 52, Calendrical.ISOWeek
      Date.range(~D[2019-W52-1 Calendrical.ISOWeek], ~D[2019-W52-7 Calendrical.ISOWeek])

      iex> Calendrical.Interval.week 2019, 52, Calendrical.Julian
      Date.range(~D[2019-12-24 Calendrical.Julian], ~D[2019-12-30 Calendrical.Julian])

  """
  @spec week(Calendar.year(), Calendrical.week(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def week(year, week, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, & &1.week(year, week))
  end

  @doc """
  Returns a `t:Date.Range.t/0` that represents the day containing
  `date`.

  The range is enumerable.

  ### Arguments

  * `date` is any `t:Calendar.date/0`.

  ### Returns

  * A `t:Date.Range.t/0` representing the enumerable days in the
    day containing `date`, in `date`'s calendar, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` for a date missing a
    field.

  ### Examples

      iex> Calendrical.Interval.day(~D[2019-06-15])
      Date.range(~D[2019-06-15], ~D[2019-06-15])

  """
  @spec day(Date.t()) :: Date.Range.t() | Calendrical.date_error()

  def day(%{calendar: Calendar.ISO} = date) do
    %{date | calendar: Calendrical.Gregorian}
    |> day()
    |> coerce_iso_calendar()
  end

  def day(date) do
    with :ok <- whole_date(date, "day") do
      Date.range(date, date)
    end
  end

  # A date the interval is found from has every field and is one its
  # calendar has.
  defp whole_date(%{year: year, month: month, day: day, calendar: calendar}, function) do
    cond do
      not (is_integer(year) and is_integer(month) and is_integer(day)) ->
        {:error, Calendrical.missing_date_error(function, year, month, day)}

      calendar.valid_date?(year, month, day) ->
        :ok

      true ->
        invalid_date(calendar, {year, month, day})
    end
  end

  # The day is counted through the year's own range, which every
  # calendar answers, where `first_gregorian_day_of_year/1` is only the
  # month and week compilers' own.
  @doc """
  Returns a `t:Date.Range.t/0` containing a single `day`.

  The range is enumerable.

  ### Arguments

  * `year` is any `year` for `calendar`.

  * `day` is any `day` in the `year` for `calendar` (the ordinal day of year).

  * `calendar` is any module that implements the `Calendar` and `Calendrical`
    behaviours, or `Calendar.ISO`, which answers as `Calendrical.Gregorian`
    with dates in `Calendar.ISO`. The default is `Calendrical.Gregorian`.

  ### Returns

  * A `t:Date.Range.t/0` containing the single requested day, or

  * `{:error, %Calendrical.InvalidDateError{}}` if `day` is greater than
    the number of days in the year.

  ### Examples

      iex> {:ok, _} =
      ...>   Calendrical.new(MyApp.FiscalUS, :month,
      ...>     year_begins: {10, 1},
      ...>     year_number: :majority,
      ...>     weeks: [first_day: 7, min_days_in_first_week: 4]
      ...>   )
      iex> Calendrical.Interval.day 2019, 52, MyApp.FiscalUS
      Date.range(Date.new!(2019, 2, 21, MyApp.FiscalUS), Date.new!(2019, 2, 21, MyApp.FiscalUS))

      iex> Calendrical.Interval.day 2019, 92, Calendrical.NRF
      Date.range(~D[2019-W14-1 Calendrical.NRF], ~D[2019-W14-1 Calendrical.NRF])

      iex> Calendrical.Interval.day 2019, 8, Calendrical.ISOWeek
      Date.range(~D[2019-W02-1 Calendrical.ISOWeek], ~D[2019-W02-1 Calendrical.ISOWeek])

  """
  @spec day(Calendar.year(), Calendar.day(), Calendrical.calendar()) ::
          Date.Range.t() | Calendrical.date_error()
  def day(year, day, calendar \\ Calendrical.Gregorian) do
    in_calendar(calendar, &day_in_year(&1, year, day))
  end

  # The ordinal day is counted through the year's own range; a day that is
  # missing is reported as the year is, and one that is no ordinal is no date.
  defp day_in_year(_calendar, year, nil),
    do:
      {:error,
       Calendrical.MissingFieldsError.exception(function: "day", fields: [year: year, day: nil])}

  defp day_in_year(calendar, year, day) when not is_integer(day),
    do: invalid_date(calendar, year: year, day_of_year: day)

  defp day_in_year(calendar, year, day) do
    with %Date.Range{first_in_iso_days: first, last_in_iso_days: last} <- calendar.year(year) do
      day_of_the_year(first + day - 1, day, last, calendar, year)
    end
  end

  defp day_of_the_year(iso_days, day, last, calendar, _year) when day >= 1 and iso_days <= last do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    day(%Date{year: year, month: month, day: day, calendar: calendar})
  end

  defp day_of_the_year(_iso_days, day, _last, calendar, year),
    do: invalid_date(calendar, year: year, day_of_year: day)

  defp invalid_date(calendar, value) do
    {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: value)}
  end

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

  def coerce_iso_calendar({:error, _reason} = error), do: error

  # `Calendar.ISO` answers as `Calendrical.Gregorian`, whose dates are its
  # dates, as the date forms of these functions treat it.
  defp in_calendar(Calendar.ISO, interval),
    do: Calendrical.Gregorian |> interval.() |> coerce_iso_calendar()

  defp in_calendar(calendar, interval), do: interval.(calendar)
end
