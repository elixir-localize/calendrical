defmodule Calendrical.Hebrew do
  @moduledoc """
  Implementation of the Hebrew (Jewish) calendar.

  The Hebrew calendar is a *lunisolar* calendar with 12 months in an
  ordinary year and 13 months in a leap year. The leap month
  (*Adar I*) is inserted before *Adar* (which becomes *Adar II*) in
  the 3rd, 6th, 8th, 11th, 14th, 17th and 19th years of each 19-year
  *Metonic* cycle.

  Year length varies between 353, 354, 355 (ordinary) and 383, 384,
  385 (leap) days. The variability comes from two of the twelve
  "fixed" months — *Heshvan* (month 2) and *Kislev* (month 3) — which
  can each be either 29 or 30 days, plus the *molad of Tishri* delay
  rules used to keep the calendar aligned with both the lunar and
  solar cycles and to prevent certain holidays from falling on
  prohibited days of the week.

  ## Month numbering

  Months are numbered to match the [CLDR Hebrew calendar
  convention](https://cldr.unicode.org/), with **Tishri = 1** and the
  Hebrew year starting on 1 Tishri. The leap month, *Adar I*, occupies
  position 6 and is **only valid in leap years**. In an ordinary year,
  month 6 does not exist; the calendar goes directly from 5 (Shevat)
  to 7 (Adar).

  | # | Name        | Length | Notes |
  |---|-------------|--------|-------|
  | 1 | Tishri      | 30     | Year start |
  | 2 | Heshvan     | 29 / 30 | (long in 355- and 385-day years) |
  | 3 | Kislev      | 30 / 29 | (short in 353- and 383-day years) |
  | 4 | Tevet       | 29     | |
  | 5 | Shevat      | 30     | |
  | 6 | Adar I      | 30     | **leap years only** |
  | 7 | Adar / Adar II | 29  | "Adar" in ordinary years; "Adar II" in leap years |
  | 8 | Nisan       | 30     | |
  | 9 | Iyar        | 29     | |
  | 10| Sivan       | 30     | |
  | 11| Tamuz       | 29     | |
  | 12| Av          | 30     | |
  | 13| Elul        | 29     | |

  Days are assumed to begin at midnight rather than at sunset.

  ## Reference

  Algorithms are taken from Dershowitz & Reingold, *Calendrical
  Calculations* (4th ed.), Chapter 8, "The Hebrew Calendar". Note
  that Reingold uses Nisan = 1 month numbering internally, while this
  module uses CLDR's Tishri = 1 numbering at the public API; the
  conversion is handled transparently.

  """

  use Calendrical.Behaviour,
    epoch: Date.new!(-3761, 10, 7, Calendrical.Julian),
    cldr_calendar_type: :hebrew,
    months_in_ordinary_year: 12,
    months_in_leap_year: 13,
    first_day_of_week: 7

  # Quarters are not defined for a 12/13-month lunisolar calendar.
  @dialyzer [
    {:nowarn_function, quarter_of_year: 3}
  ]

  @type year :: pos_integer()
  @type month :: 1..13
  @type day :: 1..30

  # CLDR Hebrew month constants (1 = Tishri ... 13 = Elul; 6 = Adar I,
  # leap years only).
  @tishri 1
  @heshvan 2
  @kislev 3
  @tevet 4
  @shevat 5
  @adar_i 6
  @adar 7
  @nisan 8
  @iyar 9
  @sivan 10
  @tamuz 11
  @av 12
  @elul 13

  # Months whose length never depends on the year.
  @fixed_30_day_months [@tishri, @shevat, @nisan, @sivan, @av]
  @fixed_29_day_months [@tevet, @iyar, @tamuz, @elul]

  # Jerusalem (Old City) — the default observation location for the Hebrew day
  # boundary. The offset used for each location is its mean solar time
  # (longitude), which is all the day-boundary reckoning needs.
  @jerusalem %Geo.PointZ{coordinates: {35.2354, 31.7784, 754.0}}

  @doc """
  Returns the Hebrew date in effect at a given instant, under a chosen day-start
  convention.

  The Jewish day begins at sunset — more precisely the date fully changes at
  *nightfall* (tzeit hakochavim) — so in the evening the Hebrew date is already
  the following day. This maps an absolute instant to the Hebrew date, choosing
  the boundary with the `:day_start` option. Unlike the Islamic calendars, whose
  boundary is a fixed canonical city, the Hebrew boundary is the **observer's**
  local sunset, so a `:location` is taken (defaulting to Jerusalem).

  For the plain civil-day mapping (the calendar's default), convert a date
  directly with `Date.convert/2` instead.

  ### Arguments

  * `datetime` is a `t:DateTime.t/0` — an absolute instant. Its own time zone
    fixes the instant; the day boundary is taken at `:location`.

  ### Options

  * `:location` is a `t:Geo.PointZ.t/0` (or `t:Geo.Point.t/0`) giving the
    observer's location. The default is Jerusalem.

  * `:day_start` selects the moment the Hebrew day begins:

    * `:midnight` (the default) — 00:00 local time, the ordinary civil-day
      mapping.

    * `:sunset` — true sunset (shkiah, upper-limb) at `:location`.

    * `:nightfall` — nightfall (tzeit hakochavim), when the sun reaches a chosen
      depression below the horizon. See `:nightfall_angle`.

  * `:nightfall_angle` is the sun's depression below the horizon, in degrees,
    that defines nightfall for `day_start: :nightfall`. The default is `8.5`
    (the common "three small stars" tzeit).

  ### Returns

  * `{:ok, date}` — a Hebrew `t:Date.t/0`.

  * `{:error, reason}` if an option is invalid, or sunset/nightfall cannot be
    computed for the date and location.

  ### Examples

      # Morning in Jerusalem: still the civil-day date.
      iex> {:ok, date} = Calendrical.Hebrew.date_at(~U[2025-03-01 06:00:00Z])
      iex> date.calendar
      Calendrical.Hebrew

  """
  @spec date_at(DateTime.t(), Keyword.t()) :: {:ok, Date.t()} | {:error, term()}
  def date_at(%DateTime{} = datetime, options \\ []) do
    case resolve_location(Keyword.get(options, :location, @jerusalem)) do
      {:ok, location, utc_offset_seconds} ->
        Calendrical.DayStart.date_at(datetime, __MODULE__, location, utc_offset_seconds, options)

      {:error, _reason} = error ->
        error
    end
  end

  # The reference offset is the location's mean solar time: 240 seconds per
  # degree of (east-positive) longitude.
  defp resolve_location(%Geo.PointZ{coordinates: {longitude, _lat, _elev}} = location)
       when is_number(longitude) do
    {:ok, location, round(longitude * 240)}
  end

  defp resolve_location(%Geo.Point{coordinates: {longitude, _lat}} = location)
       when is_number(longitude) do
    {:ok, location, round(longitude * 240)}
  end

  defp resolve_location(other) do
    {:error, {:invalid_location, other}}
  end

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Hebrew `year` is a leap year (i.e. it
  contains the embolismic month *Adar I*).

  Leap years are determined by a 19-year Metonic cycle: years
  3, 6, 8, 11, 14, 17, and 19 of each cycle are leap years.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * `true` if the year contains 13 months; otherwise `false`.

  ### Examples

      iex> Calendrical.Hebrew.leap_year?(5784)
      true

      iex> Calendrical.Hebrew.leap_year?(5785)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Integer.mod(7 * year + 1, 19) < 7
  end

  @doc """
  Returns the number of months in the given Hebrew `year` (12 in an
  ordinary year, 13 in a leap year).

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * `12` for an ordinary year or `13` for a leap year.

  ### Examples

      iex> Calendrical.Hebrew.months_in_year(5785)
      12

      iex> Calendrical.Hebrew.months_in_year(5784)
      13

  """
  @impl true
  @spec months_in_year(year) :: 12..13
  def months_in_year(year) do
    if leap_year?(year), do: 13, else: 12
  end

  @doc """
  Returns `{:error, :not_defined}` because the Hebrew calendar does
  not define quarters; the year has a variable number of months
  (12 or 13) and so does not divide evenly into four quarters.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Hebrew.quarter_of_year(5785, 1, 1)
      {:error, :not_defined}

  """
  @impl true
  def quarter_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns the number of days in the given Hebrew `year` and `month`.

  Month 6 (*Adar I*) only exists in leap years; the function returns
  `0` for month 6 in an ordinary year.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  ### Returns

  * The number of days in the month, between 29 and 30 (or `0` for
    month 6 in an ordinary year).

  ### Examples

      iex> Calendrical.Hebrew.days_in_month(5785, 1)
      30

      iex> Calendrical.Hebrew.days_in_month(5784, 6)
      30

      iex> Calendrical.Hebrew.days_in_month(5785, 6)
      0

  """
  @impl true
  @spec days_in_month(year, month) :: 0..30
  def days_in_month(year, month) when month in 1..13 do
    cond do
      month in @fixed_30_day_months -> 30
      month in @fixed_29_day_months -> 29
      month == @heshvan -> if long_heshvan?(year), do: 30, else: 29
      month == @kislev -> if short_kislev?(year), do: 29, else: 30
      month == @adar_i -> if leap_year?(year), do: 30, else: 0
      month == @adar -> 29
    end
  end

  @doc """
  Returns the total number of days in the given Hebrew `year`.

  Possible values are 353, 354, 355 (ordinary years) and 383, 384,
  385 (leap years).

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * The number of days in the year.

  ### Examples

      iex> Calendrical.Hebrew.days_in_year(5785)
      355

      iex> Calendrical.Hebrew.days_in_year(5784)
      383

  """
  @impl true
  @spec days_in_year(year) :: 353..355 | 383..385
  def days_in_year(year) do
    hebrew_new_year(year + 1) - hebrew_new_year(year)
  end

  @doc """
  Returns `{year, week_in_year}` for the given Hebrew date.

  Weeks run Sunday (Yom Rishon, “first day”) through Shabbat, the
  calendar's own week boundary. Week 1 is the week containing
  1 Tishri, so a year that opens mid-week has a short
  first week. Every date numbers within its own year; weeks do
  not spill into the adjacent year's numbering.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  * `month` is a Hebrew month number.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * A two-tuple `{year, week_in_year}`.

  ### Examples

      iex> Calendrical.Hebrew.week_of_year(5786, 1, 1)
      {5786, 1}

      iex> Calendrical.Hebrew.week_of_year(5786, 8, 15)
      {5786, 28}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()}
  def week_of_year(year, month, day) do
    Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
  end

  @doc """
  Returns the number of weeks in the given Hebrew `year`.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  ### Returns

  * A two-tuple `{weeks_in_year, days_in_last_week}` where the
    final week is short when the year does not end on the last
    day of the calendar's week.

  ### Examples

      iex> Calendrical.Hebrew.weeks_in_year(5786)
      {51, 6}

      iex> Calendrical.Hebrew.weeks_in_year(5787)
      {56, 6}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) :: {Calendrical.week(), Calendar.day()}
  def weeks_in_year(year) do
    Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
  end

  @doc """
  Returns whether the given `year`, `month`, and `day` form a valid
  Hebrew date.

  Month 6 (*Adar I*) is only valid in leap years.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Hebrew.valid_date?(5785, 1, 30)
      true

      iex> Calendrical.Hebrew.valid_date?(5784, 6, 1)
      true

      iex> Calendrical.Hebrew.valid_date?(5785, 6, 1)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= 1 and month in 1..13 and day in 1..30 do
    if month == @adar_i and not leap_year?(year) do
      false
    else
      day <= days_in_month(year, month)
    end
  end

  def valid_date?(_year, _month, _day), do: false

  @doc """
  Returns the `t:Date.Range.t/0` of a Hebrew year, from 1 Tishri to
  the last day of Elul.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * A `t:Date.Range.t/0`, or `{:error, :invalid_date}` when `year` is
    not a Hebrew year.

  ### Examples

      iex> Calendrical.Hebrew.year(5785)
      Date.range(~D[5785-01-01 Calendrical.Hebrew], ~D[5785-13-29 Calendrical.Hebrew])

  """
  @impl true
  @spec year(year) :: Date.Range.t() | {:error, :invalid_date}
  def year(year) do
    with {:ok, first} <- Date.new(year, @tishri, 1, __MODULE__),
         {:ok, last} <- Date.new(year, @elul, days_in_month(year, @elul), __MODULE__) do
      Date.range(first, last)
    end
  end

  @doc """
  Adds an `increment` number of `date_part`s to a Hebrew date.

  Months are counted in the order of the year, so *Adar I* is counted
  in a leap year and passed over in an ordinary one. Adding years keeps
  the month, except that *Adar I* becomes *Adar* in an ordinary year.

  ### Arguments

  * `year`, `month` and `day` are the parts of a Hebrew date.

  * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
    or `:days`. A quarter is three months.

  * `increment` is the integer number of `date_part`s to add. It may be
    negative.

  * `options` is a keyword list of options.

  ### Options

  * `:coerce` — when `true`, a day beyond the end of the resulting
    month becomes that month's last day. The default is `false`.

  ### Returns

  * A `{year, month, day}` tuple.

  ### Examples

      iex> Calendrical.Hebrew.plus(5785, 5, 10, :months, 1)
      {5785, 7, 10}

      iex> Calendrical.Hebrew.plus(5784, 13, 1, :years, 1)
      {5785, 13, 1}

      iex> Calendrical.Hebrew.plus(5784, 6, 30, :years, 1, coerce: true)
      {5785, 7, 29}

  """
  @impl true
  @spec plus(year, month, day, atom(), integer(), Keyword.t()) :: {year, month, day}
  def plus(year, month, day, date_part, increment, options \\ [])

  def plus(year, month, day, :years, years, options) do
    new_year = year + years
    new_month = if month == @adar_i and not leap_year?(new_year), do: @adar, else: month
    {new_year, new_month, coerce_day(new_year, new_month, day, options)}
  end

  def plus(year, month, day, :quarters, quarters, options) do
    plus(year, month, day, :months, quarters * 3, options)
  end

  def plus(year, month, day, :months, months, options) do
    {new_year, position} = advance_position(year, month_position(year, month), months)
    new_month = month_at_position(new_year, position)
    {new_year, new_month, coerce_day(new_year, new_month, day, options)}
  end

  def plus(year, month, day, date_part, increment, options) do
    super(year, month, day, date_part, increment, options)
  end

  # Nineteen years hold 235 months (the Metonic cycle), so a long shift
  # moves whole cycles before walking the remaining years.
  @months_in_cycle 235
  @years_in_cycle 19

  defp advance_position(year, position, months)
       when months >= @months_in_cycle or months <= -@months_in_cycle do
    cycles = div(months, @months_in_cycle)

    advance_position(
      year + cycles * @years_in_cycle,
      position,
      months - cycles * @months_in_cycle
    )
  end

  defp advance_position(year, position, months) when months >= 0 do
    months_in_year = months_in_year(year)

    if position + months <= months_in_year do
      {year, position + months}
    else
      advance_position(year + 1, 1, months - (months_in_year - position + 1))
    end
  end

  defp advance_position(year, position, months) do
    if position + months >= 1 do
      {year, position + months}
    else
      advance_position(year - 1, months_in_year(year - 1), months + position)
    end
  end

  # A month's place in the order of its year: an ordinary year has no
  # Adar I, so the months after it come one place earlier.
  defp month_position(year, month) do
    if month > @adar_i and not leap_year?(year), do: month - 1, else: month
  end

  defp month_at_position(year, position) do
    if position >= @adar_i and not leap_year?(year), do: position + 1, else: position
  end

  defp coerce_day(year, month, day, options) do
    if Keyword.get(options, :coerce, false) do
      min(day, days_in_month(year, month))
    else
      day
    end
  end

  @doc """
  Returns the month-of-year for the given Hebrew date.

  In a leap year, month 7 is *Adar II* and is returned as
  `{7, :leap}` so that `Calendrical.localize/3` picks up the
  CLDR `7_yeartype_leap` variant ("Adar II"). All other months
  are returned as plain integers.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * The plain `month` integer, or `{7, :leap}` for *Adar II*.

  ### Examples

      iex> Calendrical.Hebrew.month_of_year(5785, 7, 1)
      7

      iex> Calendrical.Hebrew.month_of_year(5784, 7, 1)
      {7, :leap}

  """
  @impl true
  def month_of_year(year, month, _day) do
    if month == @adar and leap_year?(year) do
      {@adar, :leap}
    else
      month
    end
  end

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Hebrew `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Hebrew.date_to_iso_days(5785, 1, 1)
      739527

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    hebrew_new_year(year) + day - 1 + month_offset(year, month)
  end

  @doc """
  Returns a Hebrew `{year, month, day}` tuple for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the Hebrew calendar.

  ### Examples

      iex> Calendrical.Hebrew.date_from_iso_days(739_500)
      {5784, 13, 3}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    # Approximate year using the average Hebrew year length
    # (35975351/98496 ≈ 365.2468 days). The result may be one less
    # than the true year, so we search forward from `approx - 1`.
    approx = div((iso_days - epoch()) * 98_496, 35_975_351) + 1
    year = find_year(iso_days, approx - 1)

    month = find_month(iso_days, year, valid_months(year))
    day = iso_days - date_to_iso_days(year, month, 1) + 1

    {year, month, day}
  end

  # ── Year navigation helpers ──────────────────────────────────────────────

  @doc """
  Returns the ISO day number of *1 Tishri* of the given Hebrew `year`
  (the start of the Hebrew year).

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Hebrew.hebrew_new_year(5785)
      739527

  """
  @spec hebrew_new_year(year) :: integer()
  def hebrew_new_year(year) do
    epoch() + hebrew_calendar_elapsed_days(year) + hebrew_year_length_correction(year)
  end

  # Number of days elapsed from the (Sunday) noon prior to the epoch
  # of the Hebrew calendar to the *molad of Tishri* of Hebrew year y,
  # or one day later (the *dehiyyah* — postponements that prevent
  # certain holidays from falling on prohibited weekdays).
  defp hebrew_calendar_elapsed_days(year) do
    months_elapsed = Integer.floor_div(235 * year - 234, 19)
    parts_elapsed = 12_084 + 13_753 * months_elapsed
    days = 29 * months_elapsed + Integer.floor_div(parts_elapsed, 25_920)

    # Apply the *Lo ADU Rosh* postponement: if the molad of Tishri
    # falls on Sunday, Wednesday or Friday, the new year is delayed
    # one day.
    if Integer.mod(3 * (days + 1), 7) < 3 do
      days + 1
    else
      days
    end
  end

  # The remaining year-length corrections that keep ordinary years in
  # the range 353-356 and leap years in 383-386.
  defp hebrew_year_length_correction(year) do
    ny0 = hebrew_calendar_elapsed_days(year - 1)
    ny1 = hebrew_calendar_elapsed_days(year)
    ny2 = hebrew_calendar_elapsed_days(year + 1)

    cond do
      ny2 - ny1 == 356 -> 2
      ny1 - ny0 == 382 -> 1
      true -> 0
    end
  end

  # True when Heshvan (month 2) has 30 days in this year.
  defp long_heshvan?(year) do
    days_in_year(year) in [355, 385]
  end

  # True when Kislev (month 3) has 29 days in this year.
  defp short_kislev?(year) do
    days_in_year(year) in [353, 383]
  end

  # The list of valid CLDR Hebrew month numbers for the given year,
  # in calendar order. In an ordinary year month 6 (Adar I) is
  # omitted; in a leap year all 13 months are present.
  defp valid_months(year) do
    if leap_year?(year) do
      [
        @tishri,
        @heshvan,
        @kislev,
        @tevet,
        @shevat,
        @adar_i,
        @adar,
        @nisan,
        @iyar,
        @sivan,
        @tamuz,
        @av,
        @elul
      ]
    else
      [
        @tishri,
        @heshvan,
        @kislev,
        @tevet,
        @shevat,
        @adar,
        @nisan,
        @iyar,
        @sivan,
        @tamuz,
        @av,
        @elul
      ]
    end
  end

  # Number of days from 1 Tishri of the given year to 1-of-the-given-month
  # of the same year (i.e. the days in all months that come before the
  # target month in the calendar order).
  # Explicit recursion rather than Enum.reduce keeps the summed
  # offset integer-typed under dialyzer; a higher-order fold types
  # its accumulator as any().
  defp month_offset(year, month) do
    year
    |> valid_months()
    |> Enum.take_while(&(&1 != month))
    |> sum_month_days(year, 0)
  end

  defp sum_month_days([], _year, sum), do: sum

  defp sum_month_days([month | months], year, sum) do
    sum_month_days(months, year, sum + days_in_month(year, month))
  end

  # Search forward from a candidate year for the first year whose
  # 1 Tishri is on or before iso_days.
  defp find_year(iso_days, year) do
    if hebrew_new_year(year + 1) > iso_days do
      year
    else
      find_year(iso_days, year + 1)
    end
  end

  # Find the first month in the given list whose last day is on or
  # after iso_days.
  defp find_month(iso_days, year, [month | rest]) do
    last_iso_of_month = date_to_iso_days(year, month, days_in_month(year, month))

    if iso_days <= last_iso_of_month or rest == [] do
      month
    else
      find_month(iso_days, year, rest)
    end
  end
end
