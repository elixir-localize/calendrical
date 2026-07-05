defmodule Calendrical.Julian do
  @moduledoc """
  Implements the proleptic Julian calendar.

  The Julian calendar is the calendar introduced by Julius Caesar in
  46 BCE and used throughout Europe until the Gregorian reform of
  1582. It is identical in structure to `Calendrical.Gregorian` —
  12 months, 365 or 366 days, the same month lengths — but uses a
  simpler leap-year rule (every fourth year) and therefore drifts
  about three days every 400 years against the tropical year.

  This module is implemented as a macro module: `use Calendrical.Julian,
  new_year_starting_month_and_day: {1, 1}` builds a Julian variant whose
  year begins on the given month-and-day. The pre-built variants
  `Calendrical.Julian.Jan1`, `Calendrical.Julian.March1`,
  `Calendrical.Julian.March25`, `Calendrical.Julian.Sept1`, and
  `Calendrical.Julian.Dec25` correspond to historical "year-style"
  conventions used in different periods and regions.

  The module itself is also a fully-functional calendar that can be
  used directly (`~D[1500-03-15 Calendrical.Julian]`), in which case
  the year begins on January 1.

  """

  @behaviour Calendar
  @behaviour Calendrical

  @type year :: -9999..-1 | 1..9999
  @type month :: 1..12
  @type day :: 1..31

  @quarters_in_year 4
  @months_in_year 12
  @months_in_quarter 3
  @days_in_week 7

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      @options options
      @before_compile Calendrical.Julian.Compiler
    end
  end

  @doc """
  Returns the CLDR calendar type for this calendar.

  This type is used in support of `Calendrical.localize/3`.

  ### Returns

  * The atom `:gregorian` (the Julian calendar uses the Gregorian
    CLDR variant for month, era and other localised names).

  ### Examples

      iex> Calendrical.Julian.cldr_calendar_type()
      :gregorian

  """
  @spec cldr_calendar_type() :: :gregorian
  @impl Calendrical
  def cldr_calendar_type do
    :gregorian
  end

  @doc """
  Returns the CLDR calendar base for this calendar.

  ### Returns

  * The atom `:month` (the Julian calendar is month-based).

  ### Examples

      iex> Calendrical.Julian.calendar_base()
      :month

  """
  @spec calendar_base() :: :month
  @impl Calendrical
  def calendar_base do
    :month
  end

  @epoch Calendrical.Gregorian.date_to_iso_days(0, 12, 30)

  @doc false
  def epoch do
    @epoch
  end

  @doc """
  Returns whether the supplied `year`, `month`, and `day` is a valid
  Julian date.

  ### Arguments

  * `year` is any Julian year as an integer. The year `0` is not
    valid (the Julian calendar has no year zero).

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month appropriate for the month.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Julian.valid_date?(2024, 2, 29)
      true

      iex> Calendrical.Julian.valid_date?(2023, 2, 29)
      false

      iex> Calendrical.Julian.valid_date?(0, 1, 1)
      false

  """
  @spec valid_date?(Calendar.year(), Calendar.month(), Calendar.day()) :: boolean()
  @impl Calendar
  def valid_date?(0, _month, _day) do
    false
  end

  @months_with_30_days [4, 6, 9, 11]
  def valid_date?(_year, month, day) when month in @months_with_30_days and day in 1..30 do
    true
  end

  @months_with_31_days [1, 3, 5, 7, 8, 10, 12]
  def valid_date?(_year, month, day) when month in @months_with_31_days and day in 1..31 do
    true
  end

  def valid_date?(year, 2, 29) do
    if leap_year?(year), do: true, else: false
  end

  def valid_date?(_year, 2, day) when day in 1..28 do
    true
  end

  def valid_date?(_year, _month, _day) do
    false
  end

  @doc """
  Returns the year and era for the given Julian `year`.

  The Julian calendar has two eras: the current era which starts in
  year 1 and is defined as era `1`; and a second era for years less
  than 1, defined as era `0`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Julian.year_of_era(2025)
      {2025, 1}

      iex> Calendrical.Julian.year_of_era(-50)
      {50, 0}

  """
  @spec year_of_era(year) :: {year, era :: 0..1}
  def year_of_era(year) when year > 0 do
    {year, 1}
  end

  def year_of_era(year) when year <= 0 do
    {abs(year), 0}
  end

  @doc """
  Returns the year and era for the Julian date given by `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * A two-tuple `{year_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Julian.year_of_era(2025, 1, 1)
      {2025, 1}

  """
  @impl Calendar
  @spec year_of_era(year, month, day) :: {year :: Calendar.year(), era :: 0..1}

  def year_of_era(year, _month, _day) do
    year_of_era(year)
  end

  @doc """
  Returns the calendar year as displayed on rendered calendars.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * The integer Julian year.

  ### Examples

      iex> Calendrical.Julian.calendar_year(2025, 1, 1)
      2025

  """
  @spec calendar_year(year, month, day) :: Calendar.year()
  @impl Calendrical
  def calendar_year(year, _month, _day) do
    year
  end

  @doc """
  Returns the proleptic Gregorian year in which the given Julian
  year begins.

  Per TR35 the related year is constant for every date of the
  calendar year: Julian 2025 begins on Gregorian 2025-01-14, so
  every Julian 2025 date — including 2025-12-25, which falls on
  Gregorian 2026-01-07 — has related year 2025.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer proleptic Gregorian year.

  ### Examples

      iex> Calendrical.Julian.related_gregorian_year(2025, 1, 1)
      2025

      iex> Calendrical.Julian.related_gregorian_year(2025, 12, 25)
      2025

  """
  @spec related_gregorian_year(year, month, day) :: Calendar.year()
  @impl Calendrical
  def related_gregorian_year(year, _month, _day) do
    iso_days = date_to_iso_days(year, 1, 1)
    {year, _month, _day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    year
  end

  @doc """
  Returns the extended year as displayed on rendered calendars.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * The integer Julian year.

  ### Examples

      iex> Calendrical.Julian.extended_year(2025, 1, 1)
      2025

  """
  @spec extended_year(year, month, day) :: Calendar.year()
  @impl Calendrical
  def extended_year(year, _month, _day) do
    year
  end

  @doc """
  Returns the cyclic year as displayed on rendered calendars.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * The integer Julian year (the Julian calendar has no cyclic
    component).

  ### Examples

      iex> Calendrical.Julian.cyclic_year(2025, 1, 1)
      2025

  """
  @spec cyclic_year(year, month, day) :: Calendar.year()
  @impl Calendrical
  def cyclic_year(year, _month, _day) do
    year
  end

  @doc """
  Returns the quarter of the year for the given Julian date.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer in the range `1..4`.

  ### Examples

      iex> Calendrical.Julian.quarter_of_year(2025, 4, 1)
      2

  """
  @spec quarter_of_year(year, month, day) :: 1..4
  @impl Calendar
  def quarter_of_year(_year, month, _day) do
    Float.ceil(month / @months_in_quarter)
    |> trunc
  end

  @doc """
  Returns the month of the year for the given Julian date.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * The integer month.

  ### Examples

      iex> Calendrical.Julian.month_of_year(2025, 4, 1)
      4

  """
  @spec month_of_year(year, month, day) :: month
  @impl Calendrical
  def month_of_year(_year, month, _day) do
    month
  end

  @doc """
  Returns `{:error, :not_defined}` because the Julian calendar does
  not define a week-of-year scheme of its own.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Julian.week_of_year(2025, 1, 1)
      {:error, :not_defined}

  """
  @spec week_of_year(year, month, day) :: {:error, :not_defined}
  @impl Calendrical
  def week_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns `{:error, :not_defined}` because ISO weeks are not defined
  for the Julian calendar.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Julian.iso_week_of_year(2025, 1, 1)
      {:error, :not_defined}

  """
  @spec iso_week_of_year(year, month, day) :: {:error, :not_defined}
  @impl Calendrical
  def iso_week_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns `{:error, :not_defined}` because the Julian calendar does
  not define a week-of-month scheme.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Julian.week_of_month(2025, 1, 1)
      {:error, :not_defined}

  """
  @spec week_of_month(year, month, day) :: {pos_integer(), pos_integer()} | {:error, :not_defined}
  @impl Calendrical
  def week_of_month(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns the day-of-era and era for the given Julian date.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * A two-tuple `{day_in_era, era}` where `era` is `0` or `1`.

  ### Examples

      iex> Calendrical.Julian.day_of_era(2025, 1, 1)
      {739267, 1}

      iex> Calendrical.Julian.day_of_era(1, 1, 1)
      {1, 1}

  """
  @spec day_of_era(year, month, day) :: {day :: pos_integer(), era :: 0..1}
  @impl Calendar
  def day_of_era(year, month, day) do
    {_, era} = year_of_era(year)
    days = date_to_iso_days(year, month, day)

    # Day 1 of the CE era is Julian 0001-01-01 (the epoch); the BCE
    # era counts backwards from the day before the epoch.
    if era == 1 do
      {days - epoch() + 1, era}
    else
      {epoch() - days, era}
    end
  end

  @doc """
  Returns the day of the year (1-based) for the given Julian date.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer in the range `1..366`.

  ### Examples

      iex> Calendrical.Julian.day_of_year(2025, 3, 1)
      60

  """
  @spec day_of_year(year, month, day) :: 1..366
  @impl Calendar
  def day_of_year(year, month, day) do
    first_day = date_to_iso_days(year, 1, 1) |> floor()
    this_day = date_to_iso_days(year, month, day) |> floor()
    this_day - first_day + 1
  end

  @doc """
  Returns the day-of-week for the given Julian date.

  The day-of-week is an integer from 1 to 7, where 1 is Monday and 7
  is Sunday.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  * `starting_on` is `:default` for the calendar's natural week
    boundary (Monday).

  ### Returns

  * A three-tuple `{day_of_week, first_day_of_week, last_day_of_week}`.

  ### Examples

      iex> Calendrical.Julian.day_of_week(2025, 1, 1, :default)
      {2, 1, 7}

  """
  @spec day_of_week(year, month, day, 1..7 | :default) ::
          {Calendar.day_of_week(), first_day_of_week :: non_neg_integer(),
           last_day_of_week :: non_neg_integer()}

  @impl Calendar
  @epoch_day_of_week 6
  def day_of_week(year, month, day, :default) do
    days = date_to_iso_days(year, month, day)
    days_after_saturday = rem(days, 7)

    day_of_week =
      Localize.Utils.Math.amod(days_after_saturday + @epoch_day_of_week, @days_in_week)

    {day_of_week, 1, 7}
  end

  @doc """
  Shifts a Julian date by the given `t:Duration.t/0`.

  ### Arguments

  * `year`, `month`, `day` form the Julian date to shift.

  * `duration` is a `t:Duration.t/0`.

  ### Returns

  * A three-tuple `{year, month, day}` representing the shifted
    Julian date.

  ### Examples

      iex> Calendrical.Julian.shift_date(2025, 1, 1, Duration.new!(month: 1))
      {2025, 2, 1}

  """
  @spec shift_date(Calendar.year(), Calendar.month(), Calendar.day(), Duration.t()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}

  @impl Calendar
  def shift_date(year, month, day, duration) do
    Calendrical.shift_date(year, month, day, __MODULE__, duration)
  end

  @doc """
  Shifts a time by the given `t:Duration.t/0`.

  Time arithmetic is delegated to `Calendar.ISO.shift_time/5`.

  ### Arguments

  * `hour`, `minute`, `second`, `microsecond` form the time to shift.

  * `duration` is a `t:Duration.t/0`.

  ### Returns

  * A four-tuple `{hour, minute, second, microsecond}` representing
    the shifted time.

  ### Examples

      iex> Calendrical.Julian.shift_time(12, 0, 0, {0, 0}, Duration.new!(hour: 1))
      {13, 0, 0, {0, 0}}

  """
  @spec shift_time(
          Calendar.hour(),
          Calendar.minute(),
          Calendar.second(),
          Calendar.microsecond(),
          Duration.t()
        ) ::
          {Calendar.hour(), Calendar.minute(), Calendar.second(), Calendar.microsecond()}

  @impl Calendar
  def shift_time(hour, minute, second, microsecond, duration) do
    Calendar.ISO.shift_time(hour, minute, second, microsecond, duration)
  end

  @doc """
  Shifts a naive datetime by the given `t:Duration.t/0`.

  ### Arguments

  * `year`, `month`, `day`, `hour`, `minute`, `second`, `microsecond`
    form the Julian naive datetime to shift.

  * `duration` is a `t:Duration.t/0`.

  ### Returns

  * A seven-tuple `{year, month, day, hour, minute, second, microsecond}`
    representing the shifted Julian naive datetime.

  ### Examples

      iex> Calendrical.Julian.shift_naive_datetime(2025, 1, 1, 12, 0, 0, {0, 0}, Duration.new!(day: 1))
      {2025, 1, 2, 12, 0, 0, {0, 0}}

  """
  @spec shift_naive_datetime(
          Calendar.year(),
          Calendar.month(),
          Calendar.day(),
          Calendar.hour(),
          Calendar.minute(),
          Calendar.second(),
          Calendar.microsecond(),
          Duration.t()
        ) ::
          {
            Calendar.year(),
            Calendar.month(),
            Calendar.day(),
            Calendar.hour(),
            Calendar.minute(),
            Calendar.second(),
            Calendar.microsecond()
          }

  @impl Calendar
  def shift_naive_datetime(year, month, day, hour, minute, second, microsecond, duration) do
    Calendrical.shift_naive_datetime(
      year,
      month,
      day,
      hour,
      minute,
      second,
      microsecond,
      __MODULE__,
      duration
    )
  end

  @doc """
  Returns the number of periods in the given Julian `year`.

  A period corresponds to a month in month-based calendars and a
  week in week-based calendars.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  ### Returns

  * The integer `12` (months per Julian year).

  ### Examples

      iex> Calendrical.Julian.periods_in_year(2025)
      12

  """
  @spec periods_in_year(year) :: Calendar.month()
  @impl Calendrical
  def periods_in_year(_year) do
    @months_in_year
  end

  @doc false
  @impl Calendrical
  def weeks_in_year(_year) do
    {:error, :not_defined}
  end

  @doc """
  Returns the number of days in the given Julian `year`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  ### Returns

  * `365` for an ordinary year or `366` for a leap year.

  ### Examples

      iex> Calendrical.Julian.days_in_year(2024)
      366

      iex> Calendrical.Julian.days_in_year(2025)
      365

  """
  @spec days_in_year(year) :: 365 | 366
  @impl Calendrical
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Returns the number of days in the given Julian `year` and `month`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  ### Returns

  * An integer in the range `28..31`.

  ### Examples

      iex> Calendrical.Julian.days_in_month(2024, 2)
      29

      iex> Calendrical.Julian.days_in_month(2025, 2)
      28

  """
  @spec days_in_month(year, month) :: 28..31
  @impl Calendar

  def days_in_month(year, 2) do
    if leap_year?(year), do: 29, else: 28
  end

  def days_in_month(_year, month) when month in @months_with_30_days do
    30
  end

  def days_in_month(_year, month) when month in @months_with_31_days do
    31
  end

  @doc """
  Returns the number of days in the given month.

  Because February's length depends on whether the year is a leap
  year, this arity-1 form returns `{:error, :unresolved}` for month 2.

  ### Arguments

  * `month` is a month in the range `1..12`.

  ### Returns

  * An integer day count, or `{:error, :unresolved}` for February.

  ### Examples

      iex> Calendrical.Julian.days_in_month(4)
      30

      iex> Calendrical.Julian.days_in_month(2)
      {:error, :unresolved}

  """
  @spec days_in_month(month) :: Calendar.day() | {:error, :unresolved}
  @impl true
  def days_in_month(month) do
    case month do
      2 -> {:error, :unresolved}
      month when month in @months_with_30_days -> 30
      _other -> 31
    end
  end

  @doc """
  Returns the number of days in a Julian week.

  ### Returns

  * The integer `7`.

  ### Examples

      iex> Calendrical.Julian.days_in_week()
      7

  """
  @spec days_in_week() :: 7
  def days_in_week do
    @days_in_week
  end

  @doc """
  Returns a `t:Date.Range.t/0` representing the given Julian `year`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  ### Returns

  * A `t:Date.Range.t/0` spanning all the days of the year.

  ### Examples

      iex> Calendrical.Julian.year(2025)
      Date.range(~D[2025-01-01 Calendrical.Julian], ~D[2025-12-31 Calendrical.Julian])

  """
  @spec year(year) :: Date.Range.t()
  @impl Calendrical
  def year(year) do
    last_month = months_in_year(year)
    days_in_last_month = days_in_month(year, last_month)

    with {:ok, start_date} <- Date.new(year, 1, 1, __MODULE__),
         {:ok, end_date} <- Date.new(year, last_month, days_in_last_month, __MODULE__) do
      Date.range(start_date, end_date)
    end
  end

  @doc """
  Returns a `t:Date.Range.t/0` representing a given quarter of a
  Julian year.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `quarter` is an integer in the range `1..4`.

  ### Returns

  * A `t:Date.Range.t/0` spanning the requested quarter.

  ### Examples

      iex> Calendrical.Julian.quarter(2025, 1)
      Date.range(~D[2025-01-01 Calendrical.Julian], ~D[2025-03-31 Calendrical.Julian])

  """
  @spec quarter(year, Calendrical.quarter()) :: Date.Range.t()
  @impl Calendrical
  def quarter(year, quarter) do
    months_in_quarter = div(months_in_year(year), @quarters_in_year)
    starting_month = months_in_quarter * (quarter - 1) + 1
    starting_day = 1

    ending_month = starting_month + months_in_quarter - 1
    ending_day = days_in_month(year, ending_month)

    with {:ok, start_date} <- Date.new(year, starting_month, starting_day, __MODULE__),
         {:ok, end_date} <- Date.new(year, ending_month, ending_day, __MODULE__) do
      Date.range(start_date, end_date)
    end
  end

  @doc """
  Returns a `t:Date.Range.t/0` representing a given Julian
  year-and-month.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  ### Returns

  * A `t:Date.Range.t/0` spanning the requested month.

  ### Examples

      iex> Calendrical.Julian.month(2025, 2)
      Date.range(~D[2025-02-01 Calendrical.Julian], ~D[2025-02-28 Calendrical.Julian])

  """
  @spec month(year, month) :: Date.Range.t()
  @impl Calendrical
  def month(year, month) do
    starting_day = 1
    ending_day = days_in_month(year, month)

    with {:ok, start_date} <- Date.new(year, month, starting_day, __MODULE__),
         {:ok, end_date} <- Date.new(year, month, ending_day, __MODULE__) do
      Date.range(start_date, end_date)
    end
  end

  @doc """
  Returns `{:error, :not_defined}` because the Julian calendar does
  not define a week-of-year scheme.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `week` is the requested week number.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Julian.week(2025, 1)
      {:error, :not_defined}

  """
  @spec week(year, Calendrical.week()) :: {:error, :not_defined}
  @impl Calendrical
  def week(_year, _week) do
    {:error, :not_defined}
  end

  @doc """
  Adds an `increment` of `date_part`s to a Julian `year-month-day`.

  ### Arguments

  * `year`, `month`, `day` form the Julian date to shift.

  * `date_part` is one of `:years`, `:quarters`, `:months`, or
    `:days`.

  * `increment` is the integer number of `date_part`s to add (may
    be negative).

  ### Options

  * `:coerce` (boolean, default `false`) — when `true`, clamps the
    resulting day-of-month to the last valid day of the new month
    if the original day overflows (so adding one month to 31 March
    yields 30 April rather than an invalid date).

  ### Returns

  * A three-tuple `{year, month, day}` representing the shifted
    Julian date.

  ### Examples

      iex> Calendrical.Julian.plus(2025, 1, 1, :years, 1)
      {2026, 1, 1}

      iex> Calendrical.Julian.plus(2025, 1, 1, :months, 1)
      {2025, 2, 1}

      iex> Calendrical.Julian.plus(2025, 1, 1, :days, 1)
      {2025, 1, 2}

  """
  @spec plus(year, month, day, :years | :quarters | :months | :days, integer(), Keyword.t()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  @impl Calendrical
  def plus(year, month, day, date_part, increment, options \\ [])

  def plus(year, month, day, :years, years, options) do
    new_year = skip_year_zero(year + years, year)

    new_day =
      if Keyword.get(options, :coerce, false) do
        max_new_day = days_in_month(new_year, month)
        min(day, max_new_day)
      else
        day
      end

    {new_year, month, new_day}
  end

  def plus(year, month, day, :quarters, quarters, options) do
    months = quarters * @months_in_quarter
    plus(year, month, day, :months, months, options)
  end

  def plus(year, month, day, :months, months, options) do
    months_in_year = months_in_year(year)

    # Normalize a non-positive month from div_amod into the prior
    # year — otherwise subtracting months can produce {2025, -2, 1}.
    {year_increment, new_month} =
      case Localize.Utils.Math.div_amod(month + months, months_in_year) do
        {year_increment, new_month} when new_month > 0 ->
          {year_increment, new_month}

        {year_increment, new_month} ->
          {year_increment - 1, months_in_year + new_month}
      end

    new_year = skip_year_zero(year + year_increment, year)

    new_day =
      if Keyword.get(options, :coerce, false) do
        max_new_day = days_in_month(new_year, new_month)
        min(day, max_new_day)
      else
        day
      end

    {new_year, new_month, new_day}
  end

  def plus(year, month, day, :days, days, _options) do
    iso_days = date_to_iso_days(year, month, day) + days
    date_from_iso_days(iso_days)
  end

  # The Julian calendar has no year zero, so year arithmetic that
  # lands on or crosses zero skips it: year -1 plus one year is
  # year 1, and year 1 minus one year is year -1.
  defp skip_year_zero(new_year, original_year) when new_year >= 0 and original_year < 0 do
    new_year + 1
  end

  defp skip_year_zero(new_year, original_year) when new_year <= 0 and original_year > 0 do
    new_year - 1
  end

  defp skip_year_zero(new_year, _original_year) do
    new_year
  end

  @doc """
  Returns whether the given Julian `year` is a leap year.

  Julian leap years occur every four years (every year divisible
  by 4 — unlike the Gregorian rule, the centurial exceptions do
  not apply).

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Julian.leap_year?(2024)
      true

      iex> Calendrical.Julian.leap_year?(2025)
      false

      iex> Calendrical.Julian.leap_year?(2100)
      true

  """
  @spec leap_year?(year :: Calendar.year()) :: boolean()
  @impl Calendar
  def leap_year?(year) when is_integer(year) do
    Localize.Utils.Math.mod(year, 4) == if year > 0, do: 0, else: 3
  end

  @doc """
  Returns the number of ISO days for the given Julian `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any non-zero Julian year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Julian.date_to_iso_days(2025, 1, 1)
      739630

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    adjustment = adjustment(year, month, day)
    year = if year < 0, do: year + 1, else: year

    epoch() - 1 +
      365 * (year - 1) +
      Integer.floor_div(year - 1, 4) +
      Integer.floor_div(367 * month - 362, @months_in_year) +
      adjustment +
      day
  end

  defp adjustment(year, month, _day) do
    cond do
      month <= 2 -> 0
      leap_year?(year) -> -1
      true -> -2
    end
  end

  @doc """
  Returns a Julian `{year, month, day}` tuple for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Julian calendar.

  ### Examples

      iex> Calendrical.Julian.date_from_iso_days(740_000)
      {2026, 1, 6}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    approx = Integer.floor_div(4 * (iso_days - epoch()) + 1464, 1461)
    year = if approx <= 0, do: approx - 1, else: approx
    prior_days = iso_days - date_to_iso_days(year, 1, 1)
    correction = correction(iso_days, year)
    month = Integer.floor_div(@months_in_year * (prior_days + correction) + 373, 367)
    day = 1 + (iso_days - date_to_iso_days(year, month, 1))

    {year, month, day}
  end

  defp correction(iso_days, year) do
    cond do
      iso_days < date_to_iso_days(year, 3, 1) -> 0
      leap_year?(year) -> 1
      true -> 2
    end
  end

  @doc """
  Returns the `t:Calendar.iso_days/0` form of the given Julian naive
  datetime.

  ### Arguments

  * `year`, `month`, `day`, `hour`, `minute`, `second`, `microsecond`
    form the Julian naive datetime.

  ### Returns

  * A `t:Calendar.iso_days/0` `{days, day_fraction}` tuple.

  ### Examples

      iex> Calendrical.Julian.naive_datetime_to_iso_days(2025, 1, 1, 12, 0, 0, {0, 0})
      {739630, {43_200_000_000, 86_400_000_000}}

  """
  @impl Calendar
  @spec naive_datetime_to_iso_days(
          Calendar.year(),
          Calendar.month(),
          Calendar.day(),
          Calendar.hour(),
          Calendar.minute(),
          Calendar.second(),
          Calendar.microsecond()
        ) :: Calendar.iso_days()

  def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
    {date_to_iso_days(year, month, day), time_to_day_fraction(hour, minute, second, microsecond)}
  end

  @doc """
  Returns the Julian naive-datetime tuple for the given
  `t:Calendar.iso_days/0`.

  ### Arguments

  * `iso_days` is a `t:Calendar.iso_days/0` `{days, day_fraction}`
    tuple.

  ### Returns

  * A seven-tuple `{year, month, day, hour, minute, second, microsecond}`.

  ### Examples

      iex> Calendrical.Julian.naive_datetime_from_iso_days({739630, {43_200_000_000, 86_400_000_000}})
      {2025, 1, 1, 12, 0, 0, {0, 6}}

  """
  @spec naive_datetime_from_iso_days(Calendar.iso_days()) :: {
          Calendar.year(),
          Calendar.month(),
          Calendar.day(),
          Calendar.hour(),
          Calendar.minute(),
          Calendar.second(),
          Calendar.microsecond()
        }
  @impl Calendar
  def naive_datetime_from_iso_days({days, day_fraction}) do
    {year, month, day} = date_from_iso_days(days)
    {hour, minute, second, microsecond} = time_from_day_fraction(day_fraction)
    {year, month, day, hour, minute, second, microsecond}
  end

  @doc false
  @impl Calendar
  defdelegate iso_days_to_beginning_of_day(iso_days), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate iso_days_to_end_of_day(iso_days), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate day_rollover_relative_to_midnight_utc, to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate months_in_year(year), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate time_from_day_fraction(day_fraction), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate parse_date(date_string), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate parse_time(time_string), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate parse_utc_datetime(dt_string), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate parse_naive_datetime(dt_string), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate date_to_string(year, month, day), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate datetime_to_string(
                year,
                month,
                day,
                hour,
                minute,
                second,
                microsecond,
                time_zone,
                zone_abbr,
                utc_offset,
                std_offset
              ),
              to: Calendar.ISO

  @doc false
  defdelegate datetime_to_string(
                year,
                month,
                day,
                hour,
                minute,
                second,
                microsecond,
                time_zone,
                zone_abbr,
                utc_offset,
                std_offset,
                format
              ),
              to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate naive_datetime_to_string(
                year,
                month,
                day,
                hour,
                minute,
                second,
                microsecond
              ),
              to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate time_to_string(hour, minute, second, microsecond), to: Calendar.ISO

  @doc false
  @impl Calendar
  defdelegate valid_time?(hour, minute, second, microsecond), to: Calendar.ISO
end
