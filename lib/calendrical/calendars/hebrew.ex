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

  A Hebrew date's `month` is the month's **position in its year**, as it
  is in every calendar: 1 (*Tishri*) to 12 (*Elul*) in an ordinary year,
  and 1 to 13 in a leap year, whose leap month *Adar I* is month 6. So
  `Date.new/4`, `months_in_year/1` and `days_in_month/2` agree, and the
  months of any year are `1..months_in_year(year)`.

  The months from *Adar I* on therefore sit one place later in a leap
  year. The **traditional** numbering names the same month in every
  year. It follows [RFC 7529](https://www.rfc-editor.org/rfc/rfc7529)
  (and the `monthCode` of JavaScript's Temporal): *Tishri* is 1 and
  *Elul* 12, 6 is *Adar* in an ordinary year and *Adar II* in a leap
  year, and *Adar I* is `{5, :leap}`, the leap month that follows month
  5. `ordinal_month_from_traditional/2` finds a traditional month's position in a year
  and `lunar_month_of_year/2` goes the other way.

  | Month | Ordinary year | Leap year | Traditional | Days |
  |---|---|---|---|---|
  | Tishri | 1 | 1 | 1 | 30 |
  | Heshvan | 2 | 2 | 2 | 29 or 30 |
  | Kislev | 3 | 3 | 3 | 30 or 29 |
  | Tevet | 4 | 4 | 4 | 29 |
  | Shevat | 5 | 5 | 5 | 30 |
  | Adar I | — | 6 | `{5, :leap}` | 30 |
  | Adar / Adar II | 6 | 7 | 6 | 29 |
  | Nisan | 7 | 8 | 7 | 30 |
  | Iyar | 8 | 9 | 8 | 29 |
  | Sivan | 9 | 10 | 9 | 30 |
  | Tamuz | 10 | 11 | 10 | 29 |
  | Av | 11 | 12 | 11 | 30 |
  | Elul | 12 | 13 | 12 | 29 |

  *Heshvan* is long in 355- and 385-day years, and *Kislev* is short
  in 353- and 383-day years.

  Month names come from CLDR, whose Hebrew data numbers the months 1
  (*Tishri*) to 13 (*Elul*) with 6 for *Adar I*, whether or not the
  year has it. `month_of_year/3` returns that CLDR number, which is
  how `Calendrical.localize/3` names a date's month, and
  `Calendrical.month_names/2` lists the names by it.

  Days are assumed to begin at midnight rather than at sunset.

  ## Reference

  Algorithms are taken from Dershowitz & Reingold, *Calendrical
  Calculations* (4th ed.), Chapter 8, "The Hebrew Calendar", which
  numbers the months from *Nisan*; this module numbers them by their
  position in the year, from *Tishri*.

  """

  use Calendrical.Behaviour,
    epoch: Date.new!(-3761, 10, 7, Calendrical.Julian),
    cldr_calendar_type: :hebrew,
    months_in_ordinary_year: 12,
    months_in_leap_year: 13,
    first_day_of_week: 7

  @type year :: pos_integer()
  @type month :: 1..13
  @type day :: 1..30

  @typedoc """
  A traditional Hebrew month (RFC 7529): `1..12`, or `{5, :leap}` for
  *Adar I*.
  """
  @type traditional_month :: 1..12 | {5, :leap}

  # The leap month, Adar I, is the 6th month of a leap year and follows
  # traditional month 5 (Shevat).
  @leap_month 6
  @traditional_leap_month 5

  # CLDR's numbers for the months (1 = Tishri ... 13 = Elul; 6 = Adar I,
  # leap years only). A CLDR number names a month whatever its position in
  # the year, so month lengths are found by it; `cldr_month/2` converts a
  # position to it and `cldr_month_position/2` back.
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
  Returns the quarter of the Hebrew year that holds the given
  `year`, `month`, and `day`. The quarters follow the traditional
  months (Tishri–Kislev, Tevet–Adar, Nisan–Sivan, Tammuz–Elul), so a
  leap year's Adar I and Adar II are both in the second.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is a Hebrew month in the range `1..13`.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * The quarter, `1..4`, or

  * `{:error, :invalid_date}` for a month the year does not have.

  ### Examples

      iex> Calendrical.Hebrew.quarter_of_year(5785, 1, 1)
      1

      iex> Calendrical.Hebrew.quarter_of_year(5787, 7, 1)
      2

  """
  @impl true
  def quarter_of_year(year, month, _day) do
    Calendrical.Period.period_number_of_month(__MODULE__, year, month, 3)
  end

  @doc """
  Returns the number of days in the given Hebrew `year` and `month`.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is the month's position in the year,
    `1..months_in_year(year)`.

  ### Returns

  * The number of days in the month, 29 or 30, or `0` for a month the
    year does not have.

  ### Examples

      iex> Calendrical.Hebrew.days_in_month(5785, 1)
      30

      # Adar I, the 6th month of the leap year 5784
      iex> Calendrical.Hebrew.days_in_month(5784, 6)
      30

      # Adar, the 6th month of the ordinary year 5785
      iex> Calendrical.Hebrew.days_in_month(5785, 6)
      29

      # An ordinary year has no 13th month
      iex> Calendrical.Hebrew.days_in_month(5785, 13)
      0

  """
  @impl true
  @spec days_in_month(year, month) :: 0 | 29 | 30
  def days_in_month(year, month) when is_integer(year) and is_integer(month) do
    cond do
      month not in 1..months_in_year(year) -> 0
      month in [@heshvan, @kislev] -> cldr_month_days(month, days_in_year(year))
      true -> cldr_month_days(cldr_month(year, month), nil)
    end
  end

  def days_in_month(_year, _month), do: 0

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

      # 15 Nisan, the 7th month of the ordinary year 5786
      iex> Calendrical.Hebrew.week_of_year(5786, 7, 15)
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

  An ordinary year has 12 months and a leap year 13.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  * `month` is the month's position in the year.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Hebrew.valid_date?(5785, 1, 30)
      true

      # Elul, the 13th month of the leap year 5784
      iex> Calendrical.Hebrew.valid_date?(5784, 13, 1)
      true

      # An ordinary year has no 13th month
      iex> Calendrical.Hebrew.valid_date?(5785, 13, 1)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= 1 and month in 1..13 and day in 1..30 do
    day <= days_in_month(year, month)
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
      Date.range(~D[5785-01-01 Calendrical.Hebrew], ~D[5785-12-29 Calendrical.Hebrew])

      iex> Calendrical.Hebrew.year(5784)
      Date.range(~D[5784-01-01 Calendrical.Hebrew], ~D[5784-13-29 Calendrical.Hebrew])

  """
  @impl true
  @spec year(year) :: Date.Range.t() | {:error, :invalid_date}
  def year(year) do
    with {:ok, first} <- Date.new(year, 1, 1, __MODULE__),
         elul = months_in_year(year),
         {:ok, last} <- Date.new(year, elul, days_in_month(year, elul), __MODULE__) do
      Date.range(first, last)
    end
  end

  @doc """
  Adds an `increment` number of `date_part`s to a Hebrew date.

  Months are counted in the order of the year, so *Adar I* is counted
  in a leap year. Adding years keeps the traditional month, so *Nisan*
  stays *Nisan* whatever its position, and *Adar I* becomes *Adar* in
  an ordinary year.

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
      {5785, 6, 10}

      # 15 Nisan, the 8th month of the leap year 5784 and the 7th of 5785
      iex> Calendrical.Hebrew.plus(5784, 8, 15, :years, 1)
      {5785, 7, 15}

      # Adar I has 30 days, and Adar, which it becomes, has 29
      iex> Calendrical.Hebrew.plus(5784, 6, 30, :years, 1, coerce: true)
      {5785, 6, 29}

  """
  @impl true
  @spec plus(year, month, day, atom(), integer(), Keyword.t()) :: {year, month, day}
  def plus(year, month, day, date_part, increment, options \\ [])

  def plus(year, month, day, :years, years, options) do
    new_year = year + years
    new_month = cldr_month_position(new_year, cldr_month(year, month))
    {new_year, new_month, coerce_day(new_year, new_month, day, options)}
  end

  def plus(year, month, day, :quarters, quarters, options) do
    plus(year, month, day, :months, quarters * 3, options)
  end

  def plus(year, month, day, :months, months, options) do
    {new_year, new_month} = advance_position(year, month, months)
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

  # The CLDR number of the month at `position` in `year`: an ordinary year
  # has no Adar I, so from Adar on its months are numbered one more than
  # their position.
  defp cldr_month(year, position) do
    if position >= @adar_i and not leap_year?(year), do: position + 1, else: position
  end

  # The position in `year` of the month CLDR numbers `month`. An ordinary
  # year has no Adar I, so it gives Adar's position.
  defp cldr_month_position(year, month) do
    if month > @adar_i and not leap_year?(year), do: month - 1, else: month
  end

  # The length of the month CLDR numbers `month`, in a year of
  # `year_length` days (needed only for Heshvan and Kislev).
  defp cldr_month_days(month, _year_length) when month in @fixed_30_day_months, do: 30
  defp cldr_month_days(month, _year_length) when month in @fixed_29_day_months, do: 29
  defp cldr_month_days(@heshvan, year_length) when year_length in [355, 385], do: 30
  defp cldr_month_days(@heshvan, _year_length), do: 29
  defp cldr_month_days(@kislev, year_length) when year_length in [353, 383], do: 29
  defp cldr_month_days(@kislev, _year_length), do: 30
  defp cldr_month_days(@adar_i, _year_length), do: 30
  defp cldr_month_days(@adar, _year_length), do: 29

  defp coerce_day(year, month, day, options) do
    if Keyword.get(options, :coerce, false) do
      min(day, days_in_month(year, month))
    else
      day
    end
  end

  @doc """
  Returns the CLDR number of the month of a Hebrew date, by which
  `Calendrical.localize/3` finds the month's name.

  CLDR numbers the Hebrew months 1 (*Tishri*) to 13 (*Elul*) with 6
  for *Adar I*, whether or not the year has it, so from *Adar* on a
  month of an ordinary year is numbered one more than its position.
  *Adar II* is returned as `{7, :leap}`, so that
  `Calendrical.localize/3` picks CLDR's `7_yeartype_leap` name for
  it. For the traditional month, see `lunar_month_of_year/2`.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is the month's position in the year.

  * `day` is a Hebrew day-of-month.

  ### Returns

  * The CLDR month number, or `{7, :leap}` for *Adar II*.

  ### Examples

      # Nisan, the 7th month of the ordinary year 5785
      iex> Calendrical.Hebrew.month_of_year(5785, 7, 1)
      8

      # Adar II, the 7th month of the leap year 5784
      iex> Calendrical.Hebrew.month_of_year(5784, 7, 1)
      {7, :leap}

  """
  @impl true
  def month_of_year(year, month, _day) when is_integer(year) and is_integer(month) do
    cldr_month = cldr_month(year, month)
    if cldr_month == @adar and leap_year?(year), do: {@adar, :leap}, else: cldr_month
  end

  def month_of_year(_year, month, _day), do: month

  @doc """
  Returns the position in a year of a traditional Hebrew month.

  The traditional numbering, from RFC 7529, names the same month every
  year: 1 (*Tishri*) to 12 (*Elul*), with 6 for *Adar*, which is
  *Adar II* in a leap year, and `{5, :leap}` for *Adar I*, the leap
  month that follows month 5. From *Adar I* on, the months of a leap
  year sit one place later.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  * `month` is a traditional month, `1..12` or `{5, :leap}`.

  ### Returns

  * `{:ok, month}` where `month` is the month's position in the year.

  * `{:error, :invalid_leap_month}` for a leap month the year does not
    have: `{5, :leap}` in an ordinary year, or any other leap month.

  * `{:error, :invalid_month}` for any other value.

  ### Examples

      # Nisan is the 7th month of an ordinary year and the 8th of a leap year
      iex> Calendrical.Hebrew.ordinal_month_from_traditional(5785, 7)
      {:ok, 7}

      iex> Calendrical.Hebrew.ordinal_month_from_traditional(5784, 7)
      {:ok, 8}

      iex> Calendrical.Hebrew.ordinal_month_from_traditional(5784, {5, :leap})
      {:ok, 6}

      iex> Calendrical.Hebrew.ordinal_month_from_traditional(5785, {5, :leap})
      {:error, :invalid_leap_month}

  """
  @spec ordinal_month_from_traditional(Calendar.year(), traditional_month()) ::
          {:ok, Calendar.month()} | {:error, :invalid_month | :invalid_leap_month}
  def ordinal_month_from_traditional(year, month)
      when is_integer(year) and is_integer(month) and month in 1..12 do
    if month > @traditional_leap_month and leap_year?(year),
      do: {:ok, month + 1},
      else: {:ok, month}
  end

  def ordinal_month_from_traditional(year, {@traditional_leap_month, :leap})
      when is_integer(year) do
    if leap_year?(year), do: {:ok, @leap_month}, else: {:error, :invalid_leap_month}
  end

  def ordinal_month_from_traditional(year, {_month, :leap}) when is_integer(year),
    do: {:error, :invalid_leap_month}

  def ordinal_month_from_traditional(_year, _month), do: {:error, :invalid_month}

  @doc """
  Returns the traditional month of a Hebrew date.

  The traditional numbering is described in `ordinal_month_from_traditional/2`.

  ### Arguments

  * `date` is a `t:Date.t/0` in the Hebrew calendar.

  ### Returns

  * The traditional month, `1..12`, or `{5, :leap}` for *Adar I*.

  * `{:error, :invalid_month}` for a value that is not a Hebrew date.

  ### Examples

      iex> Calendrical.Hebrew.lunar_month_of_year(~D[5784-06-01 Calendrical.Hebrew])
      {5, :leap}

      # 15 Nisan 5784, the 8th month of a leap year
      iex> Calendrical.Hebrew.lunar_month_of_year(~D[5784-08-15 Calendrical.Hebrew])
      7

  """
  @spec lunar_month_of_year(Date.t()) ::
          Calendar.month() | {5, :leap} | {:error, :invalid_month}
  def lunar_month_of_year(%Date{year: year, month: month, calendar: __MODULE__}) do
    lunar_month_of_year(year, month)
  end

  def lunar_month_of_year(_date), do: {:error, :invalid_month}

  @doc """
  Returns the traditional month at a position in a Hebrew year.

  This is the inverse of `ordinal_month_from_traditional/2`, which describes the
  traditional numbering.

  ### Arguments

  * `year` is any Hebrew year as an integer.

  * `month` is the month's position in the year.

  ### Returns

  * The traditional month, `1..12`, or `{5, :leap}` for *Adar I*.

  * `{:error, :invalid_month}` when the year has no month at that
    position.

  ### Examples

      iex> Calendrical.Hebrew.lunar_month_of_year(5784, 6)
      {5, :leap}

      # Nisan: the 8th month of a leap year and the 7th of an ordinary one
      iex> Calendrical.Hebrew.lunar_month_of_year(5784, 8)
      7

      iex> Calendrical.Hebrew.lunar_month_of_year(5785, 7)
      7

      iex> Calendrical.Hebrew.lunar_month_of_year(5785, 13)
      {:error, :invalid_month}

  """
  @spec lunar_month_of_year(Calendar.year(), Calendar.month()) ::
          Calendar.month() | {5, :leap} | {:error, :invalid_month}
  def lunar_month_of_year(year, month) when is_integer(year) and is_integer(month) do
    cond do
      month not in 1..months_in_year(year) -> {:error, :invalid_month}
      month < @leap_month or not leap_year?(year) -> month
      month == @leap_month -> {@traditional_leap_month, :leap}
      true -> month - 1
    end
  end

  def lunar_month_of_year(_year, _month), do: {:error, :invalid_month}

  @doc """
  Returns the position of the leap month, *Adar I*, in a Hebrew year.

  ### Arguments

  * `date_or_year` is a Hebrew year as an integer, or a `t:Date.t/0`
    in the Hebrew calendar.

  ### Returns

  * `6`, the position of *Adar I*, in a leap year.

  * `nil` in an ordinary year.

  ### Examples

      iex> Calendrical.Hebrew.leap_month(5784)
      6

      iex> Calendrical.Hebrew.leap_month(5785)
      nil

  """
  @spec leap_month(Date.t() | Calendar.year()) :: 6 | nil
  def leap_month(%Date{year: year, calendar: __MODULE__}), do: leap_month(year)
  def leap_month(year) when is_integer(year), do: if(leap_year?(year), do: @leap_month)
  def leap_month(_date_or_year), do: nil

  @doc """
  Returns the traditional month that the leap month, *Adar I*, follows.

  *Adar I* follows *Shevat*, traditional month 5, so its traditional
  month is `{5, :leap}`.

  ### Arguments

  * `date_or_year` is a Hebrew year as an integer, or a `t:Date.t/0`
    in the Hebrew calendar.

  ### Returns

  * `5` in a leap year.

  * `nil` in an ordinary year.

  ### Examples

      iex> Calendrical.Hebrew.traditional_leap_month(5784)
      5

      iex> Calendrical.Hebrew.traditional_leap_month(5785)
      nil

  """
  @spec traditional_leap_month(Date.t() | Calendar.year()) :: 5 | nil
  def traditional_leap_month(%Date{year: year, calendar: __MODULE__}),
    do: traditional_leap_month(year)

  def traditional_leap_month(year) when is_integer(year),
    do: if(leap_year?(year), do: @traditional_leap_month)

  def traditional_leap_month(_date_or_year), do: nil

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Hebrew `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is the month's position in the year.

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
    new_year = hebrew_new_year(year)
    new_year + month_offset(year, month, new_year) + day - 1
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
    new_year = hebrew_new_year(year)
    year_length = hebrew_new_year(year + 1) - new_year

    {month, day} = find_month(year, iso_days - new_year, 1, year_length)
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

  # The number of days from 1 Tishri of `year`, which is `new_year`, to
  # the first day of the month at position `month`. Only Heshvan and
  # Kislev vary in length, with the length of the year, so that is found
  # once, and only when a month after Heshvan is asked for.
  defp month_offset(_year, month, _new_year) when month <= 1, do: 0
  defp month_offset(_year, 2, _new_year), do: 30

  defp month_offset(year, month, new_year) do
    year_length = hebrew_new_year(year + 1) - new_year
    sum_month_days(year, min(month - 1, months_in_year(year)), year_length, 0)
  end

  # The days in the months at positions 1..`month` of `year`. Explicit
  # recursion rather than Enum.reduce keeps the sum integer-typed under
  # dialyzer; a higher-order fold types its accumulator as any().
  defp sum_month_days(_year, 0, _year_length, sum), do: sum

  defp sum_month_days(year, month, year_length, sum) do
    days = cldr_month_days(cldr_month(year, month), year_length)
    sum_month_days(year, month - 1, year_length, sum + days)
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

  # The month of `year`, walking from position `month`, that holds the
  # day `offset` days after the month's first day, and the day of that
  # month.
  defp find_month(year, offset, month, year_length) do
    days = cldr_month_days(cldr_month(year, month), year_length)

    if offset < days or month >= months_in_year(year) do
      {month, offset + 1}
    else
      find_month(year, offset - days, month + 1, year_length)
    end
  end
end
