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

  use Calendrical.Calendar,
    epoch: ~D[0284-08-29 Calendrical.Julian],
    cldr_calendar_type: :coptic,
    months_in_year: 13,
    weeks: [first_day: 7],
    years_in_cycle: 28

  alias Calendrical.Base.Egyptian

  @type year :: -9999..9999
  @type month :: 1..13
  @type day :: 1..30

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
  def valid_date?(year, month, day) do
    Egyptian.valid_date?(year, month, day)
  end

  @doc """
  Returns the year and era for the Coptic date given by `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * A two-tuple `{year, 1}`.

  * `{:error, %Calendrical.MissingFieldsError{}}` when `year` is not
    an integer, as for a partial date with no year.

  ### Examples

      iex> Calendrical.Coptic.year_of_era(1742, 1, 1)
      {1742, 1}

  """
  @impl true
  @spec year_of_era(year, month, day) :: {year, 1} | Calendrical.date_error()
  def year_of_era(year, _month, _day), do: {year, 1}

  @doc """
  Returns the day-of-era and era for the given Coptic `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * A two-tuple `{day_in_era, 1}`, counting from 1 Thout of year 1:
    the days before it are day 0, -1 and so on.

  ### Examples

      iex> Calendrical.Coptic.day_of_era(1742, 1, 1)
      {635901, 1}

      iex> Calendrical.Coptic.day_of_era(1, 1, 1)
      {1, 1}

      iex> Calendrical.Coptic.day_of_era(0, 13, 5)
      {0, 1}

  """
  @impl true
  @spec day_of_era(year, month, day) :: {integer(), 1}
  def day_of_era(year, month, day) do
    Calendrical.Era.day_of_era(:coptic, date_to_iso_days(year, month, day))
  end

  @doc """
  Returns the number of days in the given Coptic `year` and `month`.

  Months 1-12 always have 30 days; month 13 has 5 days, or 6
  in a leap year.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  ### Returns

  * An integer number of days, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
    does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
    month is `nil`.

  ### Examples

      iex> Calendrical.Coptic.days_in_month(1742, 1)
      30

      iex> Calendrical.Coptic.days_in_month(1742, 13)
      5

      iex> Calendrical.Coptic.days_in_month(1743, 13)
      6

  """
  @impl true
  @spec days_in_month(year, month) :: 5..30 | {:error, Exception.t()}
  def days_in_month(year, month) do
    Egyptian.days_in_month(year, month)
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
  def leap_year?(year) when is_integer(year) do
    Egyptian.leap_year?(year)
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
  @impl true
  def date_to_iso_days(year, month, day) do
    Egyptian.date_to_iso_days(year, month, day, epoch())
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
  @impl true
  def date_from_iso_days(iso_days) do
    Egyptian.date_from_iso_days(iso_days, epoch())
  end
end
