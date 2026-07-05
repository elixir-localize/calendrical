defmodule Calendrical.Islamic.Observational do
  @moduledoc """
  Implementation of the *observational* (sighting-based) Islamic
  calendar.

  Unlike the tabular calendars in `Calendrical.Islamic.Civil` and
  `Calendrical.Islamic.Tbla`, the start of each lunar month in this
  calendar is determined by **actual visibility of the new crescent
  moon** at a sample location. The location used here is **Cairo,
  Egypt** (30.1° N, 31.3° E, 200 m), the canonical "Islamic location"
  used by Dershowitz & Reingold's *Calendrical Calculations*.

  This is the calendar identified by the CLDR `:islamic` calendar
  type. Days are assumed to begin at midnight.

  ## Visibility model

  Crescent visibility is computed by `Astro.new_visible_crescent/3`
  using the **Odeh (2006)** criterion by default — a modern
  empirical model fitted against 737 historical sightings. The Odeh
  criterion replaces Reingold's older Shaukat criterion and is the
  basis for several national Islamic calendar committees.

  Months are 29 or 30 days long depending on whether the crescent
  was visible on the eve of the 30th day; years are 354 or 355 days
  long.

  ## Performance

  Each calendar conversion makes a small number of crescent
  visibility calls (typically 1-3, plus one new-moon search). The
  underlying astronomical computations are not cached, so users that
  need to convert many dates may benefit from caching results
  externally.

  ## Reference

  - Dershowitz & Reingold, *Calendrical Calculations* (4th ed.),
    Chapter 14, "The Islamic and Saudi Arabian Calendars".
  - Odeh, M. Sh. (2004), *New Criterion for Lunar Crescent
    Visibility*. Experimental Astronomy 18, 39–64.
  - CLDR `:islamic` calendar type.

  See also `Calendrical.Islamic.Rgsa` for the same algorithm applied
  at Mecca, and `Calendrical.Islamic.UmmAlQura` for the official
  Saudi tabular calendar.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  alias Calendrical.Islamic.Visibility

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..30

  # Cairo, Egypt — the "islamic-location" constant from Reingold.
  @cairo %Geo.PointZ{coordinates: {31.3, 30.1, 200.0}}

  @mean_synodic_month 29.530588853

  @doc """
  Returns the geographic location used to determine crescent
  visibility for this calendar.

  ### Returns

  * A `t:Geo.PointZ.t/0` for Cairo, Egypt (Reingold's canonical
    "Islamic location").

  ### Examples

      iex> Calendrical.Islamic.Observational.location().coordinates
      {31.3, 30.1, 200.0}

  """
  @spec location() :: Geo.PointZ.t()
  def location, do: @cairo

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Hijri `year` is a 355-day year (the
  observational analogue of a "leap year").

  Year length varies between 354 and 355 days depending on actual
  crescent sightings, so this must be computed by comparing the
  starts of two successive years.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `true` if the year contains 355 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Islamic.Observational.leap_year?(1447)
      true

      iex> Calendrical.Islamic.Observational.leap_year?(1446)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    days_in_year(year) > 354
  end

  @doc """
  Returns the number of days in the given Hijri `year`.

  ### Arguments

  * `year` is any Hijri year as an integer.

  ### Returns

  * `354` for an ordinary year or `355` for a leap year.

  ### Examples

      iex> Calendrical.Islamic.Observational.days_in_year(1446)
      354

  """
  @impl true
  @spec days_in_year(year) :: 354..355
  def days_in_year(year) do
    date_to_iso_days(year + 1, 1, 1) - date_to_iso_days(year, 1, 1)
  end

  @doc """
  Returns the number of days in the given Hijri `year` and `month`
  (29 or 30, determined by actual crescent visibility).

  ### Arguments

  * `year` is any Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  ### Returns

  * The number of days in the month (`29` or `30`).

  ### Examples

      iex> Calendrical.Islamic.Observational.days_in_month(1446, 1)
      30

      iex> Calendrical.Islamic.Observational.days_in_month(1446, 5)
      29

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month) when month in 1..12 do
    next_month_first = first_day_of_month(year, month + 1)
    this_month_first = first_day_of_month(year, month)
    next_month_first - this_month_first
  end

  @doc """
  Determines if the given `year`, `month`, and `day` form a valid
  observational Islamic date.

  ### Arguments

  * `year` is any positive Hijri year as an integer.

  * `month` is a Hijri month in the range `1..12`.

  * `day` is a Hijri day-of-month in the range `1..30`.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Islamic.Observational.valid_date?(1446, 1, 30)
      true

      iex> Calendrical.Islamic.Observational.valid_date?(1446, 5, 30)
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
  Returns the number of ISO days for the given observational
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

      iex> Calendrical.Islamic.Observational.date_to_iso_days(1446, 1, 1)
      739439

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    first_day_of_month(year, month) + day - 1
  end

  @doc """
  Returns an observational Islamic `{year, month, day}` for the
  given ISO day number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the observational Islamic
    calendar.

  * Raises `Calendrical.UnsupportedDateRangeError` if `iso_days`
    falls outside the range of the underlying JPL ephemeris.

  ### Examples

      iex> Calendrical.Islamic.Observational.date_from_iso_days(739_252)
      {1445, 6, 20}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    crescent = Visibility.phasis_on_or_before(iso_days, @cairo)
    elapsed_months = round((crescent - epoch()) / @mean_synodic_month)
    year = div(elapsed_months, 12) + 1
    month = rem(elapsed_months, 12) + 1
    day = iso_days - crescent + 1
    {year, month, day}
  end

  # ── Internal helpers ─────────────────────────────────────────────────────

  # The ISO day number of the first day of (year, month). Months > 12
  # roll over into the next year so that `days_in_month/2` can compute
  # the length of month 12 by asking for month 13.
  defp first_day_of_month(year, 13), do: first_day_of_month(year + 1, 1)

  defp first_day_of_month(year, month) when month in 1..12 do
    months_elapsed = (year - 1) * 12 + (month - 1)
    midmonth = epoch() + floor((months_elapsed + 0.5) * @mean_synodic_month)
    Visibility.phasis_on_or_before(midmonth, @cairo)
  end
end
