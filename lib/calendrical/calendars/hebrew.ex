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

  use Calendrical.Calendar,
    epoch: Date.new!(-3761, 10, 7, Calendrical.Julian),
    cldr_calendar_type: :hebrew,
    months_in_year: {12, 13},
    weeks: [first_day: 7]

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

  # CLDR's numbers for the months (1 = Tishri ... 13 = Elul; 6 = Adar I,
  # leap years only). A CLDR number names a month whatever its position in
  # the year, so month lengths are found by it; `cldr_number/2` converts a
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

  * `{:error, %Calendrical.InvalidOptionValueError{}}` for an invalid
    `:day_start`, `:nightfall_angle` or `:location`.

  * `{:error, %Calendrical.UnsupportedDateRangeError{}}` for a date outside
    the range the calendar or the installed JPL ephemeris covers.

  * `{:error, %Calendrical.NoDuskError{}}` where the sun does not set, or
    nightfall does not occur, at the location on that day.

  ### Examples

      # Morning in Jerusalem: still the civil-day date.
      iex> {:ok, date} = Calendrical.Hebrew.date_at(~U[2025-03-01 06:00:00Z])
      iex> date.calendar
      Calendrical.Hebrew

  """
  @spec date_at(DateTime.t(), Keyword.t()) :: {:ok, Date.t()} | {:error, Exception.t()}
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
    {:error, Calendrical.InvalidOptionValueError.exception(option: :location, value: other)}
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
  def leap_year?(year) when is_integer(year) do
    Integer.mod(7 * year + 1, 19) < 7
  end

  @doc """
  Returns the number of months in the given Hebrew `year` (12 in an
  ordinary year, 13 in a leap year).

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  ### Returns

  * `12` for an ordinary year or `13` for a leap year, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where `year` is `nil`, or

  * `{:error, %Calendrical.InvalidDateError{}}` where `year` is no integer.

  ### Examples

      iex> Calendrical.Hebrew.months_in_year(5785)
      12

      iex> Calendrical.Hebrew.months_in_year(5784)
      13

  """
  @impl true
  @spec months_in_year(year) :: 12..13 | {:error, Exception.t()}
  def months_in_year(year) do
    if leap_year?(year), do: 13, else: 12
  end

  @doc """
  Returns the number of days in the given Hebrew `year` and `month`.

  ### Arguments

  * `year` is any positive Hebrew year as an integer.

  * `month` is the month's position in the year,
    `1..months_in_year(year)`.

  ### Returns

  * The number of days in the month, 29 or 30, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year does
    not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
    month is `nil`.

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
      {:error, %Calendrical.InvalidMonthError{calendar: Calendrical.Hebrew, year: 5785, month: 13}}

  """
  @impl true
  @spec days_in_month(year, month) :: 29 | 30 | {:error, Exception.t()}
  # A month the year does not have, and a field that is not an integer,
  # are answered before this by `Calendrical.Compiler.DateCheck`.
  def days_in_month(year, month) when month in [@heshvan, @kislev],
    do: cldr_month_days(month, days_in_year(year))

  def days_in_month(year, month), do: cldr_month_days(cldr_number(year, month), nil)

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
    month <= months_in_year(year) and day <= days_in_month(year, month)
  end

  def valid_date?(_year, _month, _day), do: false

  @doc """
  Returns the whole number of `date_part`s from one `{year, month, day}`
  to another, as `shift/6` adds them.

  `date_part` can be `:years`, `:quarters`, `:months`, `:weeks` or
  `:days`. The count is the largest number `shift/6`, clamping the day
  into a shorter month, can add to the earlier date without passing the
  later one; it is negative when `to` is before `from`. Months count a
  leap year's Adar I, and come from the months elapsed before each year
  (235 in every 19), so a span of any length costs the same.

  ### Arguments

  * `from` is the starting `{year, month, day}`.

  * `to` is the ending `{year, month, day}`.

  * `date_part` is `:years`, `:quarters`, `:months`, `:weeks` or
    `:days`.

  ### Returns

  * The whole number of `date_part`s from `from` to `to`, as an
    integer.

  ### Examples

      # 5784 is a leap year of thirteen months, 5785 an ordinary one
      iex> Calendrical.Hebrew.diff({5784, 1, 1}, {5785, 1, 1}, :months)
      13

      iex> Calendrical.Hebrew.diff({5784, 1, 1}, {5786, 1, 1}, :months)
      25

  """
  @impl true
  @spec diff({year, month, day}, {year, month, day}, atom()) :: integer()
  def diff(from, to, date_part) do
    Calendrical.Base.Common.diff(__MODULE__, from, to, date_part, &months_between/3)
  end

  # A month's position counts from Tishri, as the months elapsed before a year
  # do, so the months between two dates are the difference of the two counts.
  defp months_between(
         _calendar,
         {year_from, month_from, _day_from},
         {year_to, month_to, _day_to}
       ),
       do: months_elapsed(year_to) + month_to - (months_elapsed(year_from) + month_from)

  # The CLDR number of the month at `position` in `year`: an ordinary year
  # has no Adar I, so from Adar on its months are numbered one more than
  # their position.
  defp cldr_number(year, position) do
    if position >= @adar_i and not leap_year?(year), do: position + 1, else: position
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

  @doc """
  Returns the position of the leap month, *Adar I*, in a Hebrew year.

  ### Arguments

  * `year` is a Hebrew year as an integer.

  ### Returns

  * `6`, the position of *Adar I*, in a leap year.

  * `nil` in an ordinary year, or for anything but an integer year.

  ### Examples

      iex> Calendrical.Hebrew.leap_month(5784)
      6

      iex> Calendrical.Hebrew.leap_month(5785)
      nil

  """
  @spec leap_month(Calendar.year()) :: 6 | nil
  @impl true
  def leap_month(year) when is_integer(year), do: if(leap_year?(year), do: @leap_month)

  # Anything but a year, a date among them, is no year and has no leap month.
  def leap_month(_not_a_year), do: nil

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
  @impl true
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
  @impl true
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

  # The months from the epoch to Tishri of `year`: 235 in every 19 years.
  defp months_elapsed(year), do: Integer.floor_div(235 * year - 234, 19)

  # Number of days elapsed from the (Sunday) noon prior to the epoch
  # of the Hebrew calendar to the *molad of Tishri* of Hebrew year y,
  # or one day later (the *dehiyyah* — postponements that prevent
  # certain holidays from falling on prohibited weekdays).
  defp hebrew_calendar_elapsed_days(year) do
    months_elapsed = months_elapsed(year)
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
    days = cldr_month_days(cldr_number(year, month), year_length)
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
    days = cldr_month_days(cldr_number(year, month), year_length)

    if offset < days or month >= months_in_year(year) do
      {month, offset + 1}
    else
      find_month(year, offset - days, month + 1, year_length)
    end
  end
end
