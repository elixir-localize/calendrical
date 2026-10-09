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
    months_in_leap_year: 13,
    first_day_of_week: 7

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
  Returns the year and era for the given Coptic `year`.

  The Coptic calendar has one era, anno martyrum (era `1`), whose
  year 1 began on 29 August 284. CLDR defines no era before it, so
  the years before its first are year 0, -1 and so on of the same
  era, as Temporal numbers them.

  ### Arguments

  * `year` is any Coptic year as an integer.

  ### Returns

  * A two-tuple `{year, 1}`.

  ### Examples

      iex> Calendrical.Coptic.year_of_era(1742)
      {1742, 1}

      iex> Calendrical.Coptic.year_of_era(0)
      {0, 1}

      iex> Calendrical.Coptic.year_of_era(-50)
      {-50, 1}

  """
  @spec year_of_era(year) :: {year, 1}
  def year_of_era(year) do
    {year, 1}
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

  ### Examples

      iex> Calendrical.Coptic.year_of_era(1742, 1, 1)
      {1742, 1}

  """
  @impl true
  @spec year_of_era(year, month, day) :: {year, 1}
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
    Egyptian.related_gregorian_year(year, month, day, epoch())
  end

  @doc """
  Returns the quarter of the Coptic year that holds the given
  `year`, `month`, and `day`: three months each, with the thirteenth
  month (the epagomenal days) in the fourth.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  ### Returns

  * The quarter, `1..4`, or

  * `{:error, :invalid_date}` for a month the year does not have.

  ### Examples

      iex> Calendrical.Coptic.quarter_of_year(1742, 1, 1)
      1

      iex> Calendrical.Coptic.quarter_of_year(1742, 13, 1)
      4

  """
  @impl true
  def quarter_of_year(year, month, _day) do
    Calendrical.Period.period_number_of_month(__MODULE__, year, month, 3)
  end

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
  Returns the day of the week for the given Coptic `year`, `month`,
  and `day`.

  The Coptic liturgical week begins on Sunday (Ⲧⲕⲩⲣⲓⲁⲕⲏ, the
  Lord's Day), so days number Sunday = 1 through Saturday = 7.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month in the range `1..13`.

  * `day` is a Coptic day-of-month.

  * `starting_on` is `:default` for the calendar's natural
    Sunday-first numbering, or an explicit weekday
    (`:monday` .. `:sunday`) to renumber the week relative to
    that start.

  ### Returns

  * A three-tuple `{day_of_week, first_day_of_week, last_day_of_week}`.

  ### Examples

      iex> Calendrical.Coptic.day_of_week(1742, 1, 1, :default)
      {5, 1, 7}

      iex> Calendrical.Coptic.day_of_week(1742, 1, 1, :monday)
      {4, 1, 7}

  """
  @impl true
  @spec day_of_week(
          year,
          month,
          day,
          :default | :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday
        ) :: {1..7, 1, 7}
  def day_of_week(year, month, day, starting_on) do
    super(year, month, day, starting_on)
  end

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
  def days_in_month(year, month) do
    Egyptian.days_in_month(year, month)
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
    Egyptian.days_in_year(year)
  end

  @doc """
  Returns `{year, week_in_year}` for the given Coptic date.

  Weeks run Sunday (Ⲧⲕⲩⲣⲓⲁⲕⲏ, the Lord's Day) through Saturday, the
  calendar's own week boundary. Week 1 is the week containing
  1 Thoout, so a year that opens mid-week has a short
  first week. Every date numbers within its own year; weeks do
  not spill into the adjacent year's numbering.

  ### Arguments

  * `year` is any Coptic year as an integer.

  * `month` is a Coptic month number.

  * `day` is a Coptic day-of-month.

  ### Returns

  * A two-tuple `{year, week_in_year}`, or

  * `{:error, :invalid_date}` if the date is not valid.

  ### Examples

      iex> Calendrical.Coptic.week_of_year(1742, 1, 1)
      {1742, 1}

      iex> Calendrical.Coptic.week_of_year(1742, 7, 1)
      {1742, 27}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()} | Calendrical.date_error()
  def week_of_year(year, month, day) do
    Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
  end

  @doc """
  Returns the number of weeks in the given Coptic `year`.

  ### Arguments

  * `year` is any Coptic year as an integer.

  ### Returns

  * A two-tuple `{weeks_in_year, days_in_last_week}` where the
    final week is short when the year does not end on the last
    day of the calendar's week, or

  * `{:error, :invalid_date}` if `year` is not valid.

  ### Examples

      iex> Calendrical.Coptic.weeks_in_year(1742)
      {53, 5}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) ::
          {Calendrical.week(), Calendar.day()} | {:error, :invalid_date}
  def weeks_in_year(year) do
    Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
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

  @doc """
  Returns the number of days in the given month, whatever its year.

  Twelve months have 30 days; the thirteenth has 6 in a leap year and 5 otherwise.

  ### Arguments

  * `month` is a month number, 1..13.

  ### Returns

  * The number of days, where the month has as many in every year.

  * `{:ambiguous, range}` where the month's length depends on the year.

  * `{:error, :undefined}` for any other value.

  ### Examples

      iex> Calendrical.Coptic.days_in_month(1)
      30

      iex> Calendrical.Coptic.days_in_month(13)
      {:ambiguous, 5..6}

  """
  @impl true
  def days_in_month(month) when month in 1..12, do: 30
  def days_in_month(13), do: {:ambiguous, 5..6}
  def days_in_month(_month), do: {:error, :undefined}
end
