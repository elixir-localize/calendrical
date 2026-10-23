defmodule Calendrical.Ethiopic do
  @moduledoc """
  Implementation of the Ethiopic calendar.

  The Ethiopic calendar (Ge'ez calendar) is a 13-month calendar
  used as the principal calendar in Ethiopia and Eritrea. The
  first twelve months each have 30 days; the thirteenth month
  (Pagumē) has 5 days, or 6 in a leap year.

  The epoch is the start of the Era of Mercy (Amete Mihret),
  29 August 8 CE in the Julian calendar.

  """

  use Calendrical.Calendar,
    epoch: ~D[0008-08-29 Calendrical.Julian],
    cldr_calendar_type: :ethiopic,
    months_in_year: 13,
    weeks: [first_day: 7],
    years_in_cycle: 28

  alias Calendrical.Base.Egyptian

  @type year :: -9999..9999
  @type month :: 1..13
  @type day :: 1..30

  @doc """
  Returns whether the supplied `year`, `month`, and `day` is a valid
  Ethiopic date.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month. Months `1..12` have 30 days;
    month 13 has 5 days, or 6 in a leap year.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Ethiopic.valid_date?(2018, 1, 30)
      true

      iex> Calendrical.Ethiopic.valid_date?(2019, 13, 6)
      true

      iex> Calendrical.Ethiopic.valid_date?(2018, 13, 6)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(year, month, day) do
    Egyptian.valid_date?(year, month, day)
  end

  @doc """
  Returns the year and era for the given Ethiopic `year`.

  The Ethiopic calendar has two eras: Amete Mihret, the Era of
  Mercy (era `1`), which numbers the years from 1; and Amete Alem,
  the Era of the World (era `0`), which begins 5500 years earlier
  and numbers the years before it, as CLDR defines it: year 0 is
  Amete Alem 5500.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  * `{:error, %Calendrical.MissingFieldsError{}}` when `year` is not
    an integer, as for a partial date with no year.

  ### Examples

      iex> Calendrical.Ethiopic.year_of_era(2018)
      {2018, 1}

      iex> Calendrical.Ethiopic.year_of_era(0)
      {5500, 0}

      iex> Calendrical.Ethiopic.year_of_era(-50)
      {5450, 0}

  """
  @spec year_of_era(year) :: {integer(), 0..1} | Calendrical.date_error()
  def year_of_era(year) when not is_integer(year),
    do: {:error, Calendrical.missing_year_error("year_of_era", year)}

  def year_of_era(year) when year >= 1 do
    {year, 1}
  end

  def year_of_era(year) do
    {Calendrical.Ethiopic.AmeteAlem.amete_alem_year(year), 0}
  end

  @doc """
  Returns the year and era for the Ethiopic date given by `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  * `{:error, %Calendrical.MissingFieldsError{}}` when `year` is not
    an integer, as for a partial date with no year.

  ### Examples

      iex> Calendrical.Ethiopic.year_of_era(2018, 1, 1)
      {2018, 1}

  """
  @impl true
  @spec year_of_era(year, month, day) :: {integer(), 0..1} | Calendrical.date_error()
  def year_of_era(year, _month, _day), do: year_of_era(year)

  @doc """
  Returns the day-of-era and era for the given Ethiopic `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  ### Returns

  * A two-tuple `{day_in_era, era}` where `era` is `0` or `1`,
    counting from the era's first day: 1 Meskerem of year 1 in
    Amete Mihret and of Amete Alem 1 (year -5499) in Amete Alem.
    The days before Amete Alem are day 0, -1 and so on.

  ### Examples

      iex> Calendrical.Ethiopic.day_of_era(2018, 1, 1)
      {736710, 1}

      iex> Calendrical.Ethiopic.day_of_era(1, 1, 1)
      {1, 1}

      iex> Calendrical.Ethiopic.day_of_era(-5499, 1, 1)
      {1, 0}

  """
  @impl true
  @spec day_of_era(year, month, day) :: {integer(), 0..1}
  def day_of_era(year, month, day) do
    Calendrical.Era.day_of_era(:ethiopic, date_to_iso_days(year, month, day))
  end

  @doc """
  Returns the number of days in the given Ethiopic `year` and `month`.

  Months 1-12 always have 30 days; month 13 has 5 days, or 6
  in a leap year.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  ### Returns

  * An integer number of days, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
    does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
    month is `nil`.

  ### Examples

      iex> Calendrical.Ethiopic.days_in_month(2018, 1)
      30

      iex> Calendrical.Ethiopic.days_in_month(2018, 13)
      5

      iex> Calendrical.Ethiopic.days_in_month(2019, 13)
      6

  """
  @impl true
  @spec days_in_month(year, month) :: 5..30 | {:error, Exception.t()}
  def days_in_month(year, month) do
    Egyptian.days_in_month(year, month)
  end

  @doc """
  Returns whether the given Ethiopic `year` is a leap year.

  An Ethiopic year is a leap year when it is one less than a
  multiple of four (i.e. `rem(year, 4) == 3`).

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Ethiopic.leap_year?(2019)
      true

      iex> Calendrical.Ethiopic.leap_year?(2018)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) when is_integer(year) do
    Egyptian.leap_year?(year)
  end

  @doc """
  Returns the number of ISO days for the given Ethiopic `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Ethiopic year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Ethiopic.date_to_iso_days(2018, 1, 1)
      739870

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  @impl true
  def date_to_iso_days(year, month, day) do
    Egyptian.date_to_iso_days(year, month, day, epoch())
  end

  @doc """
  Returns an Ethiopic `{year, month, day}` tuple for the given ISO
  day number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Ethiopic calendar.

  ### Examples

      iex> Calendrical.Ethiopic.date_from_iso_days(740_000)
      {2018, 5, 11}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  @impl true
  def date_from_iso_days(iso_days) do
    Egyptian.date_from_iso_days(iso_days, epoch())
  end
end
