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
    months_in_leap_year: 12,
    first_day_of_week: 7

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

  ### Returns

  * A `t:Geo.PointZ.t/0` for Mecca, Saudi Arabia (the
    *al-Masjid al-Ḥarām*).

  ### Examples

      iex> Calendrical.Islamic.Rgsa.location().coordinates
      {39.8262, 21.4225, 277.0}

  """
  @spec location() :: Geo.PointZ.t()
  def location, do: @mecca

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Hijri `year` is a 355-day year (the
  sighting-based analogue of a "leap year").

  Year length varies between 354 and 355 days depending on predicted
  crescent sightings at Mecca, so this is computed by comparing the
  starts of two successive years.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `true` if the year contains 355 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.leap_year?(1447)
      true

      iex> Calendrical.Islamic.Rgsa.leap_year?(1446)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year), do: days_in_year(year) > 354

  @doc """
  Returns the number of days in the given Hijri `year`.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `354` for an ordinary year or `355` for a leap year.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.days_in_year(1446)
      354

  """
  @impl true
  @spec days_in_year(year) :: 354..355
  def days_in_year(year) do
    date_to_iso_days(year + 1, 1, 1) - date_to_iso_days(year, 1, 1)
  end

  @doc """
  Returns `{year, week_in_year}` for the given Islamic date.

  Weeks run Sunday (al-Ahad, “the first”) through Saturday, the
  calendar's own week boundary. Week 1 is the week containing
  1 Muharram, so a year that opens mid-week has a short
  first week. Every date numbers within its own year; weeks do
  not spill into the adjacent year's numbering.

  ### Arguments

  * `year` is any Islamic year as an integer.

  * `month` is a Islamic month number.

  * `day` is a Islamic day-of-month.

  ### Returns

  * A two-tuple `{year, week_in_year}`.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.week_of_year(1447, 1, 1)
      {1447, 1}

      iex> Calendrical.Islamic.Rgsa.week_of_year(1447, 9, 1)
      {1447, 35}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()}
  def week_of_year(year, month, day) do
    Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
  end

  @doc """
  Returns the number of weeks in the given Islamic `year`.

  ### Arguments

  * `year` is any Islamic year as an integer.

  ### Returns

  * A two-tuple `{weeks_in_year, days_in_last_week}` where the
    final week is short when the year does not end on the last
    day of the calendar's week.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.weeks_in_year(1447)
      {52, 2}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) :: {Calendrical.week(), Calendar.day()}
  def weeks_in_year(year) do
    Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
  end

  @doc """
  Returns the number of days in the given Hijri `year` and `month`
  (29 or 30, determined by predicted crescent visibility at Mecca).

  ### Arguments

  * `year` is any Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  ### Returns

  * The number of days in the month (`29` or `30`).

  ### Examples

      iex> Calendrical.Islamic.Rgsa.days_in_month(1446, 1)
      30

      iex> Calendrical.Islamic.Rgsa.days_in_month(1446, 4)
      29

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month) when month in 1..12 do
    first_day_of_month(year, month + 1) - first_day_of_month(year, month)
  end

  @doc """
  Returns whether the given `year`, `month`, and `day` form a valid
  Saudi sighting-based Islamic date.

  ### Arguments

  * `year` is any positive Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  * `day` is a Hijri day-of-month in the range `1..30`.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.valid_date?(1446, 1, 30)
      true

      iex> Calendrical.Islamic.Rgsa.valid_date?(1446, 4, 30)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
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

  ### Arguments

  * `year` is any Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  * `day` is a Hijri day-of-month in the range `1..30`.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  * Raises `Calendrical.UnsupportedDateRangeError` if the date falls
    outside the range of the underlying JPL ephemeris.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.date_to_iso_days(1446, 1, 1)
      739439

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    first_day_of_month(year, month) + day - 1
  end

  @doc """
  Returns a Saudi sighting-based Islamic `{year, month, day}` for
  the given ISO day number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Saudi sighting-based
    Islamic calendar.

  * Raises `Calendrical.UnsupportedDateRangeError` if `iso_days`
    falls outside the range of the underlying JPL ephemeris.

  ### Examples

      iex> Calendrical.Islamic.Rgsa.date_from_iso_days(739_252)
      {1445, 6, 20}

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
