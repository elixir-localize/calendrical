defmodule Calendrical.Coptic do
  @moduledoc """
  Implementation of the Coptic calendar.

  The Coptic calendar is a 13-month calendar derived from the
  ancient Egyptian calendar, currently used by the Coptic
  Orthodox Church of Alexandria. The first twelve months each
  have 30 days; the thirteenth month (the *epagomenal* month
  Pi Kogi Enavot) has 5 days, or 6 in a leap year.

  The epoch is the start of the Era of Martyrs (anno martyrum),
  29 August 284 CE in the Julian calendar.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0284-08-29 Calendrical.Julian],
    cldr_calendar_type: :coptic,
    months_in_ordinary_year: 13,
    months_in_leap_year: 13

  import Localize.Utils.Math, only: [mod: 2]

  # Coptic does not define quarters; quarter_of_year/3 returns
  # `{:error, :not_defined}` rather than a non_neg_integer.
  @dialyzer [
    {:nowarn_function, quarter_of_year: 3}
  ]

  @type year :: -9999..-1 | 1..9999
  @type month :: 1..13
  @type day :: 1..30

  @months_with_30_days 1..12
  @epoch_day_of_week 6
  @last_day_of_week 5

  @doc """
  Returns whether the supplied `year`, `month`, and `day` is a valid
  Coptic date.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month. Months `1..12` have 30 days;
    month 13 has 5 days, or 6 in a leap year.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Coptic.valid_date?(1742, 1, 30)
      true

      iex> Calendrical.Coptic.valid_date?(1743, 13, 6)
      true

      iex> Calendrical.Coptic.valid_date?(1742, 13, 6)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(_year, month, day) when month in @months_with_30_days and day in 1..30 do
    true
  end

  def valid_date?(year, 13, 6) do
    leap_year?(year)
  end

  def valid_date?(_year, 13, day) when day in 1..5 do
    true
  end

  def valid_date?(_year, _month, _day) do
    false
  end

  @doc """
  Returns the year and era for the given Coptic `year`.

  The Coptic calendar has two eras: the current era which starts
  in year 1 and is defined as era `1` (anno martyrum); and a
  second era for years less than 1, defined as era `0`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Coptic.year_of_era(1742)
      {1742, 1}

      iex> Calendrical.Coptic.year_of_era(-50)
      {50, 0}

  """
  @spec year_of_era(year) :: {pos_integer(), 0..1}
  def year_of_era(year) when year > 0, do: {year, 1}
  def year_of_era(year) when year < 0, do: {abs(year), 0}

  @doc """
  Returns the year and era for the Coptic date given by `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Coptic.year_of_era(1742, 1, 1)
      {1742, 1}

  """
  @impl true
  @spec year_of_era(year, month, day) :: {pos_integer(), 0..1}
  def year_of_era(year, _month, _day), do: year_of_era(year)

  @doc """
  Returns the Gregorian year that contains the given Coptic date.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * An integer Gregorian year.

  ### Examples

      iex> Calendrical.Coptic.related_gregorian_year(1742, 1, 1)
      2025

  """
  @impl true
  @spec related_gregorian_year(year, month, day) :: Calendar.year()
  def related_gregorian_year(year, month, day) do
    {gregorian_year, _, _} =
      date_to_iso_days(year, month, day)
      |> Calendar.ISO.date_from_iso_days()

    gregorian_year
  end

  @doc """
  Returns `{:error, :not_defined}` because the Coptic calendar
  does not define quarters; the year has 13 months and so does not
  divide evenly into four quarters.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Coptic.quarter_of_year(1742, 1, 1)
      {:error, :not_defined}

  """
  @impl true
  def quarter_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns the day-of-era and era for the given Coptic `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * A two-tuple `{day_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Coptic.day_of_era(1742, 1, 1)
      {843840, 1}

  """
  @impl true
  @spec day_of_era(year, month, day) :: {non_neg_integer(), 0..1}
  def day_of_era(year, month, day) do
    {_, era} = year_of_era(year)
    days = date_to_iso_days(year, month, day)
    {days + epoch(), era}
  end

  @doc """
  Returns the day of the week for the given Coptic `year`, `month`,
  and `day`.

  Coptic weeks begin on Saturday, so the returned tuple has
  `first_day_of_week = 6` and `last_day_of_week = 5`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  * `starting_on` is `:default` for the calendar's natural week
    boundary (Saturday).

  ### Returns

  * A three-tuple `{day_of_week, first_day_of_week, last_day_of_week}`.

  ### Examples

      iex> Calendrical.Coptic.day_of_week(1742, 1, 1, :default)
      {4, 6, 5}

  """
  @impl true
  @spec day_of_week(
          year,
          month,
          day,
          :default | :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday
        ) :: {1..7, 1 | 6, 5 | 7}
  def day_of_week(year, month, day, :default) do
    days = date_to_iso_days(year, month, day)
    days_after_saturday = rem(days, 7)
    day = Localize.Utils.Math.amod(days_after_saturday + @epoch_day_of_week, days_in_week())

    {day, @epoch_day_of_week, @last_day_of_week}
  end

  # An explicit `starting_on` weekday renumbers the week relative to
  # that start (the ISO convention), while `:default` keeps this
  # calendar's native numbering above. Previously any value other
  # than `:default` raised a FunctionClauseError.
  def day_of_week(year, month, day, starting_on) do
    weekday = Calendrical.iso_days_to_day_of_week(date_to_iso_days(year, month, day))
    {Integer.mod(weekday - weekday_number(starting_on), 7) + 1, 1, 7}
  end

  defp weekday_number(:monday), do: 1
  defp weekday_number(:tuesday), do: 2
  defp weekday_number(:wednesday), do: 3
  defp weekday_number(:thursday), do: 4
  defp weekday_number(:friday), do: 5
  defp weekday_number(:saturday), do: 6
  defp weekday_number(:sunday), do: 7

  @doc """
  Returns the number of days in the given Coptic `year` and `month`.

  Months 1-12 always have 30 days; month 13 has 5 days, or 6
  in a leap year.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  ### Returns

  * An integer number of days.

  ### Examples

      iex> Calendrical.Coptic.days_in_month(1742, 1)
      30

      iex> Calendrical.Coptic.days_in_month(1742, 13)
      5

      iex> Calendrical.Coptic.days_in_month(1743, 13)
      6

  """
  @impl true
  @spec days_in_month(year, month) :: 5..30
  def days_in_month(year, 13) do
    if leap_year?(year), do: 6, else: 5
  end

  def days_in_month(_year, month) when month in @months_with_30_days do
    30
  end

  @doc """
  Returns the number of days in the given Coptic `year`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  ### Returns

  * `365` for an ordinary year or `366` for a leap year.

  ### Examples

      iex> Calendrical.Coptic.days_in_year(1742)
      365

      iex> Calendrical.Coptic.days_in_year(1743)
      366

  """
  @impl true
  @spec days_in_year(year) :: 365..366
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Returns whether the given Coptic `year` is a leap year.

  A Coptic year is a leap year when it is one less than a multiple
  of four (i.e. `rem(year, 4) == 3`).

  ### Arguments

  * `year` is any Coptic year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Coptic.leap_year?(1743)
      true

      iex> Calendrical.Coptic.leap_year?(1742)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    mod(year, 4) == 3
  end

  @doc """
  Returns the number of ISO days for the given Coptic `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Coptic.date_to_iso_days(1742, 1, 1)
      739870

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    (epoch() - 1 + 365 * (year - 1) + :math.floor(year / 4) + 30 * (month - 1) + day)
    |> trunc()
  end

  @doc """
  Returns a Coptic `{year, month, day}` tuple for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Coptic calendar.

  ### Examples

      iex> Calendrical.Coptic.date_from_iso_days(740_000)
      {1742, 5, 11}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    year = trunc(:math.floor((4 * (iso_days - epoch()) + 1463) / 1461))
    month = trunc(:math.floor((iso_days - date_to_iso_days(year, 1, 1)) / 30)) + 1
    day = iso_days + 1 - date_to_iso_days(year, month, 1)

    {year, month, day}
  end
end
