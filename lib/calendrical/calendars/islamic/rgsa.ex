defmodule Calendrical.Islamic.Rgsa do
  @moduledoc """
  Implementation of the *Saudi Arabian sighting-based* Islamic
  calendar (CLDR `:islamic_rgsa`).

  Like `Calendrical.Islamic.Observational`, this calendar determines
  the start of each lunar month from actual crescent visibility, but
  the observation point is **Mecca, Saudi Arabia** (21.4225° N,
  39.8262° E, 277 m) — the *al-Masjid al-Ḥarām* — rather than Cairo.
  This matches the location used for the canonical Saudi religious
  determination of dates such as the start of Ramadan and Eid.

  This calendar differs from `Calendrical.Islamic.UmmAlQura` in two
  important ways:

  * **`UmmAlQura`** uses the official tabular calendar published by
    KACST (the Umm al-Qura Calendar). It is a precomputed lookup
    table — fast, deterministic, and the legal Saudi civil calendar.

  * **`Rgsa`** computes month starts from astronomical visibility at
    Mecca on demand. It is the algorithmic equivalent of the Saudi
    *religious sighting* practice and may diverge from `UmmAlQura`
    in months where the astronomical prediction does not match the
    KACST table.

  Days are assumed to begin at midnight.

  ## Visibility model

  As with `Calendrical.Islamic.Observational`, crescent visibility
  is computed by `Astro.new_visible_crescent/3` using the Odeh (2006)
  criterion by default.

  ## Reference

  - CLDR `:islamic_rgsa` calendar type. The `rgsa` suffix denotes
    "*Religious Saudi Arabia*".
  - Dershowitz & Reingold, *Calendrical Calculations* (4th ed.),
    Chapter 14.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_rgsa,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  alias Calendrical.Islamic.Visibility

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..30

  # Mecca, Saudi Arabia — al-Masjid al-Ḥarām (the Great Mosque).
  @mecca %Geo.PointZ{coordinates: {39.8262, 21.4225, 277.0}}

  @mean_synodic_month 29.530588853

  @doc """
  Returns the geographic location used to determine crescent
  visibility for this calendar.
  """
  @spec location() :: Geo.PointZ.t()
  def location, do: @mecca

  # ── Configuration overrides ──────────────────────────────────────────────

  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year), do: days_in_year(year) > 354

  @impl true
  def days_in_year(year) do
    date_to_iso_days(year + 1, 1, 1) - date_to_iso_days(year, 1, 1)
  end

  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month) when month in 1..12 do
    first_day_of_month(year, month + 1) - first_day_of_month(year, month)
  end

  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= 1 and month in 1..12 and day in 1..30 do
    day <= days_in_month(year, month)
  end

  def valid_date?(_year, _month, _day), do: false

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Saudi sighting-based
  Islamic `year`, `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    first_day_of_month(year, month) + day - 1
  end

  @doc """
  Returns a Saudi sighting-based Islamic `{year, month, day}` for
  the given ISO day number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    crescent = Visibility.phasis_on_or_before(iso_days, @mecca)
    elapsed_months = round((crescent - epoch()) / @mean_synodic_month)
    year = div(elapsed_months, 12) + 1
    month = rem(elapsed_months, 12) + 1
    day = iso_days - crescent + 1
    {year, month, day}
  end

  defp first_day_of_month(year, 13), do: first_day_of_month(year + 1, 1)

  defp first_day_of_month(year, month) when month in 1..12 do
    months_elapsed = (year - 1) * 12 + (month - 1)
    midmonth = epoch() + floor((months_elapsed + 0.5) * @mean_synodic_month)
    Visibility.phasis_on_or_before(midmonth, @mecca)
  end
end
