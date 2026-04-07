defmodule Calendrical.Ecclesiastical do
  @moduledoc """
  Computes the dates of Christian ecclesiastical events for a given
  Gregorian year.

  This module bundles the Reingold-style algorithms for the
  movable and fixed festivals of the Western, Eastern Orthodox, and
  *astronomical* (WCC 1997 proposed) Christian liturgical traditions.

  ## Three traditions

  Calendrical exposes three different *Easter* computations because
  they really are three distinct calculations. The differences are
  small in most years (and the three frequently coincide) but the
  underlying definitions and target audiences are different.

  | Function | Method | Calendar | Used by |
  |---|---|---|---|
  | `easter_sunday/1` | Gregorian *computus* (tabular) | Western Gregorian | Roman Catholic, Anglican, most Protestants |
  | `astronomical_easter_sunday/1` | **Astronomical** Paschal Full Moon + first Sunday after | (proleptic Gregorian, UTC) | "Astronomical Easter" — proposed by the World Council of Churches in 1997, no Church follows it |
  | `orthodox_easter_sunday/1` | Julian *computus* (tabular) | Eastern Orthodox Julian | Eastern Orthodox |

  Western Easter and Orthodox Easter coincide in years like **2025**;
  they can differ by one, four, or five weeks in other years
  because the Western (Gregorian) and Eastern (Julian) computus use
  different lookup tables and different leap-year rules. The
  astronomical reckoning agrees with the Western Gregorian computus
  for most years in the 21st century but is not actually used by any
  Church — it is included here for comparison and research.

  ## Movable feasts (Western)

  * `easter_sunday/1` — Western Easter Sunday (Gregorian computus).

  * `good_friday/1` — Western Good Friday (two days before Western
    Easter Sunday).

  * `pentecost/1` — Western Pentecost Sunday, exactly 49 days after
    `easter_sunday/1`.

  * `advent/1` — the first Sunday of Advent, the Sunday closest to
    30 November.

  ## Movable feasts (Eastern Orthodox, Julian-based)

  All Eastern Orthodox functions return `Calendrical.Julian` dates
  so that the Julian-calendar context is immediately visible in the
  result. Use `Date.convert/2` to project them onto another calendar.

  * `orthodox_easter_sunday/1` — Eastern Orthodox Easter Sunday
    (Julian computus).

  * `orthodox_good_friday/1` — Eastern Orthodox Good Friday (two
    days before Orthodox Easter Sunday).

  * `orthodox_pentecost/1` — Eastern Orthodox Pentecost Sunday,
    exactly 49 days after `orthodox_easter_sunday/1`.

  * `orthodox_advent/1` — the start of the Eastern Orthodox
    *Nativity Fast* on **15 November** (Julian). This is a fixed
    40-day Lenten preparation for Christmas, not a movable Sunday
    observance. Eastern Orthodoxy does not have a direct equivalent
    of the Western "Advent Sunday".

  ## Movable feasts (astronomical, WCC 1997)

  * `astronomical_easter_sunday/1` — Astronomical Easter Sunday: the
    first Sunday strictly after the astronomical Paschal Full Moon.
    This is the calculation proposed by the World Council of
    Churches at the 1997 Aleppo Consultation as a basis for unifying
    Western and Eastern Easter dates. No Church has yet adopted it.

  * `astronomical_good_friday/1` — Astronomical Good Friday (two
    days before `astronomical_easter_sunday/1`).

  * `paschal_full_moon/1` — the *astronomical* Paschal Full Moon —
    the first astronomical full moon on or after the March vernal
    equinox. Used internally by the astronomical Easter functions.
    Uses the `Astro` library for the equinox and full-moon
    calculations.

  ## Fixed feasts

  * `christmas/1` — Western (Gregorian) Christmas Day,
    25 December.

  * `epiphany/1` — Epiphany as observed in the United States: the
    first Sunday after 1 January. (The traditional fixed-date
    Epiphany on 6 January is also widely observed.)

  * `eastern_orthodox_christmas/1` — Eastern Orthodox Christmas
    Day, 25 December (Julian) projected onto the proleptic Gregorian
    calendar. May fall in either January or December of the
    requested Gregorian year, so a list is returned.

  * `coptic_christmas/1` — Coptic Christmas, 29 Koiak in the Coptic
    calendar (`Calendrical.Coptic`), projected onto the proleptic
    Gregorian calendar. Like Eastern Orthodox Christmas, may return
    zero, one, or two dates.

  ## Reference

  - Dershowitz & Reingold, *Calendrical Calculations* (4th ed.),
    Chapter 9 ("Ecclesiastical Calendars").

  - World Council of Churches, *Towards a Common Date for Easter*,
    Aleppo Consultation, 1997.

  """

  alias Calendrical.Kday

  @sunday 7

  @doc """
  Returns the date of Western *Easter Sunday* in the given Gregorian
  year, computed by the Gregorian *computus*.

  This is the calculation used by the Roman Catholic Church, the
  Anglican Communion, and most Protestant churches. The algorithm is
  the Nicaean rule corrected for the Gregorian century rule and the
  Metonic-cycle inaccuracy.

  ## Examples

      iex> Calendrical.Ecclesiastical.easter_sunday(2024)
      ~D[2024-03-31 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.easter_sunday(2025)
      ~D[2025-04-20 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.easter_sunday(2026)
      ~D[2026-04-05 Calendrical.Gregorian]

  """
  @spec easter_sunday(Calendar.year()) :: Date.t()
  def easter_sunday(g_year) when is_integer(g_year) do
    century = div(g_year, 100) + 1
    nicaean_epact = Integer.mod(14 + 11 * Integer.mod(g_year, 19), 30)
    gregorian_correction = -div(3 * century, 4)
    metonic_correction = div(5 + 8 * century, 25)

    shifted_epact = Integer.mod(nicaean_epact + gregorian_correction + metonic_correction, 30)

    adjusted_epact =
      cond do
        shifted_epact == 0 -> shifted_epact + 1
        shifted_epact == 1 and Integer.mod(g_year, 19) > 10 -> shifted_epact + 1
        true -> shifted_epact
      end

    paschal_moon_iso_days =
      Calendrical.Gregorian.date_to_iso_days(g_year, 4, 19) - adjusted_epact

    paschal_moon_iso_days
    |> Kday.kday_after(@sunday)
    |> iso_days_to_gregorian_date()
  end

  @doc """
  Returns the date of Western *Good Friday* in the given Gregorian
  year — exactly two days before `easter_sunday/1`.

  ## Examples

      iex> Calendrical.Ecclesiastical.good_friday(2024)
      ~D[2024-03-29 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.good_friday(2025)
      ~D[2025-04-18 Calendrical.Gregorian]

  """
  @spec good_friday(Calendar.year()) :: Date.t()
  def good_friday(g_year) when is_integer(g_year) do
    Date.add(easter_sunday(g_year), -2)
  end

  @doc """
  Returns the date of *Pentecost Sunday* (Whitsunday) in the given
  Gregorian year. Pentecost is exactly 49 days after Western
  Easter Sunday.

  ## Examples

      iex> Calendrical.Ecclesiastical.pentecost(2024)
      ~D[2024-05-19 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.pentecost(2025)
      ~D[2025-06-08 Calendrical.Gregorian]

  """
  @spec pentecost(Calendar.year()) :: Date.t()
  def pentecost(g_year) when is_integer(g_year) do
    Date.add(easter_sunday(g_year), 49)
  end

  @doc """
  Returns the date of *Advent Sunday* in the given Gregorian year:
  the Sunday closest to 30 November.

  ## Examples

      iex> Calendrical.Ecclesiastical.advent(2024)
      ~D[2024-12-01 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.advent(2025)
      ~D[2025-11-30 Calendrical.Gregorian]

  """
  @spec advent(Calendar.year()) :: Date.t()
  def advent(g_year) when is_integer(g_year) do
    Calendrical.Gregorian.date_to_iso_days(g_year, 11, 30)
    |> Kday.kday_nearest(@sunday)
    |> iso_days_to_gregorian_date()
  end

  # ── Eastern Orthodox (Julian) Easter & Good Friday ────────────────────

  @doc """
  Returns the date of Eastern Orthodox *Easter Sunday* in the given
  Gregorian year, computed by the Julian *computus*.

  The result is returned as a `Calendrical.Julian` `Date` so that
  the Julian-calendar context is immediately visible in the result.
  Use `Date.convert/2` to project it onto another calendar.

  ## Examples

      iex> Calendrical.Ecclesiastical.orthodox_easter_sunday(2024)
      ~D[2024-04-22 Calendrical.Julian]

      iex> Calendrical.Ecclesiastical.orthodox_easter_sunday(2025)
      ~D[2025-04-07 Calendrical.Julian]

      iex> {:ok, gregorian} =
      ...>   Date.convert(
      ...>     Calendrical.Ecclesiastical.orthodox_easter_sunday(2024),
      ...>     Calendrical.Gregorian
      ...>   )
      iex> gregorian
      ~D[2024-05-05 Calendrical.Gregorian]

  """
  @spec orthodox_easter_sunday(Calendar.year()) :: Date.t()
  def orthodox_easter_sunday(g_year) when is_integer(g_year) do
    shifted_epact = Integer.mod(14 + 11 * Integer.mod(g_year, 19), 30)
    j_year = if g_year > 0, do: g_year, else: g_year - 1

    paschal_moon_iso_days =
      Calendrical.Julian.date_to_iso_days(j_year, 4, 19) - shifted_epact

    paschal_moon_iso_days
    |> Kday.kday_after(@sunday)
    |> iso_days_to_julian_date()
  end

  @doc """
  Returns the date of Eastern Orthodox *Good Friday* in the given
  Gregorian year — exactly two days before
  `orthodox_easter_sunday/1`.

  The result is returned as a `Calendrical.Julian` `Date`.

  ## Examples

      iex> Calendrical.Ecclesiastical.orthodox_good_friday(2024)
      ~D[2024-04-20 Calendrical.Julian]

      iex> Calendrical.Ecclesiastical.orthodox_good_friday(2025)
      ~D[2025-04-05 Calendrical.Julian]

  """
  @spec orthodox_good_friday(Calendar.year()) :: Date.t()
  def orthodox_good_friday(g_year) when is_integer(g_year) do
    g_year
    |> orthodox_easter_sunday()
    |> Date.add(-2)
  end

  @doc """
  Returns the date of Eastern Orthodox *Pentecost Sunday* in the
  given Gregorian year — exactly 49 days after
  `orthodox_easter_sunday/1`.

  The result is returned as a `Calendrical.Julian` `Date`.

  ## Examples

      iex> Calendrical.Ecclesiastical.orthodox_pentecost(2024)
      ~D[2024-06-10 Calendrical.Julian]

      iex> Calendrical.Ecclesiastical.orthodox_pentecost(2025)
      ~D[2025-05-26 Calendrical.Julian]

  """
  @spec orthodox_pentecost(Calendar.year()) :: Date.t()
  def orthodox_pentecost(g_year) when is_integer(g_year) do
    g_year
    |> orthodox_easter_sunday()
    |> Date.add(49)
  end

  @doc """
  Returns the start date of the Eastern Orthodox *Nativity Fast* in
  the given Gregorian year — **15 November** in the Julian calendar
  (≡ 28 November Gregorian during the current 13-day offset
  period).

  The Nativity Fast is a fixed 40-day Lenten preparation for
  Christmas. Eastern Orthodoxy does not have a direct equivalent of
  the Western *Advent Sunday* — there is no movable "first Sunday
  of Advent" observance — so this function returns the (fixed)
  start of the fast instead.

  The result is returned as a `Calendrical.Julian` `Date`.

  ## Examples

      iex> Calendrical.Ecclesiastical.orthodox_advent(2024)
      ~D[2024-11-15 Calendrical.Julian]

      iex> Calendrical.Ecclesiastical.orthodox_advent(2025)
      ~D[2025-11-15 Calendrical.Julian]

  """
  @spec orthodox_advent(Calendar.year()) :: Date.t()
  def orthodox_advent(g_year) when is_integer(g_year) do
    Date.new!(g_year, 11, 15, Calendrical.Julian)
  end

  # ── Astronomical (WCC 1997) Easter & Good Friday ──────────────────────

  @doc """
  Returns the date of *Astronomical Easter Sunday* in the given
  Gregorian year — the first Sunday strictly after the astronomical
  Paschal Full Moon.

  This is the World Council of Churches' 1997 Aleppo Consultation
  proposal for unifying Western and Eastern Easter dates. **No
  Church currently follows it.** It is included for comparison
  with the Western (`easter_sunday/1`) and Eastern Orthodox
  (`orthodox_easter_sunday/1`) computus calculations.

  Uses `paschal_full_moon/1` (which in turn uses the `Astro`
  library) and so is restricted to the year range `1000..3000`.
  The result is returned as a `Calendar.ISO` `Date`.

  ## Examples

      iex> Calendrical.Ecclesiastical.astronomical_easter_sunday(2024)
      {:ok, ~D[2024-03-31]}

      iex> Calendrical.Ecclesiastical.astronomical_easter_sunday(2025)
      {:ok, ~D[2025-04-20]}

  """
  @spec astronomical_easter_sunday(Calendar.year()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def astronomical_easter_sunday(gregorian_year)
      when is_integer(gregorian_year) and gregorian_year in 1000..3000 do
    with {:ok, pfm} <- paschal_full_moon(gregorian_year) do
      {:ok, sunday_after(pfm)}
    end
  end

  @doc """
  Returns the date of *Astronomical Good Friday* in the given
  Gregorian year — exactly two days before
  `astronomical_easter_sunday/1`.

  ## Examples

      iex> Calendrical.Ecclesiastical.astronomical_good_friday(2024)
      {:ok, ~D[2024-03-29]}

      iex> Calendrical.Ecclesiastical.astronomical_good_friday(2025)
      {:ok, ~D[2025-04-18]}

  """
  @spec astronomical_good_friday(Calendar.year()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def astronomical_good_friday(gregorian_year)
      when is_integer(gregorian_year) and gregorian_year in 1000..3000 do
    with {:ok, easter} <- astronomical_easter_sunday(gregorian_year) do
      {:ok, Date.add(easter, -2)}
    end
  end

  @doc """
  Returns the date of the *astronomical* Paschal Full Moon for a
  given Gregorian year.

  The astronomical Paschal Full Moon is the first astronomical full
  moon that occurs on or after the March (vernal) equinox. It is the
  basis for `astronomical_easter_sunday/1`.

  This function returns the *astronomical* PFM, computed from
  observed lunar and solar positions via the `Astro` library. It
  may occasionally differ by a day or more from the *ecclesiastical*
  PFM used by the Western (`easter_sunday/1`) or Eastern
  (`orthodox_easter_sunday/1`) computus, which are defined by
  tabular rules rather than astronomical observation.

  The returned date is a `Calendar.ISO` `Date`. The `Astro` library
  returns the underlying instant in UTC.

  ### Arguments

  * `gregorian_year` is the Gregorian year for which to compute the
    Paschal Full Moon. Must be in the range `1000..3000` due to the
    underlying equinox-calculation precision.

  ### Returns

  * `{:ok, date}` where `date` is the `t:Date.t/0` of the Paschal
    Full Moon in UTC, or

  * `{:error, exception}` if the calculation cannot be performed.

  ### Examples

      iex> Calendrical.Ecclesiastical.paschal_full_moon(2024)
      {:ok, ~D[2024-03-25]}

      iex> Calendrical.Ecclesiastical.paschal_full_moon(2025)
      {:ok, ~D[2025-04-13]}

  """
  @spec paschal_full_moon(Calendar.year()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def paschal_full_moon(gregorian_year)
      when is_integer(gregorian_year) and gregorian_year in 1000..3000 do
    with {:ok, equinox} <- Astro.equinox(gregorian_year, :march),
         {:ok, full_moon} <-
           Astro.date_time_lunar_phase_at_or_after(equinox, Astro.Lunar.full_moon_phase()) do
      {:ok, DateTime.to_date(full_moon)}
    end
  end

  @doc """
  Returns the date of Western *Christmas Day* (25 December) in the
  given Gregorian year.

  ## Examples

      iex> Calendrical.Ecclesiastical.christmas(2024)
      ~D[2024-12-25 Calendrical.Gregorian]

  """
  @spec christmas(Calendar.year()) :: Date.t()
  def christmas(g_year) when is_integer(g_year) do
    Date.new!(g_year, 12, 25, Calendrical.Gregorian)
  end

  @doc """
  Returns the date of *Epiphany* as observed in the United States in
  the given Gregorian year: the first Sunday after 1 January.

  Note that the traditional fixed-date Epiphany falls on 6 January
  and is more widely observed elsewhere.

  ## Examples

      iex> Calendrical.Ecclesiastical.epiphany(2024)
      ~D[2024-01-07 Calendrical.Gregorian]

      iex> Calendrical.Ecclesiastical.epiphany(2025)
      ~D[2025-01-05 Calendrical.Gregorian]

  """
  @spec epiphany(Calendar.year()) :: Date.t()
  def epiphany(g_year) when is_integer(g_year) do
    Calendrical.Gregorian.date_to_iso_days(g_year, 1, 2)
    |> Kday.kday_on_or_after(@sunday)
    |> iso_days_to_gregorian_date()
  end

  @doc """
  Returns the dates of *Eastern Orthodox Christmas* (25 December
  Julian) that fall in the given Gregorian year.

  Returns a list of zero, one, or two `t:Date.t/0` values because
  the Julian-to-Gregorian offset can place 25 December Julian in
  either January or December of the same Gregorian year.

  ## Examples

      iex> Calendrical.Ecclesiastical.eastern_orthodox_christmas(2024)
      [~D[2024-01-07 Calendrical.Gregorian]]

      iex> Calendrical.Ecclesiastical.eastern_orthodox_christmas(2025)
      [~D[2025-01-07 Calendrical.Gregorian]]

  """
  @spec eastern_orthodox_christmas(Calendar.year()) :: [Date.t()]
  def eastern_orthodox_christmas(g_year) when is_integer(g_year) do
    julian_in_gregorian(12, 25, g_year, Calendrical.Julian)
  end

  @doc """
  Returns the dates of *Coptic Christmas* (29 Koiak in the Coptic
  calendar) that fall in the given Gregorian year.

  Returns a list of zero, one, or two `t:Date.t/0` values for the
  same reason as `eastern_orthodox_christmas/1`.

  ## Examples

      iex> Calendrical.Ecclesiastical.coptic_christmas(2024)
      [~D[2024-01-08 Calendrical.Gregorian]]

      iex> Calendrical.Ecclesiastical.coptic_christmas(2025)
      [~D[2025-01-07 Calendrical.Gregorian]]

  """
  @spec coptic_christmas(Calendar.year()) :: [Date.t()]
  def coptic_christmas(g_year) when is_integer(g_year) do
    julian_in_gregorian(4, 29, g_year, Calendrical.Coptic)
  end

  # Returns the first Sunday strictly after the given date.
  # Used to derive `astronomical_easter_sunday/1` from
  # `paschal_full_moon/1`. The input is a plain `Calendar.ISO` Date
  # returned by the Astro library; the output is the same kind of
  # Date.
  defp sunday_after(%Date{} = date) do
    iso_days = Date.to_gregorian_days(date)

    Calendrical.Kday.kday_after(iso_days, 7)
    |> Date.from_gregorian_days()
  end

  # Returns the Gregorian dates on which a given Julian or Coptic
  # `month`/`day` occurs in the supplied Gregorian year. The
  # underlying calendar (`Calendrical.Julian` or
  # `Calendrical.Coptic`) is supplied so the same helper can drive
  # `eastern_orthodox_christmas/1` and `coptic_christmas/1`.
  defp julian_in_gregorian(month, day, g_year, source_calendar) do
    {jan1_year, _, _} =
      source_calendar.date_from_iso_days(Calendrical.Gregorian.date_to_iso_days(g_year, 1, 1))

    candidates =
      for y <- [jan1_year, jan1_year + 1] do
        source_calendar.date_to_iso_days(y, month, day)
      end

    g_start = Calendrical.Gregorian.date_to_iso_days(g_year, 1, 1)
    g_end = Calendrical.Gregorian.date_to_iso_days(g_year + 1, 1, 1) - 1

    candidates
    |> Enum.filter(fn iso -> iso >= g_start and iso <= g_end end)
    |> Enum.map(&iso_days_to_gregorian_date/1)
  end

  defp iso_days_to_gregorian_date(iso_days) do
    {year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    Date.new!(year, month, day, Calendrical.Gregorian)
  end

  defp iso_days_to_julian_date(iso_days) do
    {year, month, day} = Calendrical.Julian.date_from_iso_days(iso_days)
    Date.new!(year, month, day, Calendrical.Julian)
  end
end
