defmodule Calendrical.Month do
  @moduledoc """
  The months of any calendar, asked of the calendar module: how a month
  is named and numbered, which months a year has and which days a month
  has, and the lengths a month can have.

  A date's month is its position in the year. A calendar names that
  position in two ways. Its traditional number is the number the culture
  gives the month, `n`, or `{n, :leap}` for an intercalary month that
  follows month `n`: in a Chinese year whose leap month follows month 2,
  position 3 is `{2, :leap}` and position 4 is `3`, and in a Hebrew leap
  year position 6, Adar I, is `{5, :leap}`. Its CLDR month is the index
  of its name in the calendar's CLDR data, which is the traditional
  number in every CLDR calendar but the Hebrew, where CLDR gives Adar I a
  number of its own.

  Every function here takes the calendar as its first argument and
  answers for every calendar Calendrical builds. Until the answers are
  computed here from the position of the calendar's leap month and its
  `c:Calendrical.info/0`, each function puts the question to the
  calendar's own callback.

  """

  @typedoc "A calendar module."
  @type calendar :: module()

  @typedoc "A month as a culture names it: its number, or `{number, :leap}` for a leap month."
  @type traditional_month :: Calendar.month() | {Calendar.month(), :leap}

  @doc """
  Returns the CLDR month of a month of a year: the index of its name in
  the calendar's CLDR data, with `{month, :leap}` where the name has a
  leap form.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A CLDR month number, or `{month, :leap}`, or

  * `{:error, reason}` for a month the year does not have.

  ### Examples

      # Nisan, the seventh month of an ordinary Hebrew year, is CLDR's month 8
      iex> Calendrical.Month.cldr_month(Calendrical.Hebrew, 5786, 7)
      8

      # The leap month after the second month of a Chinese year
      iex> Calendrical.Month.cldr_month(Calendrical.Chinese, 4660, 3)
      {2, :leap}

  """
  @spec cldr_month(calendar, Calendar.year(), Calendar.month()) ::
          traditional_month() | {:error, term()}
  def cldr_month(calendar, year, month) do
    calendar.month_of_year(year, month, 1)
  end

  @doc """
  Returns a month of a year as the calendar's culture names it: its
  traditional number, or `{month, :leap}` for a leap month.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A `t:traditional_month/0`, or

  * `{:error, exception}` for a month the year does not have.

  ### Examples

      # Adar I, the sixth month of the Hebrew leap year 5787, follows Shevat, month 5
      iex> Calendrical.Month.traditional_month(Calendrical.Hebrew, 5787, 6)
      {5, :leap}

      iex> Calendrical.Month.traditional_month(Calendrical.Hebrew, 5787, 7)
      6

  """
  @spec traditional_month(calendar, Calendar.year(), Calendar.month()) ::
          traditional_month() | {:error, Exception.t()}
  def traditional_month(calendar, year, month) do
    calendar.traditional_month(year, month)
  end

  @doc """
  Returns the position in a year of a month the calendar's culture
  names: the inverse of `traditional_month/3`.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `traditional_month` is a `t:traditional_month/0`.

  ### Returns

  * The month's position in the year, or

  * `{:error, exception}` where the year has no such month.

  ### Examples

      iex> Calendrical.Month.month_from_traditional(Calendrical.Hebrew, 5787, {5, :leap})
      6

      iex> Calendrical.Month.month_from_traditional(Calendrical.Hebrew, 5786, 6)
      6

  """
  @spec month_from_traditional(calendar, Calendar.year(), traditional_month()) ::
          Calendar.month() | {:error, Exception.t()}
  def month_from_traditional(calendar, year, traditional_month) do
    calendar.month_from_traditional(year, traditional_month)
  end

  @doc """
  Returns a year's months in order, as the calendar's culture names them.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A list of `t:traditional_month/0`, the nth naming the year's nth
    month, and `[]` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Month.traditional_months(Calendrical.Hebrew, 5787)
      [1, 2, 3, 4, 5, {5, :leap}, 6, 7, 8, 9, 10, 11, 12]

  """
  @spec traditional_months(calendar, Calendar.year()) :: [traditional_month()]
  def traditional_months(calendar, year) do
    calendar.traditional_months(year)
  end

  @doc """
  Returns the position of a year's leap month, or `nil` where the year
  has none.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * The leap month's position in the year, or `nil`.

  ### Examples

      iex> Calendrical.Month.leap_month(Calendrical.Hebrew, 5787)
      6

      iex> Calendrical.Month.leap_month(Calendrical.Hebrew, 5786)
      nil

      iex> Calendrical.Month.leap_month(Calendrical.Gregorian, 2026)
      nil

  """
  @spec leap_month(calendar, Calendar.year()) :: Calendar.month() | nil
  def leap_month(calendar, year) do
    case Enum.find_index(traditional_months(calendar, year), &match?({_month, :leap}, &1)) do
      nil -> nil
      index -> index + 1
    end
  end

  @doc """
  Returns the months a year has, as runs of their numbers in order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A list of ranges: one from 1 in every year of every calendar but a
    composite, whose year a change of calendar falls in has the months
    that are left, and `[]` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Month.month_numbers(Calendrical.Hebrew, 5787)
      [1..13]

      # England's 1751 began on 25 March and ended on 31 December
      iex> Calendrical.Month.month_numbers(Calendrical.Reform.England, 1751)
      [3..12]

  """
  @spec month_numbers(calendar, Calendar.year()) :: [Range.t()]
  def month_numbers(calendar, year) do
    calendar.month_numbers(year)
  end

  @doc """
  Returns the days a month of a year has, as runs of their numbers in
  order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A list of ranges: one from 1 in every month of every calendar but a
    composite, whose month a change of calendar falls in has the days
    that are left, and `[]` for a month the year does not have.

  ### Examples

      iex> Calendrical.Month.day_numbers(Calendrical.Gregorian, 2026, 2)
      [1..28]

      # England dropped 3 to 13 September 1752
      iex> Calendrical.Month.day_numbers(Calendrical.Reform.England, 1752, 9)
      [1..2, 14..30]

  """
  @spec day_numbers(calendar, Calendar.year(), Calendar.month()) :: [Range.t()]
  def day_numbers(calendar, year, month) do
    calendar.day_numbers(year, month)
  end

  @doc """
  Returns the fewest and the most months a year of the calendar has.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * `{fewest, most}`, or

  * `{:error, :undefined}` where the calendar cannot say without a year.

  ### Examples

      iex> Calendrical.Month.months_in_year_bounds(Calendrical.Hebrew)
      {12, 13}

      iex> Calendrical.Month.months_in_year_bounds(Calendrical.Reform.England)
      {10, 13}

  """
  @spec months_in_year_bounds(calendar) ::
          {Calendar.month(), Calendar.month()} | {:error, :undefined}
  def months_in_year_bounds(calendar) do
    calendar.months_in_year_bounds()
  end

  @doc """
  Returns the fewest and the most days a month of the calendar has in
  any year.

  ### Arguments

  * `calendar` is a calendar module.

  * `month` is a month of the calendar.

  ### Returns

  * `{fewest, most}`, or

  * `{:error, :undefined}` where the calendar cannot say without a year,
    and `{:error, exception}` for a month the calendar has in no year.

  ### Examples

      iex> Calendrical.Month.days_in_month_bounds(Calendrical.Gregorian, 2)
      {28, 29}

      iex> Calendrical.Month.days_in_month_bounds(Calendrical.Reform.England, 9)
      {19, 30}

  """
  @spec days_in_month_bounds(calendar, Calendar.month()) ::
          {Calendar.day(), Calendar.day()} | {:error, :undefined | Exception.t()}
  def days_in_month_bounds(calendar, month) do
    calendar.days_in_month_bounds(month)
  end

  @doc """
  Returns the days of a named month of a year, in the order of time.

  A calendar that counts its months from the year's first day can split
  the month that names them: `Calendrical.Julian.March25` begins its year
  on 25 March, so its March is two counted months.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `named_month` is the CLDR month that names the month.

  ### Returns

  * A list of `t:Date.Range.t/0`, one for each counted month that carries
    the name, earliest first, and `[]` where none does.

  ### Examples

      iex> Calendrical.Month.named_month(Calendrical.Julian.March25, 1750, 3) |> length()
      2

      iex> Calendrical.Month.named_month(Calendrical.Gregorian, 2026, 2)
      [Date.range(~D[2026-02-01 Calendrical.Gregorian], ~D[2026-02-28 Calendrical.Gregorian])]

  """
  @spec named_month(calendar, Calendar.year(), Calendar.month()) :: [Date.Range.t()]
  def named_month(calendar, year, named_month) do
    calendar.named_month(year, named_month)
  end
end
