defmodule Calendrical.Bangla.Rules do
  @moduledoc false

  # The arithmetic the Bangla calendars share. Both revisions pin the year
  # to the Gregorian calendar: 1 Boishakh is 14 April, the year is the
  # Gregorian year it begins in less 593, and a year is a leap year when
  # the Gregorian year its Falgun falls in, the next one, is. They differ
  # only in their months' lengths, which each calendar passes in as a pair
  # of tuples, `{ordinary, leap}`.

  alias Calendrical.Gregorian

  @gregorian_offset 593
  @boishakh_1 {4, 14}
  @months_in_year 12

  @doc "The Gregorian year a Bangla year begins in."
  @spec gregorian_year(integer()) :: integer()
  def gregorian_year(year) do
    year + @gregorian_offset
  end

  @doc "Whether a Bangla year is a leap year: its Falgun falls in a Gregorian leap year."
  @spec leap_year?(integer()) :: boolean()
  def leap_year?(year) do
    Gregorian.leap_year?(gregorian_year(year) + 1)
  end

  @doc "The days in a month of a year, from the calendar's month lengths."
  @spec days_in_month({tuple(), tuple()}, integer(), 1..12) :: pos_integer()
  def days_in_month(month_lengths, year, month) do
    month_lengths
    |> lengths(year)
    |> elem(month - 1)
  end

  @doc "The ISO day number of a date."
  @spec date_to_iso_days({tuple(), tuple()}, integer(), 1..12, pos_integer()) :: integer()
  def date_to_iso_days(month_lengths, year, month, day) do
    table = lengths(month_lengths, year)
    boishakh_1(year) + days_before(table, month - 1, 0, 0) + day - 1
  end

  @doc "The date of an ISO day number."
  @spec date_from_iso_days({tuple(), tuple()}, integer()) :: {integer(), 1..12, pos_integer()}
  def date_from_iso_days(month_lengths, iso_days) do
    year = year_of(iso_days)
    table = lengths(month_lengths, year)
    {month, day} = month_and_day(table, 1, iso_days - boishakh_1(year) + 1)
    {year, month, day}
  end

  # The year a day is in: the one that began on the 14 April on or before it.
  defp year_of(iso_days) do
    {gregorian_year, _month, _day} = Gregorian.date_from_iso_days(iso_days)
    candidate = gregorian_year - @gregorian_offset

    if iso_days >= boishakh_1(candidate) do
      candidate
    else
      candidate - 1
    end
  end

  defp boishakh_1(year) do
    {month, day} = @boishakh_1
    Gregorian.date_to_iso_days(gregorian_year(year), month, day)
  end

  defp lengths({ordinary, leap}, year) do
    if leap_year?(year) do
      leap
    else
      ordinary
    end
  end

  # Explicit recursion keeps the sums integer-typed for Dialyzer.
  defp days_before(_table, count, count, sum) do
    sum
  end

  defp days_before(table, count, index, sum) do
    days_before(table, count, index + 1, sum + elem(table, index))
  end

  defp month_and_day(_table, @months_in_year, day_of_year) do
    {@months_in_year, day_of_year}
  end

  defp month_and_day(table, month, day_of_year) do
    length = elem(table, month - 1)

    if day_of_year <= length do
      {month, day_of_year}
    else
      month_and_day(table, month + 1, day_of_year - length)
    end
  end
end
