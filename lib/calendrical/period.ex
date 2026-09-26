defmodule Calendrical.Period do
  @moduledoc false

  # The quarters, quadrimesters and semesters of a year: runs of 3, 4 or 6
  # of its twelve traditional months, each ending where the next begins.
  # A calendar with leap months places them through
  # `ordinal_month_from_traditional/2`, so a leap month falls in the period
  # of the month it repeats (the Hebrew Adar I in the second quarter,
  # beside Adar II), and a month beyond the twelfth (the Coptic and
  # Ethiopic epagomenal month) falls in the last period. Each period spans
  # the calendar's own `month/2` ranges, so a week-based calendar's periods
  # are its months' weeks.

  @traditional_months_in_year 12

  @doc false
  # The dates of the year's `period_number`th period of `months_per_period`
  # months.
  @spec date_range(module(), Calendar.year(), pos_integer(), pos_integer()) ::
          Date.Range.t() | {:error, :not_defined | :invalid_date}
  def date_range(calendar, year, period_number, months_per_period) do
    with {:ok, first..last//1} <-
           ordinal_month_span(calendar, year, period_number, months_per_period),
         %Date.Range{first: first_date} <- calendar.month(year, first),
         %Date.Range{last: last_date} <- calendar.month(year, last) do
      Date.range(first_date, last_date)
    end
  end

  @doc false
  # The number of the period of `months_per_period` months that holds the
  # ordinal `month`.
  @spec period_number_of_month(module(), Calendar.year(), Calendar.month(), pos_integer()) ::
          pos_integer() | {:error, :invalid_date}
  def period_number_of_month(calendar, year, month, months_per_period) do
    1..periods_in_year(months_per_period)
    |> Enum.find(&period_holds_month?(calendar, year, &1, months_per_period, month))
    |> period_number_or_error()
  end

  defp period_holds_month?(calendar, year, period_number, months_per_period, month) do
    case ordinal_month_span(calendar, year, period_number, months_per_period) do
      {:ok, ordinal_months} -> month in ordinal_months
      {:error, _reason} -> false
    end
  end

  defp period_number_or_error(nil), do: {:error, :invalid_date}
  defp period_number_or_error(period_number), do: period_number

  defp ordinal_month_span(calendar, year, period_number, months_per_period) do
    periods_in_year = periods_in_year(months_per_period)

    if period_number in 1..periods_in_year do
      first_traditional_month = (period_number - 1) * months_per_period + 1

      with {:ok, first} <-
             ordinal_month_from_traditional(calendar, year, first_traditional_month),
           {:ok, last} <-
             last_ordinal_month(
               calendar,
               year,
               period_number,
               periods_in_year,
               months_per_period
             ) do
        {:ok, first..last//1}
      end
    else
      {:error, :invalid_date}
    end
  end

  # The last period runs to the year's last month, so it takes a month
  # beyond the twelfth; any other period ends where the next begins.
  defp last_ordinal_month(calendar, year, periods_in_year, periods_in_year, _months_per_period),
    do: {:ok, calendar.months_in_year(year)}

  defp last_ordinal_month(calendar, year, period_number, _periods_in_year, months_per_period) do
    next_traditional_month = period_number * months_per_period + 1

    with {:ok, next_first} <-
           ordinal_month_from_traditional(calendar, year, next_traditional_month) do
      {:ok, next_first - 1}
    end
  end

  # The ordinal position of a traditional month: the same number in a
  # calendar without leap months.
  defp ordinal_month_from_traditional(calendar, year, traditional_month) do
    if Code.ensure_loaded?(calendar) and
         function_exported?(calendar, :ordinal_month_from_traditional, 2) do
      calendar.ordinal_month_from_traditional(year, traditional_month)
    else
      {:ok, traditional_month}
    end
  end

  defp periods_in_year(months_per_period),
    do: div(@traditional_months_in_year, months_per_period)
end
