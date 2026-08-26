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

  ### Supported date range

  This calendar is observational: each year begins at the vernal
  equinox observed in Tehran, computed by `Astro.equinox/2`, which
  is accurate only for Gregorian years 1000 to 3000. Date
  conversions therefore support Gregorian years 1001 to 3000
  (approximately Persian years 380 to 2378). Dates outside that
  range raise `Calendrical.UnsupportedDateRangeError`.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-03-20 Calendrical.Julian],
    cldr_calendar_type: :persian,
    first_day_of_week: 6

  @mean_tropical_year 365.24219

  # `Astro.equinox/2` is accurate to within two minutes only for
  # this span of Gregorian years; outside it the equinox — and
  # therefore Nowruz — cannot be computed.
  @supported_gregorian_years 1000..3000

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
  Returns `{year, week_in_year}` for the given Persian date.

  Weeks run Saturday (Shanbeh) through Friday, the
  calendar's own week boundary. Week 1 is the week containing
  1 Farvardin, so a year that opens mid-week has a short
  first week. Every date numbers within its own year; weeks do
  not spill into the adjacent year's numbering.

  ### Arguments

  * `year` is any Persian year as an integer.

  * `month` is a Persian month number.

  * `day` is a Persian day-of-month.

  ### Returns

  * A two-tuple `{year, week_in_year}`.

  ### Examples

      iex> Calendrical.Persian.week_of_year(1404, 1, 1)
      {1404, 1}

      iex> Calendrical.Persian.week_of_year(1404, 7, 1)
      {1404, 28}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()}
  def week_of_year(year, month, day) do
    Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
  end

  @doc """
  Returns the number of weeks in the given Persian `year`.

  ### Arguments

  * `year` is any Persian year as an integer.

  ### Returns

  * A two-tuple `{weeks_in_year, days_in_last_week}` where the
    final week is short when the year does not end on the last
    day of the calendar's week.

  ### Examples

      iex> Calendrical.Persian.weeks_in_year(1404)
      {53, 7}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) :: {Calendrical.week(), Calendar.day()}
  def weeks_in_year(year) do
    Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
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

  * Raises `Calendrical.UnsupportedDateRangeError` if the date falls
    outside the supported range described in the module
    documentation.

  ### Examples

      iex> Calendrical.Persian.date_to_iso_days(1404, 1, 1)
      739696

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) :: integer()
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
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

  * Raises `Calendrical.UnsupportedDateRangeError` if `iso_days`
    falls outside the supported range described in the module
    documentation.

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
        else: ceil((day_of_year - 6) / 30)

    day = iso_days - date_to_iso_days(year, month, 1) + 1
    {year, month, trunc(day)}
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

  * `{:error, :year_out_of_range}` if `year` is outside the
    Gregorian years 1000 to 3000 for which the equinox can be
    computed.

  ### Examples

      iex> Calendrical.Persian.new_year_gregorian(2025)
      {:ok, ~D[2025-03-21]}

      iex> Calendrical.Persian.new_year_gregorian(900)
      {:error, :year_out_of_range}

  """
  @spec new_year_gregorian(Calendar.year()) :: {:ok, Date.t()} | {:error, :year_out_of_range}
  def new_year_gregorian(year) when year in @supported_gregorian_years do
    with {:ok, equinox} <- vernal_equinox(year),
         {:ok, solar_noon} <- midday_in_tehran(equinox) do
      if Time.compare(equinox, solar_noon) in [:gt, :eq] do
        Date.new(equinox.year, equinox.month, equinox.day + 1)
      else
        Date.new(equinox.year, equinox.month, equinox.day)
      end
    end
  end

  def new_year_gregorian(year) when is_integer(year) do
    {:error, :year_out_of_range}
  end

  @doc """
  Returns the Gregorian `Date` of the last day of the Persian year
  that begins in the given Gregorian `year`.

  ### Arguments

  * `year` is the Gregorian year in which the Persian year starts.

  ### Returns

  * `{:ok, date}` where `date` is a `t:Date.t/0` in `Calendar.ISO`,
    one day before the next Persian new year.

  * `{:error, :year_out_of_range}` if `year + 1` is outside the
    Gregorian years 1000 to 3000 for which the equinox can be
    computed.

  ### Examples

      iex> Calendrical.Persian.year_end_gregorian(2025)
      {:ok, ~D[2026-03-20]}

  """
  @spec year_end_gregorian(Calendar.year()) :: {:ok, Date.t()} | {:error, :year_out_of_range}
  def year_end_gregorian(year) do
    with {:ok, new_year} <- new_year_gregorian(year + 1) do
      {:ok, Date.add(new_year, -1)}
    end
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

  * Raises `Calendrical.UnsupportedDateRangeError` if the date falls
    outside the supported Gregorian years 1001 to 3000.

  ### Examples

      iex> Calendrical.Persian.new_year_on_or_before(739_400)
      739330

  """
  @spec new_year_on_or_before(integer()) :: integer()
  def new_year_on_or_before(iso_days) when is_integer(iso_days) do
    {year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    {:ok, date} = Date.new(year, month, day)

    with {:ok, new_year_gregorian} <- new_year_gregorian(year),
         {:ok, prior_year_gregorian} <- new_year_gregorian(year - 1) do
      new_year =
        if Date.compare(new_year_gregorian, date) == :gt do
          prior_year_gregorian
        else
          new_year_gregorian
        end

      Calendrical.Gregorian.date_to_iso_days(new_year.year, new_year.month, new_year.day)
    else
      {:error, :year_out_of_range} ->
        raise Calendrical.UnsupportedDateRangeError,
          calendar: __MODULE__,
          value: date,
          range:
            "Gregorian years #{@supported_gregorian_years.first + 1} " <>
              "to #{@supported_gregorian_years.last}"
    end
  end
end
