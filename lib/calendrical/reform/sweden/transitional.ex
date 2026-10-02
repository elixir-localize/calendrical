defmodule Calendrical.Reform.Sweden.Transitional do
  @moduledoc """
  The transitional "Swedish calendar" in use between 1700 and 1712.

  In 1700 Sweden began a gradual transition to the Gregorian calendar by
  omitting the leap day that year (there was no 29 February 1700). The plan was
  to drop every leap day from 1700 to 1740, at which point Sweden would have
  aligned with the Gregorian calendar. The plan was abandoned after 1700, so for
  the years 1700 to 1712 Sweden ran a unique calendar that was **one day ahead
  of the Julian calendar** and ten days behind the Gregorian calendar.

  In 1712 Sweden reverted to the Julian calendar by inserting a second leap day
  that year — the only known instance of a **30 February**. From 1 March 1712
  the calendar realigned with the Julian calendar.

  This module models that transitional calendar. It is not intended for direct
  use; it exists as the 1700–1712 segment of the `Calendrical.Reform.Sweden` composite
  calendar. Within that window each date maps to the same physical day as the
  Julian date bearing the same numbers, shifted back by one day, and the date
  30 February 1712 is valid.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0001-01-01 Calendrical.Julian],
    cldr_calendar_type: :gregorian

  # The one physical day that the Swedish calendar labelled 30 February 1712.
  # In the (proleptic) Julian calendar that day is 29 February 1712.
  @february_30_1712 Calendrical.Julian.date_to_iso_days(1712, 2, 29)

  @doc """
  Converts a `year`, `month` and `day` in the transitional Swedish calendar to
  an ISO day number.

  ### Arguments

  * `year`, `month` and `day` are the parts of a Swedish calendar date. From
    1 March 1700 to 30 February 1712 the date runs one day ahead of Julian;
    before and after that window it is the Julian date.

  ### Returns

  * The integer ISO day number of the given date.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.date_to_iso_days(1712, 2, 30) ==
      ...>   Calendrical.Julian.date_to_iso_days(1712, 2, 29)
      true

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) ::
          Calendrical.iso_day_number()
  def date_to_iso_days(year, month, day) do
    Calendrical.Julian.date_to_iso_days(year, month, day) + offset(year, month, day)
  end

  # 1700-03-01 through 1712-02-30 run one day behind Julian (29 February 1700
  # was omitted); before and after that the calendar is Julian. Julian's
  # date_to_iso_days is a non-validating arithmetic formula, so 30 February
  # 1712 rolls to 1 March and the -1 offset brings it back to the physical
  # 29 February 1712.
  defp offset(year, month, day)
       when {year, month, day} >= {1700, 3, 1} and {year, month, day} < {1712, 3, 1},
       do: -1

  defp offset(_year, _month, _day), do: 0

  # The ISO day of 1 March 1700, the window's first day; its last is
  # `@february_30_1712`.
  @first_ahead_day Calendrical.Julian.date_to_iso_days(1700, 3, 1) - 1

  @doc """
  Converts an ISO day number to a `{year, month, day}` in the transitional
  Swedish calendar.

  ### Arguments

  * `iso_days` is an integer ISO day number. Outside the 1700–1712 window
    the result is the Julian date.

  ### Returns

  * A `{year, month, day}` tuple.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.date_from_iso_days(
      ...>   Calendrical.Julian.date_to_iso_days(1712, 2, 29))
      {1712, 2, 30}

  """
  @spec date_from_iso_days(Calendrical.iso_day_number()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  def date_from_iso_days(@february_30_1712), do: {1712, 2, 30}

  def date_from_iso_days(iso_days)
      when iso_days >= @first_ahead_day and iso_days < @february_30_1712 do
    Calendrical.Julian.date_from_iso_days(iso_days + 1)
  end

  def date_from_iso_days(iso_days) do
    Calendrical.Julian.date_from_iso_days(iso_days)
  end

  @doc """
  Returns whether `year` is a leap year in the transitional Swedish calendar.

  Leap years follow the Julian rule, except 1700, whose 29 February was
  omitted; 1712 additionally carried the extra 30 February day.

  ### Arguments

  * `year` is the year to test.

  ### Returns

  * A boolean.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.leap_year?(1704)
      true

      iex> Calendrical.Reform.Sweden.Transitional.leap_year?(1700)
      false

  """
  @impl true
  @spec leap_year?(Calendar.year()) :: boolean()
  def leap_year?(1700), do: false

  def leap_year?(year) do
    Calendrical.Julian.leap_year?(year)
  end

  # Outside its window the calendar is the Julian calendar, whose years have
  # no zero: the year after 1 BC, year -1, is AD 1. `Calendrical.Behaviour`
  # numbers a calendar's years one after another, so everything that steps
  # from one year to the next, and the eras either side of the missing year,
  # is answered here as the Julian calendar answers it.

  @doc """
  Returns whether `year`, `month` and `day` name a date of the transitional
  Swedish calendar.

  There is no year 0, as there is none in the Julian calendar: the year
  before AD 1 is year -1.

  ### Arguments

  * `year`, `month` and `day` are the parts of a date.

  ### Returns

  * A boolean.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.valid_date?(1712, 2, 30)
      true

      iex> Calendrical.Reform.Sweden.Transitional.valid_date?(-1, 12, 31)
      true

      iex> Calendrical.Reform.Sweden.Transitional.valid_date?(0, 6, 15)
      false

  """
  @impl true
  @spec valid_date?(Calendar.year(), Calendar.month(), Calendar.day()) :: boolean()
  def valid_date?(0, _month, _day), do: false

  def valid_date?(year, month, day) do
    super(year, month, day)
  end

  @doc """
  Returns the number of days in `year`: 365 or 366, as in the Julian
  calendar, except in 1700, which lost its leap day, and 1712, which has 367.

  ### Arguments

  * `year` is any year but 0.

  ### Returns

  * The number of days in the year.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.days_in_year(1712)
      367

      iex> Calendrical.Reform.Sweden.Transitional.days_in_year(-1)
      366

  """
  @impl true
  @spec days_in_year(Calendar.year()) :: Calendar.day()
  def days_in_year(year) do
    date_to_iso_days(next_year(year), 1, 1) - date_to_iso_days(year, 1, 1)
  end

  @doc """
  Returns the number of days in `month` of `year`: the Julian month's, except
  in February of 1700, which has 28, and of 1712, which has 30.

  ### Arguments

  * `year` is any year but 0.

  * `month` is a month of the year.

  ### Returns

  * The number of days in the month.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.days_in_month(1712, 2)
      30

      iex> Calendrical.Reform.Sweden.Transitional.days_in_month(-1, 12)
      31

  """
  @impl true
  @spec days_in_month(Calendar.year(), Calendar.month()) :: Calendar.day()
  def days_in_month(year, @months_in_ordinary_year) do
    date_to_iso_days(next_year(year), 1, 1) -
      date_to_iso_days(year, @months_in_ordinary_year, 1)
  end

  def days_in_month(year, month) do
    super(year, month)
  end

  @doc """
  Adds an `increment` number of `date_part`s to a `year`, `month` and `day`.

  Years, quarters and months step over the year 0 the calendar does not have,
  so a year after 15 June 1 BC is 15 June AD 1.

  ### Arguments

  * `year`, `month` and `day` are the parts of a date.

  * `date_part` is `:years`, `:quarters`, `:months`, `:weeks` or `:days`.

  * `increment` is the integer number of `date_part`s to add, which may be
    negative.

  * `options` is a keyword list of options.

  ### Options

  * `:coerce`, when `true`, brings a day the month reached does not have to
    that month's last day. The default is `false`.

  ### Returns

  * A `{year, month, day}` tuple.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.plus(-1, 6, 15, :years, 1)
      {1, 6, 15}

      iex> Calendrical.Reform.Sweden.Transitional.plus(1, 1, 31, :months, -1)
      {-1, 12, 31}

      iex> Calendrical.Reform.Sweden.Transitional.plus(1712, 2, 30, :years, 1, coerce: true)
      {1713, 2, 28}

  """
  @impl true
  @spec plus(
          Calendar.year(),
          Calendar.month(),
          Calendar.day(),
          :years | :quarters | :months | :weeks | :days,
          integer(),
          Keyword.t()
        ) :: {Calendar.year(), Calendar.month(), Calendar.day()}
  def plus(year, month, day, :years, years, options) do
    super(year, month, day, :years, skip_year_zero(year + years, year) - year, options)
  end

  # The month reached is the same whichever year it is in, so a count that
  # crosses the missing year goes twelve months further.
  def plus(year, month, day, :months, months, options) do
    {year_reached, _month, _day} = super(year, month, 1, :months, months, [])
    year_skipped = skip_year_zero(year_reached, year) - year_reached

    super(year, month, day, :months, months + year_skipped * @months_in_ordinary_year, options)
  end

  def plus(year, month, day, date_part, increment, options) do
    super(year, month, day, date_part, increment, options)
  end

  @doc """
  Returns the year of the era and the era of `year`: era 1 from AD 1 and
  era 0 before it, where year -1 is 1 BC.

  ### Arguments

  * `year` is any year but 0.

  ### Returns

  * A `{year_of_era, era}` tuple.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.year_of_era(1712)
      {1712, 1}

      iex> Calendrical.Reform.Sweden.Transitional.year_of_era(-1)
      {1, 0}

  """
  @spec year_of_era(Calendar.year()) :: {Calendar.year(), Calendar.era()}
  def year_of_era(year) do
    Calendrical.Julian.year_of_era(year)
  end

  @doc """
  Returns the year of the era and the era of the date `year`, `month` and
  `day`, as `year_of_era/1` gives them for its year.

  ### Arguments

  * `year`, `month` and `day` are the parts of a date.

  ### Returns

  * A `{year_of_era, era}` tuple, or `{:error, :invalid_date}`.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.year_of_era(-44, 3, 15)
      {44, 0}

  """
  @impl true
  @spec year_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.era()} | Calendrical.date_error()
  def year_of_era(year, _month, _day) do
    year_of_era(year)
  end

  @doc """
  Returns the day of the era and the era of the date `year`, `month` and
  `day`.

  The eras meet where the Julian calendar's do: day 1 of era 1 is 1 January
  AD 1, and the days of era 0 count back from the day before it.

  ### Arguments

  * `year`, `month` and `day` are the parts of a date.

  ### Returns

  * A `{day_of_era, era}` tuple, or `{:error, :invalid_date}`.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.day_of_era(1, 1, 1)
      {1, 1}

      iex> Calendrical.Reform.Sweden.Transitional.day_of_era(-1, 12, 31)
      {1, 0}

  """
  @impl true
  @spec day_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.day(), Calendar.era()} | Calendrical.date_error()
  def day_of_era(year, month, day) do
    {_year_of_era, era} = year_of_era(year)
    iso_days = date_to_iso_days(year, month, day)

    if era == 1, do: {iso_days - epoch() + 1, era}, else: {epoch() - iso_days, era}
  end

  @doc """
  Returns the extended year of the date `year`, `month` and `day`: one number
  for the year through both eras, in which 1 BC, year -1, is 0.

  ### Arguments

  * `year`, `month` and `day` are the parts of a date.

  ### Returns

  * The extended year, or `{:error, :invalid_date}`.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.extended_year(1712, 2, 30)
      1712

      iex> Calendrical.Reform.Sweden.Transitional.extended_year(-1, 6, 15)
      0

  """
  @impl true
  @spec extended_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          Calendar.year() | Calendrical.date_error()
  def extended_year(year, _month, _day) when year < 0 do
    year + 1
  end

  def extended_year(year, _month, _day) do
    year
  end

  defp next_year(-1), do: 1
  defp next_year(year), do: year + 1

  # A count of years that reaches or crosses the missing year 0 goes one
  # year further the way it was going.
  defp skip_year_zero(year, from_year) when year >= 0 and from_year < 0, do: year + 1
  defp skip_year_zero(year, from_year) when year <= 0 and from_year > 0, do: year - 1
  defp skip_year_zero(year, _from_year), do: year
end
