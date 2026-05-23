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

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-03-20 Calendrical.Julian],
    cldr_calendar_type: :persian

  @mean_tropical_year 365.24219

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
  def leap_year?(year) do
    new_year = date_to_iso_days(year, 1, 1)
    next_year = date_to_iso_days(year + 1, 1, 1)
    next_year - new_year == 366
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

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) :: integer()
  def date_to_iso_days(year, month, day) do
    new_year =
      new_year_on_or_before(
        (epoch() + 180 +
           :math.floor(@mean_tropical_year * if(0 < year, do: year - 1, else: year)))
        |> trunc
      )

    new_year - 1 + if(month <= 7, do: 31 * (month - 1), else: 30 * (month - 1) + 6) + day
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

  """
  @spec date_from_iso_days(integer()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  def date_from_iso_days(iso_days) do
    new_year_iso_days = new_year_on_or_before(iso_days)
    y = round((new_year_iso_days - epoch()) / @mean_tropical_year) + 1
    year = if y > 0, do: y, else: y - 1
    day_of_year = 1 + iso_days - date_to_iso_days(year, 1, 1)

    month =
      if day_of_year <= 186,
        do: ceil(day_of_year / 31),
        else: :math.ceil((day_of_year - 6) / 30)

    day = iso_days - date_to_iso_days(year, month, 1) + 1
    {year, trunc(month), trunc(day)}
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

  ### Examples

      iex> Calendrical.Persian.new_year_gregorian(2025)
      {:ok, ~D[2025-03-21]}

  """
  @spec new_year_gregorian(Calendar.year()) :: {:ok, Date.t()}
  def new_year_gregorian(year) do
    {:ok, equinox} = vernal_equinox(year)
    {:ok, solar_noon} = midday_in_tehran(equinox)

    if Time.compare(equinox, solar_noon) in [:gt, :eq] do
      Date.new(equinox.year, equinox.month, equinox.day + 1)
    else
      Date.new(equinox.year, equinox.month, equinox.day)
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

  ### Examples

      iex> Calendrical.Persian.year_end_gregorian(2025)
      {:ok, ~D[2026-03-20]}

  """
  @spec year_end_gregorian(Calendar.year()) :: {:ok, Date.t()}
  def year_end_gregorian(year) do
    {:ok, new_year} = new_year_gregorian(year + 1)
    {:ok, Date.add(new_year, -1)}
  end

  @tehran %Geo.PointZ{coordinates: {51.3890, 35.6892, 1100}}

  defp midday_in_tehran(date) do
    Astro.solar_noon(@tehran, date)
  end

  defp vernal_equinox(year) do
    Astro.equinox(year, :march)
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
    {year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    {:ok, date} = Date.new(year, month, day)
    {:ok, new_year_gregorian} = new_year_gregorian(year)
    {:ok, prior_year_gregorian} = new_year_gregorian(year - 1)

    new_year =
      if Date.compare(new_year_gregorian, date) == :gt do
        prior_year_gregorian
      else
        new_year_gregorian
      end

    Calendrical.Gregorian.date_to_iso_days(new_year.year, new_year.month, new_year.day)
  end
end
