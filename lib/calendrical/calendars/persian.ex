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

  ### Astronomical and arithmetic years

  This calendar is observational: each year begins on the day of the
  vernal equinox in Tehran (the day after, when the equinox falls after
  noon), computed by `Astro.equinox/2`, which is accurate only for
  Gregorian years 1000 to 3000. Persian years 380 to 2378 begin there.

  Every other year begins as ICU's Persian calendar has it: by the
  33-year arithmetic cycle, with ICU's table of corrections for the
  years after 2378. The two agree on when years 379, 380, 2378 and 2379
  begin, so no year at either join is lengthened or shortened. Years
  are numbered astronomically, as ICU numbers them: the year before 1
  is 0.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-03-20 Calendrical.Julian],
    cldr_calendar_type: :persian,
    first_day_of_week: 6

  # `Astro.equinox/2` is accurate to within two minutes only for
  # this span of Gregorian years; outside it the equinox — and
  # therefore Nowruz — cannot be computed.
  @supported_gregorian_years 1000..3000

  # The Persian years whose start is computed from the equinox: year `y`
  # begins in Gregorian year `y + 621`.
  @astronomical_years 380..2378

  # ICU's arithmetic Persian calendar (`persncal.cpp`): 1 Farvardin 1 is
  # its julian day 1948320, Gregorian 21 March 622, and year `y` begins
  # `365 * (y - 1) + floor((8 * y + 21) / 33)` days later, a day earlier
  # when ICU lists `y - 1` as a common year the cycle makes leap. Only
  # the corrections after the astronomical years are kept.
  @arithmetic_epoch 227_260

  @arithmetic_common_years MapSet.new([
                             2389,
                             2393,
                             2422,
                             2426,
                             2455,
                             2459,
                             2488,
                             2492,
                             2521,
                             2525,
                             2554,
                             2558,
                             2587,
                             2591,
                             2620,
                             2624,
                             2653,
                             2657,
                             2686,
                             2690,
                             2719,
                             2723,
                             2748,
                             2752,
                             2756,
                             2781,
                             2785,
                             2789,
                             2818,
                             2822,
                             2847,
                             2851,
                             2855,
                             2880,
                             2884,
                             2888,
                             2913,
                             2917,
                             2921,
                             2946,
                             2950,
                             2954,
                             2979,
                             2983,
                             2987
                           ])

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

  * A two-tuple `{year, week_in_year}`, or

  * `{:error, :invalid_date}` if the date is not valid.

  ### Examples

      iex> Calendrical.Persian.week_of_year(1404, 1, 1)
      {1404, 1}

      iex> Calendrical.Persian.week_of_year(1404, 7, 1)
      {1404, 28}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()} | Calendrical.date_error()
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
    day of the calendar's week, or

  * `{:error, :invalid_date}` if `year` is not valid.

  ### Examples

      iex> Calendrical.Persian.weeks_in_year(1404)
      {53, 7}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) ::
          {Calendrical.week(), Calendar.day()} | {:error, :invalid_date}
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

  ### Examples

      iex> Calendrical.Persian.date_to_iso_days(1404, 1, 1)
      739696

      iex> Calendrical.Persian.date_to_iso_days(1, 1, 1)
      227260

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) :: integer()
  @impl true
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    new_year(year) - 1 + if(month <= 7, do: 31 * (month - 1), else: 30 * (month - 1) + 6) + day
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

  ### Examples

      iex> Calendrical.Persian.new_year_on_or_before(739_400)
      739330

  """
  @spec new_year_on_or_before(integer()) :: integer()
  def new_year_on_or_before(iso_days) when is_integer(iso_days) do
    {_year, new_year} = year_and_new_year(iso_days)
    new_year
  end

  # The Persian year `iso_days` falls in, and the ISO day it begins on.
  # ICU's cycle places the day within a year of its year, since an
  # astronomical year begins at most a day from the cycle's.
  defp year_and_new_year(iso_days) do
    estimate = Integer.floor_div(33 * (iso_days - @arithmetic_epoch) + 3, 12_053) + 1

    Enum.find_value([estimate - 1, estimate, estimate + 1], fn year ->
      new_year = new_year(year)
      if new_year <= iso_days and iso_days < new_year(year + 1), do: {year, new_year}
    end)
  end

  # The ISO day of 1 Farvardin of `year`.
  defp new_year(year) when year in @astronomical_years do
    {:ok, new_year} = new_year_gregorian(year + 621)
    Date.to_gregorian_days(new_year)
  end

  defp new_year(year) do
    correction = if MapSet.member?(@arithmetic_common_years, year - 1), do: 1, else: 0
    @arithmetic_epoch + 365 * (year - 1) + Integer.floor_div(8 * year + 21, 33) - correction
  end

  @doc """
  Returns the number of days in the given month, whatever its year.

  The first six months have 31 days and the next five 30; the last, Esfand, has 30 in a leap year and 29 otherwise.

  ### Arguments

  * `month` is a month number, 1..12.

  ### Returns

  * The number of days, where the month has as many in every year.

  * `{:ambiguous, range}` where the month's length depends on the year.

  * `{:error, :undefined}` for any other value.

  ### Examples

      iex> Calendrical.Persian.days_in_month(1)
      31

      iex> Calendrical.Persian.days_in_month(7)
      30

      iex> Calendrical.Persian.days_in_month(12)
      {:ambiguous, 29..30}

  """
  @impl true
  def days_in_month(month) when month in 1..6, do: 31
  def days_in_month(month) when month in 7..11, do: 30
  def days_in_month(12), do: {:ambiguous, 29..30}
  def days_in_month(_month), do: {:error, :undefined}
end
