defmodule Calendrical.Islamic.Tbla do
  @moduledoc """
  Implementation of the tabular Islamic (Hijri) calendar based on the
  *astronomical* epoch.

  The TBLA (Tabular Based on Lunar Algorithm) calendar is structurally
  identical to `Calendrical.Islamic.Civil` — it uses the same 12-month
  layout, the same 30-year leap-year cycle, and the same arithmetic
  for converting between dates — but its epoch is one day earlier.

  The TBLA epoch is **Thursday 15 July 622 CE (Julian)** — equivalent
  to **18 July 622 CE (proleptic Gregorian)** — the day of the *hijra*
  rather than the day after. This is the convention used by some
  astronomical references and CLDR's `islamic-tbla` calendar type.

  Days are assumed to begin at midnight rather than at sunset.

  See `Calendrical.Islamic.Civil` for the month structure.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-18 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_tbla,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  alias Calendrical.Islamic.Tabular

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..30

  @doc """
  Returns whether the given Hijri `year` is a leap year.

  Leap years are determined by the Type II (*Kūshyār*) 30-year cycle
  in which years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and 29 of each
  cycle are leap years.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `true` if the year contains 355 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Islamic.Tbla.leap_year?(1447)
      true

      iex> Calendrical.Islamic.Tbla.leap_year?(1446)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year), do: Tabular.leap_year?(year)

  @doc """
  Returns the number of days in the given Hijri `year` and `month`.

  Odd-numbered months have 30 days and even-numbered months have 29
  days, except month 12 (*Dhū al-Ḥijjah*) which has 30 days in a
  leap year.

  ### Arguments

  * `year` is any Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  ### Returns

  * The number of days in the month (`29` or `30`).

  ### Examples

      iex> Calendrical.Islamic.Tbla.days_in_month(1447, 1)
      30

      iex> Calendrical.Islamic.Tbla.days_in_month(1446, 12)
      29

      iex> Calendrical.Islamic.Tbla.days_in_month(1447, 12)
      30

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month), do: Tabular.days_in_month(year, month)

  @doc """
  Returns the number of days in the given Hijri `year`.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `354` for an ordinary year or `355` for a leap year.

  ### Examples

      iex> Calendrical.Islamic.Tbla.days_in_year(1446)
      354

      iex> Calendrical.Islamic.Tbla.days_in_year(1447)
      355

  """
  @impl true
  @spec days_in_year(year) :: 354..355
  def days_in_year(year) do
    if leap_year?(year), do: 355, else: 354
  end

  @doc """
  Returns the number of ISO days for the given TBLA Islamic
  `year`, `month`, and `day`.

  ### Arguments

  * `year` is any Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  * `day` is a Hijri day-of-month in the range `1..30`.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Islamic.Tbla.date_to_iso_days(1447, 1, 1)
      739793

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Tabular.date_to_iso_days(year, month, day, epoch())
  end

  @doc """
  Returns a TBLA Islamic `{year, month, day}` for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the TBLA Islamic calendar.

  ### Examples

      iex> Calendrical.Islamic.Tbla.date_from_iso_days(739_252)
      {1445, 6, 21}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    Tabular.date_from_iso_days(iso_days, epoch())
  end
end
