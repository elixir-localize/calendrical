defmodule Calendrical.Persian do
  @moduledoc """
  The present Iranian calendar was legally adopted on 31
  March 1925, under the early Pahlavi dynasty. The law
  said that the first day of the year should be the
  first day of spring in "the true solar year", "as it
  has been" ever so. It also fixes the number of days
  in each month, which previously varied by year with
  the sidereal zodiac.

  It revived the ancient Persian names, which are still
  used. It specifies the origin of the calendar to be
  the Hegira of Muhammad from Mecca to Medina in 622 CE).

  ### Astronomical years

  This calendar is observational: each year begins on the day of the
  vernal equinox in Tehran (the day after, when the equinox falls after
  true noon there), computed by `Astro.equinox/3` and `Astro.solar_noon/2`
  for every year within the 50,000 years either side of 2000 that Astro
  answers for: Persian years -48,621 to 51,378. Years are numbered
  astronomically, as ICU numbers them: the year before 1 is 0.

  ICU's Persian calendar is arithmetic instead, by a 33-year cycle with a
  table of corrections. The two agree on every year's start from 1279 to
  1479 and on most years near them, and part as the cycle and the sky
  drift apart.

  """

  # The first day of year 1 by the equinox: 19 March 622 (Julian), 22 March
  # in the proleptic Gregorian calendar, Dershowitz and Reingold's epoch.
  # ICU's arithmetic calendar has the day before.
  use Calendrical.Calendar,
    epoch: ~D[0622-03-19 Calendrical.Julian],
    cldr_calendar_type: :persian,
    weeks: [first_day: 6]

  # The Persian years whose start and length Astro can compute: year `y`
  # begins in Gregorian year `y + 621`, and Astro finds the equinox for the
  # Gregorian years -48,000 to 52,000. A year outside them has no days.
  @supported_years -48_621..51_378

  @tehran %Geo.PointZ{coordinates: {51.3890, 35.6892, 1100}}

  @doc """
  Returns whether the given Persian year is a leap year.

  Since this calendar is observational we calculate the start of
  successive years and then calculate the difference in days to
  determine whether it is a leap year.

  ### Arguments

  * `year` is any Persian year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Persian.leap_year?(1403)
      true

      iex> Calendrical.Persian.leap_year?(1404)
      false

  """
  @spec leap_year?(Calendar.year()) :: boolean()
  @impl true
  def leap_year?(year) when is_integer(year) do
    new_year(year + 1) - new_year(year) == 366
  end

  @doc """
  Returns the number of days in a Persian month.

  The first six months have 31 days, the next five 30, and Esfand, the
  twelfth, 30 in a leap year and 29 otherwise.

  ### Arguments

  * `year` is any Persian year as an integer.

  * `month` is a Persian month in the range `1..12`.

  ### Returns

  * The number of days in the month, or

  * `{:error, %Calendrical.UnsupportedDateRangeError{}}` for a year
    outside those Astro answers for, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month that is not
    `1..12`.

  ### Examples

      iex> Calendrical.Persian.days_in_month(1403, 12)
      30

      iex> Calendrical.Persian.days_in_month(1404, 12)
      29

  """
  @impl true
  def days_in_month(_year, month) when month in 1..6 do
    31
  end

  def days_in_month(_year, month) when month in 7..11 do
    30
  end

  def days_in_month(year, 12) do
    if leap_year?(year) do
      30
    else
      29
    end
  end

  def days_in_month(year, month) do
    {:error,
     Calendrical.InvalidMonthError.exception(calendar: __MODULE__, year: year, month: month)}
  end

  @doc """
  Returns the number of days since the ISO calendar epoch for a given
  Persian `year`, `month`, and `day`.

  ### Arguments

  * `year` is any Persian year as an integer.

  * `month` is a Persian month in the range `1..12`.

  * `day` is a Persian day-of-month in the range `1..31`.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Persian.date_to_iso_days(1404, 1, 1)
      739696

      iex> Calendrical.Persian.date_to_iso_days(1, 1, 1)
      227261

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) :: integer()
  @impl true
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    new_year(year) - 1 + days_before_month(month) + day
  end

  # Months 1 to 6 have 31 days and months 7 to 11 have 30.
  defp days_before_month(month) when month <= 7 do
    31 * (month - 1)
  end

  defp days_before_month(month) do
    30 * (month - 1) + 6
  end

  @doc """
  Returns a `{year, month, day}` tuple representing the Persian
  calendar date for the given count of ISO days.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Persian calendar.

  ### Examples

      iex> Calendrical.Persian.date_from_iso_days(739_335)
      {1403, 1, 6}

      iex> Calendrical.Persian.date_from_iso_days(227_259)
      {0, 12, 29}

  """
  @spec date_from_iso_days(integer()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  @impl true
  def date_from_iso_days(iso_days) when is_integer(iso_days) do
    {year, new_year} = year_and_new_year(iso_days)
    day_of_year = iso_days - new_year

    if day_of_year < 186 do
      {year, div(day_of_year, 31) + 1, rem(day_of_year, 31) + 1}
    else
      {year, div(day_of_year - 186, 30) + 7, rem(day_of_year - 186, 30) + 1}
    end
  end

  @doc """
  Returns the Gregorian `Date` of the Persian new year that falls in
  the given Gregorian `year`.

  The Persian new year (Nowruz) is the day on which the March equinox
  occurs in Tehran local time.

  ### Arguments

  * `year` is the Gregorian year in which the desired Persian new
    year falls.

  ### Returns

  * `{:ok, date}` where `date` is a `t:Date.t/0` in `Calendar.ISO`.

  * `{:error, %Calendrical.UnsupportedDateRangeError{}}` if `year` is
    more than 50,000 years from 2000, beyond the years Astro answers for.

  ### Examples

      iex> Calendrical.Persian.new_year_gregorian(2025)
      {:ok, ~D[2025-03-21]}

      iex> Calendrical.Persian.new_year_gregorian(900)
      {:ok, ~D[0900-03-21]}

      iex> Calendrical.Persian.new_year_gregorian(60_000)
      {:error, %Calendrical.UnsupportedDateRangeError{calendar: Calendrical.Persian, value: 60_000, range: -48_000..52_000}}

  """
  @spec new_year_gregorian(Calendar.year()) :: {:ok, Date.t()} | {:error, Exception.t()}
  def new_year_gregorian(year) when is_integer(year) do
    with {:ok, equinox} <- vernal_equinox(year),
         {:ok, solar_noon} <- midday_in_tehran(equinox, year) do
      day = DateTime.to_date(equinox)

      if Time.compare(equinox, solar_noon) in [:gt, :eq] do
        {:ok, Date.add(day, 1)}
      else
        {:ok, day}
      end
    end
  end

  @doc """
  Returns the Gregorian `Date` of the last day of the Persian year
  that begins in the given Gregorian `year`.

  ### Arguments

  * `year` is the Gregorian year in which the Persian year starts.

  ### Returns

  * `{:ok, date}` where `date` is a `t:Date.t/0` in `Calendar.ISO`,
    one day before the next Persian new year.

  * `{:error, %Calendrical.UnsupportedDateRangeError{}}` if `year + 1` is
    more than 50,000 years from 2000.

  ### Examples

      iex> Calendrical.Persian.year_end_gregorian(2025)
      {:ok, ~D[2026-03-20]}

  """
  @spec year_end_gregorian(Calendar.year()) :: {:ok, Date.t()} | {:error, Exception.t()}
  def year_end_gregorian(year) do
    with {:ok, new_year} <- new_year_gregorian(year + 1) do
      {:ok, Date.add(new_year, -1)}
    end
  end

  defp midday_in_tehran(date, year) do
    @tehran |> Astro.solar_noon(date) |> Calendrical.Base.Astro.result(__MODULE__, year)
  end

  defp vernal_equinox(year) do
    year |> Astro.equinox(:march) |> Calendrical.Base.Astro.result(__MODULE__, year)
  end

  @doc """
  Returns the count of ISO days of the most recent Persian new year on
  or before `iso_days`.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * An integer count of days since the proleptic ISO epoch
    corresponding to the most recent Persian new year on or before
    the supplied date.

  ### Examples

      iex> Calendrical.Persian.new_year_on_or_before(739_400)
      739330

  """
  @spec new_year_on_or_before(integer()) :: integer()
  def new_year_on_or_before(iso_days) when is_integer(iso_days) do
    {_year, new_year} = year_and_new_year(iso_days)
    new_year
  end

  # The Persian year `iso_days` falls in, and the ISO day it begins on. The
  # search starts from the year that begins in the day's Gregorian year and
  # steps to the year the day is in. Near the present that is the year
  # itself or the one before it, but tens of thousands of years away ΔT and
  # the slow change in the year's length move the equinox, in universal
  # time, months from March and into the Gregorian year before.
  defp year_and_new_year(iso_days) do
    {gregorian_year, _month, _day} = Calendar.ISO.date_from_iso_days(iso_days)
    settle_year(iso_days, gregorian_year - 621)
  end

  defp settle_year(iso_days, year) do
    new_year = new_year(year)

    cond do
      iso_days < new_year -> settle_year(iso_days, year - 1)
      iso_days >= new_year(year + 1) -> settle_year(iso_days, year + 1)
      true -> {year, new_year}
    end
  end

  # The ISO day of 1 Farvardin of `year`, worked out once and kept
  # (`Calendrical.YearCache`): every conversion asks for one or two new
  # years, each an equinox and a true noon. A year beyond Astro's range
  # raises, as a conversion callback cannot return an error.
  defp new_year(year) do
    Calendrical.YearCache.fetch_integer({__MODULE__, :new_year, year}, fn ->
      case new_year_gregorian(year + 621) do
        {:ok, new_year} -> Date.to_gregorian_days(new_year)
        {:error, exception} -> raise exception
      end
    end)
  end
end
