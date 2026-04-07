defmodule Calendrical.Islamic.Tabular do
  @moduledoc false

  # Shared algorithms for the tabular Hijri (Islamic) calendars defined in
  # `Calendrical.Islamic.Civil` and `Calendrical.Islamic.Tbla`. The two
  # calendars use the same arithmetic month structure and the same 30-year
  # leap-year cycle and differ only in their epoch (Civil = Friday 16 July
  # 622 Julian, Tbla = Thursday 15 July 622 Julian).
  #
  # Algorithms are taken from Dershowitz & Reingold, *Calendrical
  # Calculations* (4th ed.), Chapter 7, "The Islamic Calendar".

  @doc """
  Returns whether the given Hijri `year` is a leap year under the standard
  Type II ("Kūshyār") 30-year cycle. Years 2, 5, 7, 10, 13, 16, 18, 21,
  24, 26, and 29 of each cycle are leap years (354 → 355 days).
  """
  @spec leap_year?(integer()) :: boolean()
  def leap_year?(year) do
    Integer.mod(14 + 11 * year, 30) < 11
  end

  @doc """
  Returns the number of days in the given `month` of the given `year`.

  Months 1, 3, 5, 7, 9, and 11 always have 30 days; months 2, 4, 6, 8,
  and 10 always have 29 days; month 12 (Dhū al-Ḥijja) has 29 days in an
  ordinary year and 30 days in a leap year.
  """
  @spec days_in_month(integer(), 1..12) :: 29..30
  def days_in_month(year, 12) do
    if leap_year?(year), do: 30, else: 29
  end

  def days_in_month(_year, month) when month in [1, 3, 5, 7, 9, 11] do
    30
  end

  def days_in_month(_year, month) when month in [2, 4, 6, 8, 10] do
    29
  end

  @doc """
  Converts a tabular Islamic date to an ISO day number using the supplied
  `epoch` (in ISO days).
  """
  @spec date_to_iso_days(integer(), 1..12, 1..30, integer()) :: integer()
  def date_to_iso_days(year, month, day, epoch) do
    epoch - 1 +
      354 * (year - 1) +
      div(3 + 11 * year, 30) +
      29 * (month - 1) +
      div(month, 2) +
      day
  end

  @doc """
  Converts an ISO day number to a tabular Islamic `{year, month, day}`
  using the supplied `epoch` (in ISO days).
  """
  @spec date_from_iso_days(integer(), integer()) :: {integer(), 1..12, 1..30}
  def date_from_iso_days(iso_days, epoch) do
    year = div(30 * (iso_days - epoch) + 10646, 10631)
    prior_days = iso_days - date_to_iso_days(year, 1, 1, epoch)
    month = div(11 * prior_days + 330, 325)
    day = iso_days - date_to_iso_days(year, month, 1, epoch) + 1
    {year, month, day}
  end
end
