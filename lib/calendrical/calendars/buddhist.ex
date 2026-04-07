defmodule Calendrical.Buddhist do
  @moduledoc """
  Implementation of the Thai Buddhist (Buddhist Era) calendar.

  The Buddhist calendar shares its month and day structure with the
  proleptic Gregorian calendar exactly. The only difference is the
  *year numbering*: years are counted from the death (*parinirvana*) of
  Gautama Buddha, traditionally placed at **543 BCE** in the Gregorian
  calendar. The relation is:

      buddhist_year = gregorian_year + 543

  So 1 BE corresponds to proleptic Gregorian year **−542** (543 BCE in
  the historical "no year zero" convention) and modern Gregorian
  2026 CE corresponds to **2569 BE**.

  This calendar is the official solar calendar of Thailand, where it
  is used alongside the Gregorian calendar in everyday life.

  ## Month and day structure

  Months and days are identical to `Calendrical.Gregorian`. Leap years
  follow the proleptic Gregorian rule:

  > A year is a leap year if it is divisible by 4, except for centurial
  > years that are not divisible by 400.

  Day boundaries are at midnight, matching the Thai civil convention.

  ## Reference

  - CLDR `:buddhist` calendar type. The CLDR era data places 1 BE
    (`:be`) at proleptic Gregorian `−542-01-01`.
  - This module follows Reingold & Dershowitz's *Calendrical
    Calculations* (4th ed.) practice of treating year-shifted Gregorian
    variants as a thin wrapper around the Gregorian implementation.

  """

  use Calendrical.Behaviour,
    epoch: ~D[-0542-01-01 Calendrical.Gregorian],
    cldr_calendar_type: :buddhist,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..31

  @gregorian_offset 543

  @doc """
  Returns the offset (in years) between the Buddhist Era and the
  proleptic Gregorian calendar. `buddhist_year - gregorian_offset()`
  yields the corresponding Gregorian year.

  """
  @spec gregorian_offset() :: 543
  def gregorian_offset, do: @gregorian_offset

  @doc """
  Returns the Gregorian year corresponding to the given Buddhist year.

  """
  @spec gregorian_year(year) :: integer()
  def gregorian_year(buddhist_year), do: buddhist_year - @gregorian_offset

  @doc """
  Returns the Buddhist year corresponding to the given Gregorian year.

  """
  @spec buddhist_year(integer()) :: year
  def buddhist_year(gregorian_year), do: gregorian_year + @gregorian_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Buddhist `year` is a leap year. The
  underlying calendar is proleptic Gregorian, so the leap-year rule
  applies to the corresponding Gregorian year.

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Gregorian.leap_year?(gregorian_year(year))
  end

  @doc """
  Returns the number of days in the given Buddhist `year` and `month`.

  """
  @impl true
  @spec days_in_month(year, month) :: 28..31
  def days_in_month(year, month) do
    Calendrical.Gregorian.days_in_month(gregorian_year(year), month)
  end

  @doc """
  Returns the number of days in the given Buddhist `year` (365 or 366).

  """
  @impl true
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Determines if the given `year`, `month`, and `day` form a valid
  Buddhist date.

  """
  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Calendrical.Gregorian.valid_date?(gregorian_year(year), month, day)
  end

  def valid_date?(_year, _month, _day), do: false

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Buddhist `year`,
  `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Calendrical.Gregorian.date_to_iso_days(gregorian_year(year), month, day)
  end

  @doc """
  Returns a Buddhist `{year, month, day}` for the given ISO day number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    {greg_year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    {buddhist_year(greg_year), month, day}
  end
end
