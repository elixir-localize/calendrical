defmodule Calendrical.Period do
  @moduledoc """
  The periods of a calendar's year, computed for every calendar from its
  kernel: the days of a year and of a month, the quarters, quadrimesters
  and semesters, the day of the year and the days a year has.

  A quarter, quadrimester or semester is a run of 3, 4 or 6 of the twelve
  traditional months, each ending where the next begins. A calendar with
  leap months places them through `Calendrical.Month.month_from_traditional/3`,
  so a leap month falls in the period of the month it repeats (the Hebrew
  Adar I in the second quarter, beside Adar II), and a month beyond the
  twelfth (the Coptic and Ethiopic epagomenal month) falls in the last
  period. Each period spans the calendar's own months, so a week-based
  calendar's periods are its months' weeks.

  """

  @traditional_months_in_year 12

  # The name of a period of a year by the months in it, for an error that
  # names the period.
  @period_names %{3 => :quarter, 4 => :quadrimester, 6 => :semester}

  @typedoc "A calendar module."
  @type calendar :: module()

  @doc """
  Returns the days of a year as a `t:Date.Range.t/0`: from the first day
  the year has to the last, so a composite calendar's year that begins or
  ends with a change of calendar is the days it has of its own.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, %Calendrical.InvalidDateError{}}` for a year the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for no year.

  ### Examples

      iex> Calendrical.Period.year(Calendrical.Gregorian, 2026)
      Date.range(~D[2026-01-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

      iex> Calendrical.Period.year(Calendrical.Reform.England, 1751)
      Date.range(~D[1751-03-25 Calendrical.Reform.England], ~D[1751-12-31 Calendrical.Reform.England])

      iex> Calendrical.Period.year(Calendrical.Julian, 0)
      {:error, %Calendrical.InvalidDateError{calendar: Calendrical.Julian, value: [year: 0]}}

  """
  @spec year(calendar, Calendar.year()) ::
          Date.Range.t() | {:error, Exception.t()}
  def year(calendar, year) when is_integer(year) do
    if Calendrical.Base.Common.composite?(calendar) do
      case Calendrical.Month.month_numbers(calendar, year) do
        [] -> invalid_date(calendar, year: year)
        months -> days_between(calendar, year, List.first(months).first, List.last(months).last)
      end
    else
      with {:ok, first} <- first_day(calendar, year, 1, year: year),
           {:ok, last} <- last_day(calendar, year, calendar.months_in_year(year), year: year) do
        Date.range(first, last)
      end
    end
  end

  def year(calendar, year), do: missing_or_invalid(calendar, "year", year: year)

  @doc """
  Returns the days of a month of a year as a `t:Date.Range.t/0`: from the
  first day the month has to the last.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, %Calendrical.InvalidDateError{}}` for a month the
    year does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for a missing year or month.

  ### Examples

      iex> Calendrical.Period.month(Calendrical.Gregorian, 2026, 2)
      Date.range(~D[2026-02-01 Calendrical.Gregorian], ~D[2026-02-28 Calendrical.Gregorian])

      iex> Calendrical.Period.month(Calendrical.Gregorian, 2026, 13)
      {:error, %Calendrical.InvalidDateError{calendar: Calendrical.Gregorian, value: [year: 2026, month: 13]}}

  """
  @spec month(calendar, Calendar.year(), Calendar.month()) ::
          Date.Range.t() | {:error, Exception.t()}
  def month(calendar, year, month) when is_integer(year) and is_integer(month) do
    if Calendrical.Base.Common.composite?(calendar) do
      days_between(calendar, year, month, month)
    else
      with {:ok, first} <- first_day(calendar, year, month, year: year, month: month),
           {:ok, last} <- last_day(calendar, year, month, year: year, month: month) do
        Date.range(first, last)
      end
    end
  end

  def month(calendar, year, month),
    do: missing_or_invalid(calendar, "month", year: year, month: month)

  @doc """
  Returns the days of a quarter of a year, three months each, as a
  `t:Date.Range.t/0`: a leap month falls in the quarter of the month it
  repeats, and a month beyond the twelfth in the last.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `quarter` is 1 to 4.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, %Calendrical.InvalidDateError{}}` for a quarter or a
    year the calendar does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
    quarter is `nil`.

  ### Examples

      iex> Calendrical.Period.quarter(Calendrical.Gregorian, 2026, 4)
      Date.range(~D[2026-10-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

  """
  @spec quarter(calendar, Calendar.year(), 1..4) :: Date.Range.t() | Calendrical.date_error()
  def quarter(calendar, year, quarter) when is_integer(year) and is_integer(quarter),
    do: date_range(calendar, year, quarter, 3)

  def quarter(calendar, year, quarter),
    do: missing_or_invalid(calendar, "quarter", year: year, quarter: quarter)

  @doc """
  Returns the days of a quadrimester of a year, four months each, as a
  `t:Date.Range.t/0` (see `quarter/3`).

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `quadrimester` is 1 to 3.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, %Calendrical.InvalidDateError{}}`, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where a field is `nil`.

  ### Examples

      iex> Calendrical.Period.quadrimester(Calendrical.Gregorian, 2026, 3)
      Date.range(~D[2026-09-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

  """
  @spec quadrimester(calendar, Calendar.year(), 1..3) :: Date.Range.t() | Calendrical.date_error()
  def quadrimester(calendar, year, quadrimester)
      when is_integer(year) and is_integer(quadrimester),
      do: date_range(calendar, year, quadrimester, 4)

  def quadrimester(calendar, year, quadrimester),
    do: missing_or_invalid(calendar, "quadrimester", year: year, quadrimester: quadrimester)

  @doc """
  Returns the days of a semester of a year, six months each, as a
  `t:Date.Range.t/0` (see `quarter/3`).

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `semester` is 1 or 2.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, %Calendrical.InvalidDateError{}}`, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where a field is `nil`.

  ### Examples

      iex> Calendrical.Period.semester(Calendrical.Gregorian, 2026, 2)
      Date.range(~D[2026-07-01 Calendrical.Gregorian], ~D[2026-12-31 Calendrical.Gregorian])

  """
  @spec semester(calendar, Calendar.year(), 1..2) :: Date.Range.t() | Calendrical.date_error()
  def semester(calendar, year, semester) when is_integer(year) and is_integer(semester),
    do: date_range(calendar, year, semester, 6)

  def semester(calendar, year, semester),
    do: missing_or_invalid(calendar, "semester", year: year, semester: semester)

  @doc """
  Returns the quarter of the year a date falls in: the quarter of its
  month (see `quarter/3`), which needs no day beyond one the month reaches.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * 1 to 4, or `{:error, %Calendrical.InvalidDateError{}}` for a month the year does not
    have, or `{:error, Calendrical.MissingFieldsError.t()}` for a missing
    year or month.

  ### Examples

      iex> Calendrical.Period.quarter_of_year(Calendrical.Gregorian, 2026, 11, 15)
      4

      iex> Calendrical.Period.quarter_of_year(Calendrical.Hebrew, 5784, 7, 1)
      2

  """
  @spec quarter_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          1..4 | {:error, Exception.t()}
  # A quarter needs only the year and the month: with no day, the month
  # need only have days in the year.
  def quarter_of_year(calendar, year, month, day) when is_integer(year) and is_integer(month) do
    if Calendrical.Month.day_in_month?(calendar, year, month, day || 1),
      do: period_number_of_month(calendar, year, month, 3),
      else: invalid_date(calendar, year: year, month: month)
  end

  def quarter_of_year(calendar, year, month, _day),
    do: missing_or_invalid(calendar, "quarter_of_year", year: year, month: month)

  @doc """
  Returns the day of the year of a date: 1 on the first day the year has.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * A positive integer, or `{:error, %Calendrical.InvalidDateError{}}` for a date the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for a missing field.

  ### Examples

      iex> Calendrical.Period.day_of_year(Calendrical.Gregorian, 2026, 3, 1)
      60

      # England's 1751 began on 25 March
      iex> Calendrical.Period.day_of_year(Calendrical.Reform.England, 1751, 4, 1)
      8

  """
  @spec day_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          pos_integer() | {:error, Exception.t()}
  def day_of_year(calendar, year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    with %Date.Range{first: first} <- year(calendar, year),
         {:ok, iso_days} <- iso_days(calendar, year, month, day) do
      iso_days - Date.to_gregorian_days(first) + 1
    end
  end

  def day_of_year(calendar, year, month, day),
    do: missing_or_invalid(calendar, "day_of_year", year: year, month: month, day: day)

  @doc """
  Returns the number of days a year has: the days from its first to its
  last, so a year that drops days in a change of calendar counts the days
  it has.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A positive integer, or `{:error, %Calendrical.InvalidDateError{}}` for a year the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for no year.

  ### Examples

      iex> Calendrical.Period.days_in_year(Calendrical.Gregorian, 2024)
      366

      # England dropped eleven days in 1752
      iex> Calendrical.Period.days_in_year(Calendrical.Reform.England, 1752)
      355

  """
  @spec days_in_year(calendar, Calendar.year()) ::
          pos_integer() | {:error, Exception.t()}
  def days_in_year(calendar, year) when is_integer(year) do
    with %Date.Range{first: first, last: last} <- year(calendar, year) do
      Date.to_gregorian_days(last) - Date.to_gregorian_days(first) + 1
    end
  end

  def days_in_year(calendar, year),
    do: missing_or_invalid(calendar, "days_in_year", year: year)

  # The first day of a month, and its last, in a calendar whose months run
  # from 1 to their length: one validation of the first day and one length,
  # since each may be a sighting of the moon.
  defp first_day(calendar, year, month, fields) when is_integer(month) do
    if calendar.valid_date?(year, month, 1),
      do: {:ok, %Date{year: year, month: month, day: 1, calendar: calendar}},
      else: invalid_date(calendar, fields)
  end

  defp last_day(calendar, year, month, fields) when is_integer(month) do
    case calendar.days_in_month(year, month) do
      days when is_integer(days) and days > 0 ->
        {:ok, %Date{year: year, month: month, day: days, calendar: calendar}}

      _no_such_month ->
        invalid_date(calendar, fields)
    end
  end

  # The days from the first day of one month to the last of another, as
  # the calendar has them.
  defp days_between(calendar, year, first_month, last_month) do
    first_days = Calendrical.Month.day_numbers(calendar, year, first_month)
    last_days = Calendrical.Month.day_numbers(calendar, year, last_month)

    if first_days == [] or last_days == [] do
      invalid_date(calendar,
        year: year,
        month: if(first_days == [], do: first_month, else: last_month)
      )
    else
      Date.range(
        Date.new!(year, first_month, List.first(first_days).first, calendar),
        Date.new!(year, last_month, List.last(last_days).last, calendar)
      )
    end
  end

  defp iso_days(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day),
      do: integer_days(calendar, calendar.date_to_iso_days(year, month, day), {year, month, day}),
      else: invalid_date(calendar, {year, month, day})
  end

  # A calendar's ISO day number may be a moment, which no whole day is.
  defp integer_days(_calendar, days, _date) when is_integer(days), do: {:ok, days}
  defp integer_days(calendar, _days, date), do: invalid_date(calendar, date)

  # A field that is missing is a missing field; one that is no integer
  # is no date's.
  defp missing_or_invalid(calendar, function, fields) do
    if Enum.any?(fields, fn {_field, value} -> is_nil(value) end),
      do: {:error, %Calendrical.MissingFieldsError{function: function, fields: fields}},
      else: invalid_date(calendar, fields)
  end

  defp invalid_date(calendar, value) do
    {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: value)}
  end

  @doc false
  # The dates of the year's `period_number`th period of `months_per_period`
  # months.
  @spec date_range(module(), Calendar.year(), pos_integer(), pos_integer()) ::
          Date.Range.t() | {:error, Exception.t()}
  def date_range(calendar, year, period_number, months_per_period) do
    with {:ok, first..last//1} <-
           ordinal_month_span(calendar, year, period_number, months_per_period) do
      range_of_months(calendar, year, first, last)
    end
  end

  defp range_of_months(calendar, year, first, last) do
    with %Date.Range{first: first_date} <- calendar.month(year, first),
         %Date.Range{last: last_date} <- calendar.month(year, last) do
      Date.range(first_date, last_date)
    end
  end

  @doc false
  # The number of the period of `months_per_period` months that holds the
  # ordinal `month`.
  @spec period_number_of_month(module(), Calendar.year(), Calendar.month(), pos_integer()) ::
          pos_integer() | {:error, Exception.t()}
  def period_number_of_month(calendar, year, month, months_per_period) do
    1..periods_in_year(months_per_period)
    |> Enum.find(&period_holds_month?(calendar, year, &1, months_per_period, month))
    |> period_number_or_error(calendar, year, month)
  end

  defp period_holds_month?(calendar, year, period_number, months_per_period, month) do
    case ordinal_month_span(calendar, year, period_number, months_per_period) do
      {:ok, ordinal_months} -> month in ordinal_months
      {:error, _reason} -> false
    end
  end

  defp period_number_or_error(nil, calendar, year, month),
    do: invalid_date(calendar, year: year, month: month)

  defp period_number_or_error(period_number, _calendar, _year, _month), do: period_number

  # The months of a year in a period: those whose traditional number falls
  # in the period's run of traditional months, the last period taking every
  # month beyond its run. A leap month carries the number of the month it
  # repeats, and a year a change of calendar shortens has the months it has.
  defp ordinal_month_span(calendar, year, period_number, months_per_period) do
    periods = periods_in_year(months_per_period)

    if is_integer(period_number) and period_number in 1..periods//1 do
      first = (period_number - 1) * months_per_period + 1
      last = if period_number == periods, do: :last, else: period_number * months_per_period

      case months_in_period(calendar, year, first, last) do
        [] -> invalid_date(calendar, period_fields(year, period_number, months_per_period))
        months -> {:ok, List.first(months)..List.last(months)//1}
      end
    else
      invalid_date(calendar, period_fields(year, period_number, months_per_period))
    end
  end

  defp period_fields(year, period_number, months_per_period) do
    [{:year, year}, {Map.fetch!(@period_names, months_per_period), period_number}]
  end

  defp months_in_period(calendar, year, first, last) do
    months = calendar |> Calendrical.Month.month_numbers(year) |> Enum.flat_map(&Enum.to_list/1)

    numbers =
      Enum.map(Calendrical.Month.traditional_months(calendar, year), &traditional_number/1)

    for {month, number} <- Enum.zip(months, numbers),
        number >= first and (last == :last or number <= last),
        do: month
  end

  defp traditional_number({number, :leap}), do: number
  defp traditional_number(number), do: number

  defp periods_in_year(months_per_period),
    do: div(@traditional_months_in_year, months_per_period)
end
