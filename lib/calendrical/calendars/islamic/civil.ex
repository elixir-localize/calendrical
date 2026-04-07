defmodule Calendrical.Islamic.Civil do
  @moduledoc """
  Implementation of the tabular Islamic (Hijri) civil calendar.

  The civil tabular calendar is a 12-month lunar calendar with a fixed
  354- or 355-day year computed from a 30-year cycle in which years
  2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and 29 are leap years (the
  Type II *Kūshyār* cycle).

  The civil epoch is **Friday 16 July 622 CE (Julian)** — equivalent
  to **19 July 622 CE (proleptic Gregorian)** — the day after the
  *hijra* of Muhammad from Mecca to Medina. This is the convention
  used by most algorithmic calendars and CLDR's `islamic-civil`
  calendar type.

  Days are assumed to begin at midnight rather than at sunset.

  ## Month structure

  | # | Name             | Days |
  |---|------------------|------|
  | 1 | Muharram         | 30   |
  | 2 | Ṣafar            | 29   |
  | 3 | Rabī' al-Awwal   | 30   |
  | 4 | Rabī' al-Thānī   | 29   |
  | 5 | Jumādā al-Ūlā    | 30   |
  | 6 | Jumādā al-Ākhirah| 29   |
  | 7 | Rajab            | 30   |
  | 8 | Sha'bān          | 29   |
  | 9 | Ramaḍān          | 30   |
  | 10| Shawwāl          | 29   |
  | 11| Dhū al-Qa'dah    | 30   |
  | 12| Dhū al-Ḥijjah    | 29 / 30 (leap) |

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_civil,
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
  Returns the number of ISO days for the given civil Islamic
  `year`, `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Tabular.date_to_iso_days(year, month, day, epoch())
  end

  @doc """
  Returns a civil Islamic `{year, month, day}` for the given ISO day
  number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    Tabular.date_from_iso_days(iso_days, epoch())
  end
end
