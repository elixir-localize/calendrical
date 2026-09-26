defmodule Calendrical.Vietnamese do
  @moduledoc """
  Implementation of the Vietnamese lunisolar calendar (âm lịch).

  The Vietnamese calendar is the Chinese lunisolar calendar observed from
  a different meridian: new moons and solar terms are computed for **105°
  East (Hanoi)** rather than Beijing. One year is divided into 12 months
  (13 in a leap year), each running new moon to new moon, so a month has
  29 or 30 days and an ordinary year 353, 354 or 355 days.

  Because the reference meridian differs from China's, the Vietnamese New
  Year (Tết) occasionally falls on a different day — or even a different
  month — from the Chinese New Year. This happens only when a new moon or
  the winter solstice falls in the one-hour window between UTC+7 and
  UTC+8: 1985 (Tết a *month* before Chinese New Year), 2007, 2030 and
  2053 (a day before). In every other year the two coincide.

  ## Reference meridian and its history

  * **From 1 January 1968** the calendar is computed for the **105° East
    (Hanoi) meridian, UTC+7**, following North Vietnam's decree of 8 August
    1967 that switched standard time from UTC+8 to UTC+7.

  * **Before 1968** Vietnam followed the Chinese calendar, so this
    implementation uses the Chinese calendar's meridian for that era —
    Beijing's local apparent time before 1929 and China Standard Time
    (UTC+8) from 1929 — and every pre-1968 date is therefore identical to
    `Calendrical.Chinese`.

  All the documented divergences from the Chinese calendar are after 1968
  and so use UTC+7. This follows Reingold & Dershowitz's *Calendrical
  Calculations* (4th ed.); Hồ Ngọc Đức's published rules instead use a flat
  105° East meridian for every date.

  ## CLDR calendar type

  CLDR has no `vietnamese` calendar type, so this calendar borrows the
  `:chinese` type for localization (month names and the sexagenary
  stem/branch year names), exactly as `Calendrical.LunarJapanese` does.
  The distinction from `Calendrical.Chinese` is the observation meridian,
  not the localized names. There is correspondingly no registered
  `-u-ca-vietnamese` BCP 47 subtag; select this calendar by module (or by
  territory) rather than by a locale-tag calendar key.

  The default epoch is `~D[-2636-02-15]`, the same as the Chinese calendar
  (both share the sexagenary cycle), so a Vietnamese year number equals
  the Chinese year number for the same date. It can be changed by setting
  the `:vietnamese_epoch` configuration key in `config.exs`:

      config :calendrical,
        vietnamese_epoch: ~D[-2636-02-15]

  ## Two month numbering conventions

  The Vietnamese lunisolar calendar (like the Chinese, Korean and Japanese
  ones) has **two distinct month numbering conventions**. Choosing the
  wrong one silently produces dates that are off by one full lunar month
  after the intercalary month in leap years. The conventions are:

  * **Ordinal** — months counted monotonically 1..12 in ordinary years
    and 1..13 in leap years. The intercalary appears at whatever position
    the astronomical no-zhongqi rule places it; it is not separately
    labelled. This is the convention `Date.new/4` accepts, the `Date.t`
    struct stores, and `Date.convert/2` returns. It is what the standard
    `Calendar` behaviour callbacks expect.

  * **Traditional** — months always numbered 1..12, with the intercalary
    expressed as `{month, :leap}` (read *tháng N nhuận* in Vietnamese —
    "intercalary Nth month") where `month` is the *preceding* traditional
    month number. This is the convention used by cultural references and
    primary sources. `#{inspect(__MODULE__)}.new/3` and the return value
    of `lunar_month_of_year/1` use this convention.

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  """
  use Calendrical.Behaviour,
    epoch: Application.compile_env(:calendrical, :vietnamese_epoch, ~D[-2636-02-15]),
    cldr_calendar_type: :chinese,
    months_in_normal_year: 12,
    months_in_leap_year: 13

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  @doc """
  Returns a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar
  formed by a calendar year, a **traditional** lunar month number, and a
  day number.

  The lunar month is that used in traditional lunisolar calendar notation.
  It is either a number between 1 and 12 or a leap month specified by the
  2-tuple `{month, :leap}` where `month` is the preceding traditional
  month number that the intercalary repeats (read *tháng N nhuận* in
  Vietnamese). See the moduledoc for the full ordinal-vs-traditional
  discussion.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `lunar_month` is either a traditional month number between 1 and 12,
    or for an intercalary month the 2-tuple `{month, :leap}` where `month`
    is the preceding traditional month number.

  * `day` is any day number valid for `year` and `lunar_month`.

  ### Returns

  * `{:ok, date}` where `date.month` is the **ordinal** position of the
    given lunar month within the year (1..12 in ordinary years, 1..13 in
    leap years), or

  * `{:error, reason}`.

  ### Examples

      iex> Calendrical.Vietnamese.new(4660, 1, 1)
      {:ok, ~D[4660-01-01 Calendrical.Vietnamese]}

  """
  @spec new(year :: Calendar.year(), month :: Lunisolar.lunar_month(), day :: Calendar.day()) ::
          {:ok, Date.t()} | {:error, atom()}

  def new(year, month, day) do
    with {:ok, {year, month, day}} <-
           Lunisolar.ordinal_date(year, month, day, epoch(), &location/1) do
      {:ok, %Date{year: year, month: month, day: day, calendar: __MODULE__}}
    end
  end

  @doc """
  Raising variant of `new/3`.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is either a traditional month number between 1 and 12, or for
    an intercalary month the 2-tuple `{month, :leap}` where `month` is the
    preceding traditional month number.

  * `day` is a day-of-month valid for the year and month.

  ### Returns

  * A `t:Date.t/0` in `#{inspect(__MODULE__)}`.

  * Raises `ArgumentError` if the date is not valid in this calendar.

  ### Examples

      iex> Calendrical.Vietnamese.new!(4660, 1, 1)
      ~D[4660-01-01 Calendrical.Vietnamese]

  """
  @spec new!(year :: Calendar.year(), month :: Lunisolar.lunar_month(), day :: Calendar.day()) ::
          Date.t()

  def new!(year, month, day) do
    case new(year, month, day) do
      {:ok, date} -> date
      {:error, reason} -> raise ArgumentError, "cannot build date, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Returns a boolean indicating if the given year is a leap year.

  Leap years have 13 months. There is a leap month when 13 new moons fall
  between the start of the 11th month (the month containing the Winter
  Solstice) in one year and the 11th month in the next.

  ### Arguments

  * `date_or_year` is either an integer year number or a
    `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar.

  ### Returns

  * A boolean indicating if the given year is a leap year.

  ### Examples

      iex> Calendrical.Vietnamese.leap_year?(4660)
      true

  """
  @spec leap_year?(date_or_year :: Calendar.year() | Date.t()) :: boolean()
  @impl Calendar

  def leap_year?(%{year: year, calendar: __MODULE__}) do
    leap_year?(year)
  end

  def leap_year?(%{calendar: _other} = date) do
    {:ok, converted} = Date.convert(date, __MODULE__)
    leap_year?(converted.year)
  end

  def leap_year?(year) when is_integer(year) do
    Lunisolar.leap_year?(year, epoch(), &location/1)
  end

  @doc """
  Returns a boolean indicating if the given year and ordinal month is a
  leap month.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * A boolean indicating if the given year and month is a leap month.

  ### Examples

      iex> Calendrical.Vietnamese.leap_month?(4660, 1)
      false

  """
  @spec leap_month?(year :: Calendar.year(), month :: Calendar.month()) :: boolean()
  def leap_month?(year, month) do
    Lunisolar.leap_month?(year, month, epoch(), &location/1)
  end

  @doc """
  Returns a boolean indicating if the given date falls in a leap month.

  ### Arguments

  * `date` is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * A boolean indicating if the given date is in a leap month.

  ### Examples

      iex> Calendrical.Vietnamese.leap_month?(~D[4660-01-01 Calendrical.Vietnamese])
      false

  """
  @spec leap_month?(date :: Date.t()) :: boolean()
  def leap_month?(%Date{calendar: __MODULE__} = date) do
    leap_month?(date.year, date.month)
  end

  @doc """
  Returns the **ordinal** position (1..13) of the leap month for a year,
  or `nil` if the year is not a leap year.

  See `traditional_leap_month/1` for the traditional notation (the
  preceding-month number that the intercalary repeats).

  ### Arguments

  * `date_or_year` is either an integer year number or a
    `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar.

  ### Returns

  * the ordinal position of the leap month (1..13), or

  * `nil` if there is no leap month in the given year.

  ### Examples

      iex> Calendrical.Vietnamese.leap_month(4661)
      nil

  """
  @spec leap_month(date_or_year :: Date.t() | Calendar.year()) :: Calendar.month() | nil
  def leap_month(%Date{year: year, calendar: __MODULE__}) do
    leap_month(year)
  end

  def leap_month(year) do
    Lunisolar.leap_month(year, epoch(), &location/1)
  end

  @doc """
  Returns the **traditional** number (1..12) of the leap month for a year,
  or `nil` if the year is not a leap year.

  The intercalary month repeats the number of the preceding non-leap
  month, written *tháng N nhuận* and used as `{N, :leap}` in this module's
  API.

  ### Arguments

  * `date_or_year` is either an integer year number or a
    `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar.

  ### Returns

  * the traditional number of the leap month (1..12), or

  * `nil` if there is no leap month in the given year.

  ### Examples

      iex> Calendrical.Vietnamese.traditional_leap_month(4661)
      nil

  """
  @spec traditional_leap_month(date_or_year :: Date.t() | Calendar.year()) ::
          Calendar.month() | nil
  def traditional_leap_month(%Date{year: year, calendar: __MODULE__}) do
    traditional_leap_month(year)
  end

  def traditional_leap_month(year) do
    case leap_month(year) do
      nil -> nil
      ordinal -> ordinal - 1
    end
  end

  @doc """
  Returns the year in the lunisolar sexagesimal 60-year cycle.

  Traditionally years are numbered only within the cycle; in this
  implementation the year is an offset from the epoch, and this function
  converts it to the position (1..60) within the current cycle. The cycle
  year forms part of the traditional zodiac shown on lunisolar calendars.

  ### Arguments

  * `date` which is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the integer year within the sexagesimal cycle of 60 years.

  ### Examples

      iex> Calendrical.Vietnamese.cyclic_year(~D[4660-01-01 Calendrical.Vietnamese])
      40

  """
  @spec cyclic_year(date :: Date.t()) :: Lunisolar.cycle()
  def cyclic_year(%Date{year: year, month: month, calendar: __MODULE__}) do
    cyclic_year(year, month)
  end

  @doc """
  Returns the year in the lunisolar sexagesimal 60-year cycle for a given
  calendar year and month.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the integer year within the sexagesimal cycle of 60 years.

  ### Examples

      iex> Calendrical.Vietnamese.cyclic_year(4660, 1)
      40

  """
  @spec cyclic_year(year :: Calendar.year(), month :: Calendar.month()) :: Lunisolar.cycle()
  def cyclic_year(year, month) when is_integer(year) and is_integer(month) do
    Lunisolar.cyclic_year(year, month, 1)
  end

  @doc """
  Returns the lunar month of the year in **traditional** notation for a
  given date, or year and ordinal month.

  Returns either a month number between 1 and 12 or, for the intercalary,
  the 2-tuple `{month, :leap}`. The value can be passed to
  `#{inspect(__MODULE__)}.new/3`.

  ### Arguments

  * `date` which is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the lunar month as either an integer between 1 and 12 or a tuple of
    the form `{lunar_month, :leap}`.

  ### Examples

      iex> Calendrical.Vietnamese.lunar_month_of_year(~D[4660-01-01 Calendrical.Vietnamese])
      1

  """
  @spec lunar_month_of_year(date :: Date.t()) :: Lunisolar.lunar_month()
  def lunar_month_of_year(%Date{year: year, month: month, calendar: __MODULE__}) do
    lunar_month_of_year(year, month)
  end

  @doc """
  Returns the lunar month of the year in **traditional** notation for a
  given calendar year and ordinal month.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the lunar month as either an integer between 1 and 12 or a tuple of
    the form `{lunar_month, :leap}`.

  ### Examples

      iex> Calendrical.Vietnamese.lunar_month_of_year(4660, 1)
      1

  """
  @spec lunar_month_of_year(year :: Calendar.year(), month :: Calendar.month()) ::
          Lunisolar.lunar_month()
  def lunar_month_of_year(year, month) do
    Lunisolar.lunar_month_of_year(year, month, 1, epoch(), &location/1)
  end

  @doc """
  Returns the Gregorian date for a given Gregorian year and lunar month
  and day.

  ### Arguments

  * `gregorian_year` is any year in the Gregorian calendar.

  * `lunar_month` is either a traditional month number between 1 and 12 or
    for a leap month the 2-tuple `{month, :leap}`.

  * `lunar_day` is any day number valid for `gregorian_year` and
    `lunar_month`.

  ### Returns

  * A gregorian date `t:Date.t/0`.

  ### Examples

      # Tết (1st day of the 1st lunar month) of 2023
      iex> Calendrical.Vietnamese.gregorian_date_for_lunar(2023, 1, 1)
      ~D[2023-01-22]

  """
  @spec gregorian_date_for_lunar(
          gregorian_year :: Calendar.year(),
          lunar_month :: Lunisolar.lunar_month(),
          lunar_day :: Calendar.day()
        ) :: Date.t()
  def gregorian_date_for_lunar(gregorian_year, lunar_month, lunar_day) do
    {year, month, day} =
      Lunisolar.gregorian_date_for_lunar(
        gregorian_year,
        lunar_month,
        lunar_day,
        epoch(),
        &location/1
      )

    Date.new!(year, month, day)
  end

  @doc """
  Returns the Gregorian date of Tết (Vietnamese Lunar New Year) for a
  given Gregorian year.

  Tết is the 1st day of the 1st lunar month. It usually coincides with the
  Chinese New Year, but diverges when a new moon or the winter solstice
  falls in the UTC+7/UTC+8 window — in 1985 (a month earlier), 2007, 2030
  and 2053 (a day earlier).

  ### Arguments

  * `gregorian_year` is any year in the Gregorian calendar.

  ### Returns

  * a `t:Date.t/0` for the Gregorian date of Tết.

  ### Examples

      iex> Calendrical.Vietnamese.tet_for_gregorian_year(2023)
      ~D[2023-01-22]

      # 1985: a full month before the Chinese New Year (20 February 1985)
      iex> Calendrical.Vietnamese.tet_for_gregorian_year(1985)
      ~D[1985-01-21]

      # 2007: a day before the Chinese New Year (18 February 2007)
      iex> Calendrical.Vietnamese.tet_for_gregorian_year(2007)
      ~D[2007-02-17]

  """
  @spec tet_for_gregorian_year(Calendar.year()) :: Date.t()
  def tet_for_gregorian_year(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, 1, 1)
  end

  @doc """
  Returns the Gregorian date of Tết Trung Thu (the Mid-Autumn Festival,
  the 15th day of the 8th lunar month) for a given Gregorian year.

  ### Arguments

  * `gregorian_year` is any year in the Gregorian calendar.

  ### Returns

  * The Gregorian date of the Mid-Autumn Festival for the given year.

  ### Examples

      iex> Calendrical.Vietnamese.mid_autumn_for_gregorian_year(2023)
      ~D[2023-09-29]

  """
  @mid_autumn_month 8
  @mid_autumn_day 15

  @spec mid_autumn_for_gregorian_year(Calendar.year()) :: Date.t()
  def mid_autumn_for_gregorian_year(gregorian_year) when is_integer(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, @mid_autumn_month, @mid_autumn_day)
  end

  # Compatibility with Calendrical.localize
  @doc false
  @impl true
  def month_of_year(year, month, _day) do
    lunar_month_of_year(year, month)
  end

  @doc false
  def date_to_iso_days({year, month, day}) do
    date_to_iso_days(year, month, day)
  end

  @doc false
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Lunisolar.date_to_iso_days(year, month, day, epoch(), &location/1)
  end

  @doc false
  def date_from_iso_days(iso_days) do
    Lunisolar.date_from_iso_days(iso_days, epoch(), &location/1)
  end

  @doc """
  Returns whether a year, ordinal month and day form a valid date in the
  `#{inspect(__MODULE__)}` calendar.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is an ordinal month number, 1..12 or 1..13 in a leap year.

  * `day` is a day of the month.

  ### Returns

  * `true` or `false`.

  ### Examples

      iex> Calendrical.Vietnamese.valid_date?(4662, 13, 1)
      true

      iex> Calendrical.Vietnamese.valid_date?(4661, 13, 1)
      false

  """
  @impl true
  def valid_date?(year, month, day) do
    Lunisolar.valid_date?(year, month, day, epoch(), &location/1)
  end

  @doc """
  Returns the number of days in an ordinal month of a year.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is an ordinal month number, 1..12 or 1..13 in a leap year.

  ### Returns

  * The number of days in the month, 29 or 30.

  ### Examples

      # The intercalary 6th month of Y4662 (= AD 2025)
      iex> Calendrical.Vietnamese.days_in_month(4662, 7)
      29

  """
  @impl true
  def days_in_month(year, month) do
    Lunisolar.days_in_month(year, month, epoch(), &location/1)
  end

  @doc """
  Returns the number of days in a year.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  ### Returns

  * The number of days from the year's new year to the next.

  ### Examples

      iex> Calendrical.Vietnamese.days_in_year(4662)
      384

      iex> Calendrical.Vietnamese.days_in_year(4661)
      354

  """
  @impl true
  def days_in_year(year) do
    Lunisolar.days_in_year(year, epoch(), &location/1)
  end

  @doc """
  Returns the number of days a month can have, without a year.

  A lunar month runs from one new moon to the next, so it has 29 or 30 days
  depending on the year.

  ### Arguments

  * `month` is an ordinal month number, 1..13.

  ### Returns

  * `{:ambiguous, 29..30}` for months 1..13.

  * `{:error, :undefined}` for any other value.

  ### Examples

      iex> Calendrical.Vietnamese.days_in_month(1)
      {:ambiguous, 29..30}

  """
  @impl true
  def days_in_month(month) when month in 1..13, do: {:ambiguous, 29..30}
  def days_in_month(_month), do: {:error, :undefined}

  @doc """
  Returns the number of days since the start of the epoch for an ordinal
  date, validating it in the same pass.

  This is `valid_date?/3` and `date_to_iso_days/3` answered from one
  computation of the lunar year; `Calendrical.iso_days/4` uses it.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is an ordinal month number, 1..12 or 1..13 in a leap year.

  * `day` is a day of the month.

  ### Returns

  * `{:ok, iso_days}` or

  * `{:error, :invalid_date}`.

  ### Examples

      # The lunar new year of Y4662 (= AD 2025) is 2025-01-29
      iex> Calendrical.Vietnamese.iso_days(4662, 1, 1)
      {:ok, 739645}

      iex> Calendrical.Vietnamese.iso_days(4661, 13, 1)
      {:error, :invalid_date}

  """
  @spec iso_days(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {:ok, integer()} | {:error, :invalid_date}
  def iso_days(year, month, day) do
    Lunisolar.iso_days(year, month, day, epoch(), &location/1)
  end

  @doc """
  Returns the ordinal month of a traditional month in a year.

  A leap month repeats the number of the month before it, so from the leap
  month on a traditional month's ordinal is one more than its number.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `lunar_month` is a traditional month number, 1..12, or `{month, :leap}`
    for the leap month that repeats traditional `month`.

  ### Returns

  * `{:ok, month}` where `month` is the ordinal month, 1..13, or

  * `{:error, :invalid_leap_month}` when the year has no such leap month, or

  * `{:error, :invalid_month}` for any other value.

  ### Examples

      # Y4662 (= AD 2025) has an intercalary 6th month
      iex> Calendrical.Vietnamese.ordinal_month_from_traditional(4662, {6, :leap})
      {:ok, 7}

      iex> Calendrical.Vietnamese.ordinal_month_from_traditional(4662, 7)
      {:ok, 8}

      iex> Calendrical.Vietnamese.ordinal_month_from_traditional(4661, {6, :leap})
      {:error, :invalid_leap_month}

  """
  @spec ordinal_month_from_traditional(Calendar.year(), Lunisolar.lunar_month()) ::
          {:ok, Calendar.month()} | {:error, :invalid_month | :invalid_leap_month}
  def ordinal_month_from_traditional(year, lunar_month) do
    Lunisolar.ordinal_month_from_traditional(year, lunar_month, epoch(), &location/1)
  end

  @doc """
  Adds an `increment` number of `date_part`s to a date.

  Adding years keeps the traditional month, so a festival on the 15th day
  of the 8th month moves to the 8th month of the new year, whatever its
  ordinal. A leap month that the new year does not have becomes the
  ordinary month of the same number. Months, quarters (three months),
  weeks and days count forward through the calendar's own months.

  ### Arguments

  * `year`, `month` and `day` are the parts of an ordinal date.

  * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks` or
    `:days`.

  * `increment` is the integer number of `date_part`s to add. It may be
    negative.

  * `options` is a keyword list of options.

  ### Options

  * `:coerce` — when `true`, a day beyond the end of the resulting month
    becomes that month's last day. The default is `false`.

  ### Returns

  * A `{year, month, day}` tuple of the ordinal date.

  ### Examples

      # 4660 (= AD 2023) has an intercalary 2nd month, so the Mid-Autumn
      # Festival (8th month, 15th day) falls in ordinal month 9
      iex> Calendrical.Vietnamese.plus(4660, 9, 15, :years, 1)
      {4661, 8, 15}
  """
  @impl true
  @spec plus(Calendar.year(), Calendar.month(), Calendar.day(), atom(), integer(), Keyword.t()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  def plus(year, month, day, date_part, increment, options \\ [])

  def plus(year, month, day, :years, years, options) do
    Lunisolar.plus_years(year, month, day, years, options, epoch(), &location/1)
  end

  def plus(year, month, day, date_part, increment, options) do
    super(year, month, day, date_part, increment, options)
  end

  @doc false
  def new_moon_on_or_after(iso_days) do
    Lunisolar.new_moon_on_or_after(iso_days, &location/1)
  end

  # 1 January 1968: North Vietnam's switch from UTC+8 to UTC+7 (decree of
  # 8 August 1967). No new moon or solstice falls near a day boundary between
  # the decree and the year boundary, so 1968-01-01 and 1967-08-08 yield
  # identical dates.
  @vietnam_1968 Calendrical.Gregorian.date_to_iso_days(1968, 1, 1)

  # A reference longitude and UT offset are required to place new moons and
  # solar terms on a civil day. From 1968 the Vietnamese calendar is computed
  # for the 105° East (Hanoi) meridian, UTC+7. Before 1968 it followed the
  # Chinese calendar, so it delegates to `Calendrical.Chinese.location/1` for
  # that era — Beijing's meridian, local apparent time before 1929 and China
  # Standard Time (UTC+8) from 1929 — keeping the two calendars identical for
  # every pre-1968 date.
  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    if iso_days < @vietnam_1968 do
      Calendrical.Chinese.location(iso_days)
    else
      {angle(21, 2, 0), angle(105, 51, 0), mt(0), Astro.Time.hours_to_days(7)}
    end
  end
end
