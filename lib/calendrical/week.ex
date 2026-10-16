defmodule Calendrical.Week do
  @moduledoc """
  The weeks of any calendar, asked of the calendar module.

  A calendar's weeks follow the rule its `c:Calendrical.info/0` states:
  the day they begin on and the fewest days of a year or a month that
  week 1 holds. Every function here takes the calendar as its first
  argument and answers for every calendar Calendrical builds, so a caller
  asks `Calendrical.Week.week_of_year(calendar, year, month, day)` and
  never asks the calendar whether it can answer.

  Until the week rule is computed here for every calendar, each function
  puts the question to the calendar's own callback, so the answers are
  the calendar's answers today.

  """

  @typedoc "A calendar module."
  @type calendar :: module()

  @doc """
  Returns the week-year and the week of the year a date is in, in the
  calendar's own weeks.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week}`, or

  * `{:error, reason}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.week_of_year(Calendrical.Gregorian, 2025, 12, 31)
      {2026, 1}

      iex> Calendrical.Week.week_of_year(Calendrical.Hebrew, 5786, 7, 15)
      {5786, 28}

  """
  @spec week_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week()} | {:error, term()}
  def week_of_year(calendar, year, month, day) do
    calendar.week_of_year(year, month, day)
  end

  @doc """
  Returns the ISO 8601 week-year and week of the day a date names,
  whichever calendar names it.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week}` of ISO 8601, or

  * `{:error, reason}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.iso_week_of_year(Calendrical.Hebrew, 5786, 7, 15)
      {2026, 14}

  """
  @spec iso_week_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week()} | {:error, term()}
  def iso_week_of_year(calendar, year, month, day) do
    calendar.iso_week_of_year(year, month, day)
  end

  @doc """
  Returns the month and the week of the month a date is in, in the
  calendar's own weeks.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{month, week}`, or

  * `{:error, reason}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.week_of_month(Calendrical.Gregorian, 2026, 1, 15)
      {1, 3}

      # The week holding 1 February is February's week 1
      iex> Calendrical.Week.week_of_month(Calendrical.Gregorian, 2026, 1, 31)
      {2, 1}

  """
  @spec week_of_month(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.month(), Calendrical.week()} | {:error, term()}
  def week_of_month(calendar, year, month, day) do
    calendar.week_of_month(year, month, day)
  end

  @doc """
  Returns the number of weeks in a year of the calendar.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * The weeks, as the calendar counts them today: `{weeks, days_in_last_week}`
    for a calendar whose weeks are cut at the year's ends and a count for
    one whose weeks are whole, or

  * `{:error, reason}` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Week.weeks_in_year(Calendrical.Gregorian, 2026)
      {52, 7}

  """
  @spec weeks_in_year(calendar, Calendar.year()) ::
          {Calendrical.week(), Calendar.day()} | pos_integer() | {:error, term()}
  def weeks_in_year(calendar, year) do
    calendar.weeks_in_year(year)
  end

  @doc """
  Returns the days of a week of a year of the calendar.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `week` is a week of that year.

  ### Returns

  * A `t:Date.Range.t/0` of the week's days, or

  * `{:error, reason}` for a week the year does not have.

  ### Examples

      iex> Calendrical.Week.week(Calendrical.ISOWeek, 2026, 25)
      Date.range(~D[2026-06-15 Calendrical.ISOWeek], ~D[2026-06-21 Calendrical.ISOWeek])

  """
  @spec week(calendar, Calendar.year(), Calendrical.week()) :: Date.Range.t() | {:error, term()}
  def week(calendar, year, week) do
    calendar.week(year, week)
  end

  @doc """
  Returns the weeks of a month of a year of the calendar, in order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A list of `t:Date.Range.t/0`, one for each week `week_of_month/4`
    names for the month, or

  * `{:error, exception}` for a month the year does not have.

  ### Examples

      iex> Calendrical.Week.weeks_of_month(Calendrical.Gregorian, 2026, 2) |> length()
      4

  """
  @spec weeks_of_month(calendar, Calendar.year(), Calendar.month()) ::
          [Date.Range.t()] | {:error, Exception.t()}
  def weeks_of_month(calendar, year, month) do
    calendar.weeks_of_month(year, month)
  end

  @doc """
  Returns the date of a day of a week of a week-year, in the calendar's
  own weeks: the inverse of `week_date_from_date/4`.

  ### Arguments

  * `calendar` is a calendar module.

  * `week_year` and `week` are a week of the calendar.

  * `day` is the day of the week, numbered from the day the calendar's
    weeks begin on.

  ### Returns

  * A `t:Date.t/0` of the calendar, or

  * `{:error, :invalid_date}` where the week has no such day.

  ### Examples

      iex> Calendrical.Week.date_from_week_date(Calendrical.ISOWeek, 2026, 25, 2)
      ~D[2026-06-16 Calendrical.ISOWeek]

      iex> Calendrical.Week.date_from_week_date(Calendrical.Hebrew, 5786, 1, 3)
      ~D[5786-01-01 Calendrical.Hebrew]

  """
  @spec date_from_week_date(calendar, Calendar.year(), Calendrical.week(), Calendar.day_of_week()) ::
          Date.t() | {:error, :invalid_date}
  def date_from_week_date(calendar, week_year, week, day) do
    calendar.date_from_week_date(week_year, week, day)
  end

  @doc """
  Returns the week-year, the week and the day of the week of a date, in
  the calendar's own weeks.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week, day_of_week}`, or

  * `{:error, :invalid_date}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.week_date_from_date(Calendrical.ISOWeek, 2026, 6, 16)
      {2026, 25, 2}

  """
  @spec week_date_from_date(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week(), Calendar.day_of_week()} | {:error, :invalid_date}
  def week_date_from_date(calendar, year, month, day) do
    calendar.week_date_from_date(year, month, day)
  end

  @doc """
  Returns the number of weeks in a week-year, as `date_from_week_date/4`
  counts them.

  ### Arguments

  * `calendar` is a calendar module.

  * `week_year` is a week-year of the calendar.

  ### Returns

  * The number of weeks, or

  * `{:error, :invalid_date}` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Week.weeks_in_week_year(Calendrical.ISOWeek, 2026)
      53

  """
  @spec weeks_in_week_year(calendar, Calendar.year()) :: pos_integer() | {:error, :invalid_date}
  def weeks_in_week_year(calendar, week_year) do
    calendar.weeks_in_week_year(week_year)
  end
end
