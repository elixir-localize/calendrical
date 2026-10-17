defmodule Calendrical.Base.Bounds do
  @moduledoc false

  # The fewest and the most of a count no year is given for: the months a
  # year has (`months_in_year_bounds/0`) and the days a month has
  # (`days_in_month_bounds/1`), as `{fewest, most}`, which every calendar
  # answers through `Calendrical.Compiler.StandardCallbacks`.
  #
  # A calendar already says the count where it is the same in every year,
  # and `{:ambiguous, counts}` where it varies (`months_in_year/0`,
  # `days_in_month/1`); the bounds are those answers read as a pair. A
  # composite calendar says neither, since a year a change of calendar cuts
  # short has fewer of each: its bounds are its members' bounds widened by
  # the counts of the years the changes fall in.

  # The bounds of the months a year has.
  def months_in_year_bounds(calendar) do
    bounds(calendar.months_in_year(), fn -> ordinary_and_leap_months(calendar) end)
  end

  # The bounds of the days a month has: `{:error, :undefined}` where the
  # calendar cannot say without a year, and an error naming the month
  # where the calendar has no such month in any year.
  def days_in_month_bounds(calendar, month) when is_integer(month) and month >= 1 do
    bounds(calendar.days_in_month(month), fn -> undefined_month(calendar, month) end)
  end

  def days_in_month_bounds(calendar, month), do: {:error, no_such_month(calendar, month)}

  # A composite calendar's bounds: its members', widened by the years the
  # changes of calendar fall in, which can have fewer months, or more, than
  # any member's year.
  def months_in_year_bounds(calendar, members, transition_years) do
    members
    |> Enum.map(& &1.months_in_year_bounds())
    |> combine(Enum.map(transition_years, &months_in(calendar, &1)))
  end

  def days_in_month_bounds(calendar, members, transition_years, month)
      when is_integer(month) and month >= 1 do
    members
    |> Enum.map(& &1.days_in_month_bounds(month))
    |> combine(Enum.map(transition_years, &calendar.days_in_month(&1, month)))
    |> month_bounds(calendar, month)
  end

  def days_in_month_bounds(calendar, _members, _transition_years, month),
    do: {:error, no_such_month(calendar, month)}

  defp bounds(count, _undefined) when is_integer(count), do: {count, count}
  defp bounds({:ambiguous, counts}, _undefined), do: {Enum.min(counts), Enum.max(counts)}
  defp bounds({:error, :undefined}, undefined), do: undefined.()
  defp bounds({:error, _exception} = error, _undefined), do: error

  # A calendar made with `use Calendrical.Calendar` says how many months
  # its ordinary and its leap years have.
  defp ordinary_and_leap_months(calendar) do
    if function_exported?(calendar, :months_in_ordinary_year, 0) and
         function_exported?(calendar, :months_in_leap_year, 0) do
      bounds(
        {:ambiguous, [calendar.months_in_ordinary_year(), calendar.months_in_leap_year()]},
        fn -> {:error, :undefined} end
      )
    else
      {:error, :undefined}
    end
  end

  # A month's length is undefined without a year where the month is one the
  # calendar has; a month beyond its most is no month of the calendar.
  defp undefined_month(calendar, month) do
    case months_in_year_bounds(calendar) do
      {:error, _reason} = error -> error
      {_fewest, most} when month <= most -> {:error, :undefined}
      {_fewest, _most} -> {:error, no_such_month(calendar, month)}
    end
  end

  defp month_bounds({:error, :undefined}, calendar, month),
    do: {:error, no_such_month(calendar, month)}

  defp month_bounds(bounds, _calendar, _month), do: bounds

  # The number of months a year of a composite calendar has: those with
  # days, which a year a change of calendar cuts short has fewer of.
  defp months_in(calendar, year) do
    calendar.month_numbers(year) |> Enum.map(&Range.size/1) |> Enum.sum()
  end

  # The bounds that hold every pair of bounds and every count, where a
  # member that cannot answer and a year with none are left out.
  defp combine(member_bounds, counts) do
    pairs =
      Enum.filter(
        member_bounds,
        &match?({fewest, most} when is_integer(fewest) and is_integer(most), &1)
      )

    counts = Enum.filter(counts, &(is_integer(&1) and &1 > 0))

    case Enum.map(pairs, &elem(&1, 0)) ++ counts do
      [] -> {:error, :undefined}
      fewest -> {Enum.min(fewest), Enum.max(Enum.map(pairs, &elem(&1, 1)) ++ counts)}
    end
  end

  defp no_such_month(calendar, month) do
    Calendrical.InvalidMonthError.exception(calendar: calendar, month: month)
  end
end
