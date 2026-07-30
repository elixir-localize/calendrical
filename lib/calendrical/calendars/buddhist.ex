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
  proleptic Gregorian calendar.

  Subtracting this offset from a Buddhist year yields the corresponding
  Gregorian year.

  ### Returns

  * The integer `543`.

  ### Examples

      iex> Calendrical.Buddhist.gregorian_offset()
      543

  """
  @spec gregorian_offset() :: 543
  def gregorian_offset, do: @gregorian_offset

  @doc """
  Returns the Gregorian year corresponding to the given Buddhist year.

  ### Arguments

  * `buddhist_year` is any Buddhist Era year as an integer.

  ### Returns

  * An integer Gregorian year (543 less than the input).

  ### Examples

      iex> Calendrical.Buddhist.gregorian_year(2569)
      2026

  """
  @spec gregorian_year(year) :: integer()
  def gregorian_year(buddhist_year) when is_integer(buddhist_year),
    do: buddhist_year - @gregorian_offset

  @doc """
  Returns the Buddhist year corresponding to the given Gregorian year.

  ### Arguments

  * `gregorian_year` is any proleptic Gregorian year as an integer.

  ### Returns

  * An integer Buddhist year (543 more than the input).

  ### Examples

      iex> Calendrical.Buddhist.buddhist_year(2026)
      2569

  """
  @spec buddhist_year(integer()) :: year
  def buddhist_year(gregorian_year) when is_integer(gregorian_year),
    do: gregorian_year + @gregorian_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Buddhist `year` is a leap year.

  The underlying calendar is proleptic Gregorian, so the leap-year rule
  applies to the corresponding Gregorian year.

  ### Arguments

  * `year` is any Buddhist year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Buddhist.leap_year?(2567)
      true

      iex> Calendrical.Buddhist.leap_year?(2569)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Gregorian.leap_year?(gregorian_year(year))
  end

  @doc """
  Returns the number of days in the given Buddhist `year` and `month`.

  ### Arguments

  * `year` is any Buddhist year as an integer.

  * `month` is a month in the range `1..12`.

  ### Returns

  * The number of days in the month (`28..31`).

  ### Examples

      iex> Calendrical.Buddhist.days_in_month(2569, 2)
      28

  """
  @impl true
  @spec days_in_month(year, month) :: 28..31
  def days_in_month(year, month) do
    Calendrical.Gregorian.days_in_month(gregorian_year(year), month)
  end

  @doc """
  Returns the number of days in the given Buddhist `year`.

  ### Arguments

  * `year` is any Buddhist year as an integer.

  ### Returns

  * `365` for an ordinary year or `366` for a leap year.

  ### Examples

      iex> Calendrical.Buddhist.days_in_year(2569)
      365

      iex> Calendrical.Buddhist.days_in_year(2567)
      366

  """
  @impl true
  @spec days_in_year(year) :: 365..366
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Returns whether the given `year`, `month`, and `day` form a valid
  Buddhist date.

  ### Arguments

  * `year` is any Buddhist year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Buddhist.valid_date?(2569, 1, 31)
      true

      iex> Calendrical.Buddhist.valid_date?(2569, 2, 29)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Calendrical.Gregorian.valid_date?(gregorian_year(year), month, day)
  end

  def valid_date?(_year, _month, _day), do: false

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Buddhist `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Buddhist year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Buddhist.date_to_iso_days(2569, 1, 1)
      739982

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Calendrical.Gregorian.date_to_iso_days(gregorian_year(year), month, day)
  end

  @doc """
  Returns a Buddhist `{year, month, day}` tuple for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in Buddhist Era numbering.

  ### Examples

      iex> Calendrical.Buddhist.date_from_iso_days(739_252)
      {2567, 1, 2}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    {greg_year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    {buddhist_year(greg_year), month, day}
  end
end
