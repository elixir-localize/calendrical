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

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year), do: Tabular.leap_year?(year)

  @doc """
  Returns the number of days in the given Hijri `year` and `month`.

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month), do: Tabular.days_in_month(year, month)

  @doc """
  Returns the number of days in the given Hijri `year` (354 or 355).

  """
  @impl true
  def days_in_year(year) do
    if leap_year?(year), do: 355, else: 354
  end

  @doc """
  Returns the number of ISO days for the given TBLA Islamic
  `year`, `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Tabular.date_to_iso_days(year, month, day, epoch())
  end

  @doc """
  Returns a TBLA Islamic `{year, month, day}` for the given ISO day
  number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    Tabular.date_from_iso_days(iso_days, epoch())
  end
end
