defmodule Calendrical.Julian do
  @moduledoc """
  Implements the proleptic Julian calendar.

  The Julian calendar is the calendar introduced by Julius Caesar in
  46 BCE and used throughout Europe until the Gregorian reform of
  1582. It is identical in structure to `Calendrical.Gregorian` —
  12 months, 365 or 366 days, the same month lengths — but uses a
  simpler leap-year rule (every fourth year) and therefore drifts
  about three days every 400 years against the tropical year.

  A Julian year begun on another day is a `Calendrical.Calendar.Shifted`
  calendar with this one as its base: `use Calendrical.Calendar.Shifted,
  base: Calendrical.Julian, year_begins: {3, 25}` builds a Julian variant
  whose year begins on the given month and day. The pre-built variants
  `Calendrical.Julian.Jan1`, `Calendrical.Julian.March1`,
  `Calendrical.Julian.March25`, `Calendrical.Julian.Sept1`, and
  `Calendrical.Julian.Dec25` correspond to historical "year-style"
  conventions used in different periods and regions.

  ## Options

  * `:new_year_starting_month_and_day` is the `{month, day}` on which
    the year begins. The default is `{1, 1}`.

  * `:year` is the Julian year, reckoned from 1 January, that a year
    takes its number from: `:beginning`, the one it begins in;
    `:ending`, the one it ends in; or `:majority`, the one most of it
    falls in, which is the first for a year that begins in January to
    June, as for a calendar made by `Calendrical.new/3`. The default is
    `:beginning`.

  ## The number of a year

  A year that begins on another day than 1 January lies across two
  Julian years, and the historical styles differ in which of them gives
  it its number. A year reckoned from 1 March or 25 March began after
  1 January of the same number, and one reckoned from 1 September or
  25 December began before it. C. R. Cheney's *A Handbook of Dates*
  sets out the reckonings from Christmas Day, from the Annunciation
  and from Venice's 1 March, and a Byzantine year of the world begins
  on 1 September, four months before the January year that is 5508
  less:

  | Calendar | Year 1100 begins on | `:year` |
  |---|---|---|
  | `Calendrical.Julian.March1` | 1 March 1100 | `:beginning` |
  | `Calendrical.Julian.March25` | 25 March 1100 | `:beginning` |
  | `Calendrical.Julian.Sept1` | 1 September 1099 | `:ending` |
  | `Calendrical.Julian.Dec25` | 25 December 1099 | `:ending` |

  A variant date carries counted months: month 1 begins on the
  new-year day and the months follow in the order of time, so a date's
  fields order as its days do and `Date.compare/2`,
  `Date.beginning_of_month/1` and `days_in_month/2` hold. A variant
  whose year begins on the first of a Julian month has twelve counted
  months, each a whole Julian month (`March1`'s month 1 is March and
  its month 12 February); one whose year begins part-way through a
  month (`March25`, `Dec25`) has thirteen, the split month's later days
  as a short month 1 and its earlier days as a short month 13: in
  `March25`, month 1 of 2024 is 25–31 March 2024, day 1 being 25 March,
  and month 13 is 1–24 March 2025. The Julian month and day that name a
  date are answered by `cardinal_month/1` and `cardinal_day/3`, and the
  Julian date itself by each variant's `julian_date/3`.

  The module itself is also a fully-functional calendar that can be
  used directly (`~D[1500-03-15 Calendrical.Julian]`), in which case
  the year begins on January 1.

  """

  @behaviour Calendar
  @behaviour Calendrical
  use Calendrical.Compiler.StandardCallbacks
  @before_compile Calendrical.Compiler.DateCheck

  @months_in_year 12
  @months_in_quarter 3
  @days_in_week 7
  @epoch Calendrical.Gregorian.date_to_iso_days(0, 12, 30)
  @months_with_30_days [4, 6, 9, 11]
  @months_with_31_days [1, 3, 5, 7, 8, 10, 12]

  @doc """
  Returns the static facts about this calendar, as
  `t:Calendrical.Info.t/0`: the Julian calendar has no year 0.

  ### Returns

  * A `t:Calendrical.Info.t/0` struct.

  ### Examples

      iex> Calendrical.Julian.info().year_zero?
      false

  """
  @impl true
  def info do
    Calendrical.Info.new(__MODULE__,
      cldr_calendar_type: :gregorian,
      era_calendar_type: :gregorian,
      structure: :months,
      months_in_year: {12, 12},
      years_in_cycle: 28,
      parsing_calendar: __MODULE__,
      epoch: epoch(),
      year_zero?: false,
      weeks: Calendrical.Info.week_rule(1, 1)
    )
  end

  @type year :: -9999..-1 | 1..9999
  @type month :: 1..12
  @type day :: 1..31

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

  def valid_date?(year, month, day)
      when is_integer(year) and month in @months_with_30_days and day in 1..30 do
    true
  end

  def valid_date?(year, month, day)
      when is_integer(year) and month in @months_with_31_days and day in 1..31 do
    true
  end

  def valid_date?(year, 2, 29) when is_integer(year) do
    if leap_year?(year), do: true, else: false
  end

  def valid_date?(year, 2, day) when is_integer(year) and day in 1..28 do
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

  * `{:error, %Calendrical.MissingFieldsError{}}` when `year` is not
    an integer, as for a partial date with no year.

  ### Examples

      iex> Calendrical.Julian.year_of_era(2025)
      {2025, 1}

      iex> Calendrical.Julian.year_of_era(-50)
      {50, 0}

  """
  @spec year_of_era(year) :: {year, era :: 0..1} | Calendrical.date_error()
  def year_of_era(year) when not is_integer(year),
    do: {:error, Calendrical.missing_year_error("year_of_era", year)}

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

  * `{:error, %Calendrical.MissingFieldsError{}}` when `year` is not
    an integer, as for a partial date with no year.

  ### Examples

      iex> Calendrical.Julian.year_of_era(2025, 1, 1)
      {2025, 1}

  """
  @impl Calendar
  @spec year_of_era(year, month, day) ::
          {year :: Calendar.year(), era :: 0..1} | Calendrical.date_error()

  def year_of_era(year, _month, _day) do
    year_of_era(year)
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
  Adds an `increment` of `date_part`s to a Julian `year-month-day`.

  ### Arguments

  * `year`, `month`, `day` form the Julian date to shift.

  * `date_part` is one of `:years`, `:quarters`, `:months`,
    `:weeks`, or `:days`.

  * `increment` is the integer number of `date_part`s to add (may
    be negative).

  ### Options

  * `:clamp` (boolean, default `false`) — when `true`, clamps the
    resulting day-of-month to the last valid day of the new month
    if the original day overflows (so adding one month to 31 March
    yields 30 April rather than an invalid date).

  ### Returns

  * A three-tuple `{year, month, day}` representing the shifted
    Julian date.

  ### Examples

      iex> Calendrical.Julian.shift(2025, 1, 1, :years, 1)
      {2026, 1, 1}

      iex> Calendrical.Julian.shift(2025, 1, 1, :months, 1)
      {2025, 2, 1}

      iex> Calendrical.Julian.shift(2025, 1, 1, :weeks, 1)
      {2025, 1, 8}

      iex> Calendrical.Julian.shift(2025, 1, 1, :days, 1)
      {2025, 1, 2}

  """
  @spec shift(
          year,
          month,
          day,
          :years | :quarters | :months | :weeks | :days,
          integer(),
          Keyword.t()
        ) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  @impl Calendrical
  def shift(year, month, day, date_part, increment, options \\ [])

  def shift(year, month, day, :years, years, options) do
    new_year = skip_year_zero(year + years, year)

    new_day =
      if Keyword.get(options, :clamp, false) do
        max_new_day = days_in_month(new_year, month)
        min(day, max_new_day)
      else
        day
      end

    {new_year, month, new_day}
  end

  def shift(year, month, day, :quarters, quarters, options) do
    months = quarters * @months_in_quarter
    shift(year, month, day, :months, months, options)
  end

  def shift(year, month, day, :months, months, options) do
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
      if Keyword.get(options, :clamp, false) do
        max_new_day = days_in_month(new_year, new_month)
        min(day, max_new_day)
      else
        day
      end

    {new_year, new_month, new_day}
  end

  def shift(year, month, day, :weeks, weeks, options) do
    shift(year, month, day, :days, weeks * @days_in_week, options)
  end

  def shift(year, month, day, :days, days, _options) do
    iso_days = date_to_iso_days(year, month, day) + days
    date_from_iso_days(iso_days)
  end

  @doc """
  Returns the whole number of `date_part`s from one `{year, month, day}`
  to another — the inverse of `shift/6`.

  `date_part` can be `:years`, `:quarters`, `:months`, `:weeks` or
  `:days`. The count is the largest number `shift/6`, clamping the day
  into a shorter month, can add to the earlier date without passing the
  later one; it is negative when `to` is before `from`. There is no year
  zero, so year -1 to year 1 is one year.

  ### Arguments

  * `from` is the starting `{year, month, day}`.

  * `to` is the ending `{year, month, day}`.

  * `date_part` is `:years`, `:quarters`, `:months`, `:weeks` or
    `:days`.

  ### Returns

  * The whole number of `date_part`s from `from` to `to`, as an
    integer.

  ### Examples

      iex> Calendrical.Julian.diff({1582, 10, 4}, {1583, 10, 4}, :months)
      12

      iex> Calendrical.Julian.diff({-1, 6, 1}, {1, 6, 1}, :years)
      1

  """
  @impl Calendrical
  @spec diff({year, month, day}, {year, month, day}, atom()) :: integer()
  def diff(from, to, date_part) do
    Calendrical.Base.Common.diff(__MODULE__, from, to, date_part)
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
  @impl true
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
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
  @impl true
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

  @doc false
  @impl Calendar
  defdelegate months_in_year(year), to: Calendar.ISO
end
