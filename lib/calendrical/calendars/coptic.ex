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
  Determines if the date given is valid according to
  this calendar.

  """
  @impl true
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
  Calculates the year and era from the given `year`.

  The Coptic calendar has two eras: the current era which starts
  in year 1 and is defined as era `1` (anno martyrum); and a
  second era for years less than 1, defined as era `0`.

  """
  @spec year_of_era(year) :: {pos_integer(), 0..1}
  def year_of_era(year) when year > 0, do: {year, 1}
  def year_of_era(year) when year < 0, do: {abs(year), 0}

  @impl true
  def year_of_era(year, _month, _day), do: year_of_era(year)

  @doc """
  Calculates the related Gregorian year for a Coptic date by
  converting via ISO days.

  """
  @impl true
  def related_gregorian_year(year, month, day) do
    {gregorian_year, _, _} =
      date_to_iso_days(year, month, day)
      |> Calendar.ISO.date_from_iso_days()

    gregorian_year
  end

  @doc """
  The Coptic calendar does not define quarters because the year
  has 13 months.

  """
  @impl true
  def quarter_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Calculates the day and era from the given `year`, `month`,
  and `day`.

  """
  @impl true
  def day_of_era(year, month, day) do
    {_, era} = year_of_era(year)
    days = date_to_iso_days(year, month, day)
    {days + epoch(), era}
  end

  @doc """
  Returns the day of the week for the given `year`, `month`,
  and `day`.

  Coptic weeks begin on Saturday, so the returned tuple has
  `first_day_of_week = 6` and `last_day_of_week = 5`.

  """
  @impl true
  def day_of_week(year, month, day, :default) do
    days = date_to_iso_days(year, month, day)
    days_after_saturday = rem(days, 7)
    day = Localize.Utils.Math.amod(days_after_saturday + @epoch_day_of_week, days_in_week())

    {day, @epoch_day_of_week, @last_day_of_week}
  end

  @doc """
  Returns the number of days in the given `year` and `month`.

  Months 1-12 always have 30 days; month 13 has 5 days, or 6
  in a leap year.

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
  Returns the number of days in the given `year`.

  """
  @impl true
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Returns whether the given `year` is a Coptic leap year.

  A Coptic year is a leap year when it is one less than a
  multiple of four.

  """
  @impl true
  def leap_year?(year) do
    mod(year, 4) == 3
  end

  @doc """
  Returns the number of ISO days for the given Coptic
  `year`, `month`, and `day`.

  """
  def date_to_iso_days(year, month, day) do
    (epoch() - 1 + 365 * (year - 1) + :math.floor(year / 4) + 30 * (month - 1) + day)
    |> trunc()
  end

  @doc """
  Returns a Coptic `{year, month, day}` for the given ISO day
  number.

  """
  def date_from_iso_days(iso_days) do
    year = :math.floor((4 * (iso_days - epoch()) + 1463) / 1461)
    month = :math.floor((iso_days - date_to_iso_days(year, 1, 1)) / 30) + 1
    day = iso_days + 1 - date_to_iso_days(year, month, 1)

    {trunc(year), trunc(month), trunc(day)}
  end
end
