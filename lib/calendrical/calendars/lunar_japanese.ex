defmodule Calendrical.LunarJapanese do
  @moduledoc """
  Implementation of the Japanese lunisolar calendar.

  In a normal Japanese lunisolar calendar, one year
  is divided into 12 months, with one month corresponding
  to the time between two full moons.

  Since the cycle of the moon is not
  an even number of days, a month in the lunar calendar
  can vary between 29 and 30 days and a normal year can
  have 353, 354, or 355 days.

  We define the epoch to the first new moon in the first
  year of the [Taika era](https://en.wikipedia.org/wiki/Taika_(era))
  which is recorded as the first imperial era.

  The epoch can be changed by setting the `:lunar_japanese_epoch`
  configuration key in `config.exs`:

      # Alternative epoch starting from the reign of Emperor
      # Huangdi
      config :calendrical,
        lunar_japanese_epoch: ~D[0645-07-20]

  ## Two month numbering conventions

  The Japanese lunisolar calendar (like the Chinese and Korean ones) has
  **two distinct month numbering conventions**. Choosing the wrong one
  silently produces dates that are off by one full lunar month after the
  intercalary month in leap years. The conventions are:

  * **Ordinal** — months counted monotonically 1..12 in ordinary years
    and 1..13 in leap years. The intercalary appears at whatever position
    the astronomical no-zhongqi rule places it; it is not separately
    labelled. This is the convention `Date.new/4` accepts, the `Date.t`
    struct stores, and `Date.convert/2` returns. It is what the standard
    `Calendar` behaviour callbacks expect.

  * **Traditional** — months always numbered 1..12, with the intercalary
    expressed as `{month, :leap}` (read 閏N月 — "intercalary Nth month")
    where `month` is the *preceding* traditional month number. This is
    the convention used by primary chronicles and cultural references.
    `#{inspect(__MODULE__)}.new/3` and the return value of
    `lunar_month_of_year/1` use this convention.

  As an example, in lunar year 1210 (= AD 1854, 嘉永7 / Kaei 7) the
  intercalary is the 8th ordinal month, equivalent to the traditional
  notation `{7, :leap}` (閏7月):

      # Build a date using traditional notation:
      iex> {:ok, date} = Calendrical.LunarJapanese.new(1210, {7, :leap}, 1)
      iex> Date.convert(date, Calendar.ISO)
      {:ok, ~D[1854-08-24]}

      # The same day via Date.new/4 uses ordinal numbering (m8 = the leap):
      iex> {:ok, date} = Date.new(1210, 8, 1, Calendrical.LunarJapanese)
      iex> Date.convert(date, Calendar.ISO)
      {:ok, ~D[1854-08-24]}

      # The Date.t struct stores months in ordinal form:
      iex> {:ok, date} = Calendrical.LunarJapanese.new(1210, {7, :leap}, 1)
      iex> {date.month, Calendrical.LunarJapanese.lunar_month_of_year(date)}
      {8, {7, :leap}}

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  """

  use Calendrical.Behaviour,
    epoch: Application.compile_env(:calendrical, :lunar_japanese_epoch, ~D[0645-07-20]),
    cldr_calendar_type: :chinese,
    months_in_normal_year: 12,
    months_in_leap_year: 13

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1,
      deg: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  @doc """
  Returns a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar
  formed by a calendar year, a **traditional** lunar month number, and
  a day number.

  The lunar month is that used in traditional lunisolar calendar
  notation. It is either a number between 1 and 12 (the number of months
  in an ordinary year) or a leap month specified by the 2-tuple
  `{month, :leap}` where `month` is the preceding traditional month
  number that the intercalary repeats (read 閏N月 — "intercalary Nth
  month"). See the moduledoc for the full ordinal-vs-traditional
  discussion.

  This function is the right entry point for creating dates from
  primary chronicles, cultural references, or any other source that
  reports a lunisolar date in its native form. To build a date from an
  ordinal (1..13) month number — the form stored on the `Date.t`
  struct itself — use `Date.new/4` instead.

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

      # Lunar new year
      iex> Calendrical.LunarJapanese.new(1379, 1, 1)
      {:ok, ~D[1379-01-01 Calendrical.LunarJapanese]}

      # First day of the intercalary 2nd month (閏2月) of Y1379 —
      # traditional notation: {2, :leap}; the resulting date.month is
      # the ordinal 3
      iex> Calendrical.LunarJapanese.new(1379, {2, :leap}, 1)
      {:ok, ~D[1379-03-01 Calendrical.LunarJapanese]}

      # Kaei 7, traditional 11th month, day 27 (安政改元日) — Y1210 has
      # an intercalary {7, :leap}, so traditional M11 is ordinal m12
      iex> {:ok, date} = Calendrical.LunarJapanese.new(1210, 11, 27)
      iex> Date.convert(date, Calendar.ISO)
      {:ok, ~D[1855-01-15]}

  """
  @spec new(year :: Calendar.year(), month :: Lunisolar.lunar_month(), day :: Calendar.day()) ::
          {:ok, Date.t()} | {:error, atom()}

  def new(year, month, day) do
    case Lunisolar.new(year, month, day, epoch(), &location/1) do
      {:error, reason} ->
        {:error, reason}

      iso_days ->
        {year, month, day} = date_from_iso_days(iso_days)
        Date.new(year, month, day, __MODULE__)
    end
  end

  @doc """
  Raising variant of `new/3`.

  ### Arguments

  * `year` is any year in the `Calendrical.LunarJapanese` calendar.

  * `month` is either a traditional month number between 1 and 12, or
    for an intercalary month the 2-tuple `{month, :leap}` where `month`
    is the preceding traditional month number.

  * `day` is a day-of-month valid for the year and month.

  ### Returns

  * A `t:Date.t/0` in `Calendrical.LunarJapanese`.

  * Raises `ArgumentError` if the date is not valid in this
    calendar.

  ### Examples

      iex> Calendrical.LunarJapanese.new!(1379, 1, 1)
      ~D[1379-01-01 Calendrical.LunarJapanese]

      iex> Calendrical.LunarJapanese.new!(1210, {7, :leap}, 1)
      ~D[1210-08-01 Calendrical.LunarJapanese]

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
  Returns a boolean indicating if the given year is a leap
  year.

  Leap years have 13 months. To determine if a year
  is a leap year, calculate the number of new moons
  between the 11th month in one year (i.e., the month
  containing the Winter Solstice) and the 11th month
  in the following year.

  If there are 13 new moons from the start of the 11th
  month in the first year to the start of the 11th
  month in the second year, a leap month must be inserted.

  In leap years, at least one month does not contain a
  Principal Term. The first such month is the leap month.

  The additional complexity is that a leap year is
  calculated for the solar year, but the calendar
  is managed in lunar years and months. Therefore when
  a leap year is detected, the leap month could be in
  the current lunar year or the next lunar year.

  ### Arguments

  * `date_or_year` is either an integer year number
    or a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * A boolean indicating if the given year is a leap
    year.

  ### Examples

      iex> Calendrical.LunarJapanese.leap_year?(1379)
      true

      iex> Calendrical.LunarJapanese.leap_year?(1378)
      false

  """
  @spec leap_year?(date_or_year :: Calendar.year() | Date.t()) :: boolean()
  @impl Calendar

  def leap_year?(%{year: year, calendar: __MODULE__}) do
    leap_year?(year)
  end

  # A date in another calendar is converted first — the previous
  # clause head bound a variable named `__MODULE` (a typo for
  # `__MODULE__`), which matched any calendar and treated foreign
  # year numbers as years of this calendar.
  def leap_year?(%{calendar: _other} = date) do
    {:ok, converted} = Date.convert(date, __MODULE__)
    leap_year?(converted.year)
  end

  def leap_year?(year) when is_integer(year) do
    Lunisolar.leap_year?(year, epoch(), &location/1)
  end

  @doc """
  Returns a boolean indicating if the given year and month
  is a leap month.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * A boolean indicating if the given year and month is a leap
    month.

  ### Examples

      iex> Calendrical.LunarJapanese.leap_month?(1379, 1)
      false

      iex> Calendrical.LunarJapanese.leap_month?(1379, 3)
      true

  """
  @spec leap_month?(year :: Calendar.year(), month :: Calendar.month()) :: boolean()
  def leap_month?(year, month) do
    Lunisolar.leap_month?(year, month, epoch(), &location/1)
  end

  @doc """
  Returns a boolean indicating if the given year and month
  is a leap month.

  ### Arguments

  * `date` is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}` calendar.

  ### Returns

  * A boolean indicating if the given year and month is a leap
    month.

  ### Examples

      iex> Calendrical.LunarJapanese.leap_month?(~D[1379-01-01 Calendrical.LunarJapanese])
      false

      iex> Calendrical.LunarJapanese.leap_month?(~D[1379-03-29 Calendrical.LunarJapanese])
      true

  """
  @spec leap_month?(date :: Date.t()) :: boolean()
  def leap_month?(%Date{calendar: __MODULE__} = date) do
    leap_month?(date.year, date.month)
  end

  @doc """
  Returns the **ordinal** position (1..13) of the leap month for a year,
  or `nil` if the year is not a leap year.

  This is the position of the intercalary in the monotonic 1..13 ordinal
  sequence used by `Date.t` structs and the standard `Calendar` callbacks.
  See `traditional_leap_month/1` for the traditional notation (the
  preceding-month number that the intercalary repeats).

  ### Arguments

  * `date_or_year` is either an integer year number
    or a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the ordinal position of the leap month (1..13), or

  * `nil` if there is no leap month in the given year.

  ### Examples

      # Y1379 is a leap year; the intercalary is at ordinal m3
      # (= traditional {2, :leap})
      iex> Calendrical.LunarJapanese.leap_month(1379)
      3

      iex> Calendrical.LunarJapanese.leap_month(~D[1379-13-29 Calendrical.LunarJapanese])
      3

      iex> Calendrical.LunarJapanese.leap_month(1380)
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

  The intercalary month in lunisolar tradition repeats the number of the
  preceding non-leap month. For example, the intercalary that appears at
  ordinal position 3 of Y1379 is written 閏2月 in traditional notation
  and used as `{2, :leap}` in this module's API.

  ### Arguments

  * `date_or_year` is either an integer year number
    or a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the traditional number of the leap month (1..12), or

  * `nil` if there is no leap month in the given year.

  ### Examples

      iex> Calendrical.LunarJapanese.traditional_leap_month(1379)
      2

      iex> Calendrical.LunarJapanese.traditional_leap_month(1210)
      7

      iex> Calendrical.LunarJapanese.traditional_leap_month(1380)
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
  Returns the Gregorian date for the given gregorian year
  and lunar month and day.

  ### Arguments

  * `gregorian_year` is any year in the Gregorian calendar.

  * `lunar_month` is either a cardinal month number between 1 and 12 or
    for a leap month the 2-tuple in the format `{month, :leap}`.

  * `lunar_day` is any day number valid for `gregorian_year` and
    `lunar_month`.

  ### Returns

  * A gregorian date `t:Date.t/0`.

  ### Examples

      # Lunar new year of 2021
      iex> Calendrical.LunarJapanese.gregorian_date_for_lunar(2021, 1, 1)
      ~D[2021-02-12]

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
  Returns the gregorian date of the
  Lunar New Year for a given gregorian year.

  ### Arguments

  * `gregorian_year` is any year in the Gregorian calendar.

  ### Returns

  * a `t:Calendar.date/0` representing the Gregorian date of
    the lunar year of the given Gregorian year.

  ### Examples

      iex> Calendrical.LunarJapanese.new_year_for_gregorian_year(2021)
      ~D[2021-02-12]

      iex> Calendrical.LunarJapanese.new_year_for_gregorian_year(2022)
      ~D[2022-02-01]

      iex> Calendrical.LunarJapanese.new_year_for_gregorian_year(2023)
      ~D[2023-01-22]

  """
  @spec new_year_for_gregorian_year(Calendar.year()) :: Date.t()
  def new_year_for_gregorian_year(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, 1, 1)
  end

  @doc """
  Returns the year in the lunisolar sexagesimal 60-year
  cycle.

  Traditionally years are numbered only within the cycle
  however in this implementation the year is an offset from
  the epoch date. It can be converted to the current year in
  the current cycle with this function.

  The cycle year is commonly shown on lunisolar calendars and
  it forms part of the traditional Chinese zodiac.

  ### Arguments

  * `date` which is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar, *or*

  *`year` and `month` representing the calendar year and month.

  ### Returns

  * the integer year within the sexagesimal cycle of 60 years.

  ### Examples

      iex> Calendrical.LunarJapanese.cyclic_year(~D[1380-04-01 Calendrical.LunarJapanese])
      60

      iex> Calendrical.LunarJapanese.cyclic_year(~D[1381-01-01 Calendrical.LunarJapanese])
      1

      iex> Calendrical.LunarJapanese.cyclic_year(~D[1200-01-02 Calendrical.LunarJapanese])
      60

      iex> Calendrical.LunarJapanese.cyclic_year(~D[1260-01-01 Calendrical.LunarJapanese])
      60

  """
  @spec cyclic_year(date :: Date.t()) :: Lunisolar.cycle()
  def cyclic_year(%Date{year: year, month: month, calendar: __MODULE__}) do
    cyclic_year(year, month)
  end

  @doc """
  Returns the year in the lunisolar sexagesimal 60-year cycle for
  a given calendar year and month.

  This is the year-and-month variant of `cyclic_year/1`.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the integer year within the sexagesimal cycle of 60 years.

  ### Examples

      iex> Calendrical.LunarJapanese.cyclic_year(1380, 4)
      60

      iex> Calendrical.LunarJapanese.cyclic_year(1381, 1)
      1

  """
  @spec cyclic_year(year :: Calendar.year(), month :: Calendar.month()) :: Lunisolar.cycle()
  def cyclic_year(year, month) do
    Lunisolar.cyclic_year(year, month, 1)
  end

  @doc """
  Returns the lunar month of the year for a given date or
  year and month.

  The lunar month number in the traditional lunisolar calendar is
  between 1 and 12 with a leap month added when there are 13 new moons
  between Winter solstices. This intercalary leap month is not
  representable in its traditional form in the `t:Calendar.date/0` struct.

  This function takes a date, or year and month, and returns either the
  month number between 1 and 12 or a 2-tuple representing the leap month.
  This 2-tuple looks like `{month_number, :leap}`.

  The value returned from this function can be passed to `#{inspect(__MODULE__)}.new/3` to
  define a date using traditional lunar months.

  ### Arguments

  * `date` which is any `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar, *or*

  *`year` and `month` representing the calendar year and month.

  ### Returns

  * the lunar month as either an integer between 1 and 12 or a
  tuple of the form `{lunar_month, :leap}`.

  ### Examples

      iex> Calendrical.LunarJapanese.lunar_month_of_year(~D[1379-02-01 Calendrical.LunarJapanese])
      2

      iex> Calendrical.LunarJapanese.lunar_month_of_year(~D[1379-03-01 Calendrical.LunarJapanese])
      {2, :leap}

      iex> Calendrical.LunarJapanese.lunar_month_of_year(~D[1379-04-01 Calendrical.LunarJapanese])
      3

  """
  @spec lunar_month_of_year(date :: Date.t()) :: Lunisolar.lunar_month()
  def lunar_month_of_year(%Date{year: year, month: month, calendar: __MODULE__}) do
    lunar_month_of_year(year, month)
  end

  @doc """
  Returns the lunar month of the year for a given calendar year and
  ordinal month.

  This is the year-and-month variant of `lunar_month_of_year/1`. See
  that function and the moduledoc for the ordinal-vs-traditional
  month numbering discussion.

  ### Arguments

  * `year` is any year in the `#{inspect(__MODULE__)}` calendar.

  * `month` is any ordinal month number in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the lunar month as either an integer between 1 and 12 or a
    tuple of the form `{lunar_month, :leap}`.

  ### Examples

      iex> Calendrical.LunarJapanese.lunar_month_of_year(1379, 3)
      {2, :leap}

      iex> Calendrical.LunarJapanese.lunar_month_of_year(1379, 4)
      3

  """
  @spec lunar_month_of_year(year :: Calendar.year(), month :: Calendar.month()) ::
          Lunisolar.lunar_month()
  def lunar_month_of_year(year, month) do
    Lunisolar.lunar_month_of_year(year, month, 1, epoch(), &location/1)
  end

  # Compatibility with Calendrical.localize
  @doc false
  @impl true
  def month_of_year(year, month, _day) do
    lunar_month_of_year(year, month)
  end

  @doc false
  def cycle_and_year(iso_days) do
    Lunisolar.cycle_and_year(iso_days)
  end

  @doc false
  def elapsed_years({cycle, cyclical_year}) do
    Lunisolar.elapsed_years(cycle, cyclical_year)
  end

  @doc false
  def elapsed_years(cycle, cyclical_year) do
    Lunisolar.elapsed_years(cycle, cyclical_year)
  end

  @doc false
  def date_to_iso_days({year, month, day}) do
    date_to_iso_days(year, month, day)
  end

  @doc false
  def date_to_iso_days(year, month, day) do
    Lunisolar.date_to_iso_days(year, month, day, epoch(), &location/1)
  end

  @doc false
  def date_from_iso_days(iso_days) do
    Lunisolar.date_from_iso_days(iso_days, epoch(), &location/1)
  end

  @doc false
  def new_moon_on_or_after(iso_days) do
    Lunisolar.new_moon_on_or_after(iso_days, &location/1)
  end

  # The Japanese era (元号) year offset: LunarJapanese year 1 began
  # in 645 CE, so the Gregorian year containing the start of lunar
  # year Y is Y + 644. The Japanese era table counts years in
  # Gregorian labels, so the offset normalizes between the two.
  @gregorian_year_offset 644

  @doc """
  Returns the year of era and era number for a lunisolar Japanese
  date.

  Japanese lunisolar dates are labelled by era (元号) year: the
  proclamation date of an era begins year one of that era within
  the current lunar year, exactly as recorded in the historical
  chronicles. Era boundaries come from the Japanese era table, not
  the Chinese one used for month names.

  ### Arguments

  * `year` is any `#{inspect(__MODULE__)}` year as an integer.

  * `month` is an ordinal month in the range `1..13`.

  * `day` is a day-of-month.

  ### Returns

  * A two-tuple `{year_of_era, era}` where `era` is the CLDR
    Japanese era index.

  ### Examples

      iex> date = Date.convert!(~D[2026-07-05], Calendrical.LunarJapanese)
      iex> Calendrical.LunarJapanese.year_of_era(date.year, date.month, date.day)
      {8, 236}

      # 安政元年 began on its proclamation day, part-way through
      # the lunar year that started as 嘉永7年.
      iex> date = Date.convert!(~D[1855-01-15], Calendrical.LunarJapanese)
      iex> Calendrical.LunarJapanese.year_of_era(date.year, date.month, date.day)
      {1, 227}

  """
  @spec year_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.era()}
  @impl Calendar
  def year_of_era(year, month, day) do
    iso_days = date_to_iso_days(year, month, day)
    Calendrical.Era.year_of_era(:japanese, iso_days, year + @gregorian_year_offset)
  end

  @doc """
  Returns the year of era and era number for the first day of a
  lunisolar Japanese year.

  ### Arguments

  * `year` is any `#{inspect(__MODULE__)}` year as an integer.

  ### Returns

  * A two-tuple `{year_of_era, era}` where `era` is the CLDR
    Japanese era index.

  ### Examples

      iex> Calendrical.LunarJapanese.year_of_era(1382)
      {8, 236}

  """
  @spec year_of_era(Calendar.year()) :: {Calendar.year(), Calendar.era()}
  def year_of_era(year) do
    year_of_era(year, 1, 1)
  end

  @doc """
  Returns the day of era and era number for a lunisolar Japanese
  date.

  Era boundaries come from the Japanese era table (see
  `year_of_era/3`), so the day count begins on the era's
  proclamation day.

  ### Arguments

  * `year` is any `#{inspect(__MODULE__)}` year as an integer.

  * `month` is an ordinal month in the range `1..13`.

  * `day` is a day-of-month.

  ### Returns

  * A two-tuple `{day_of_era, era}` where `era` is the CLDR
    Japanese era index.

  ### Examples

      iex> date = Date.convert!(~D[2019-05-01], Calendrical.LunarJapanese)
      iex> Calendrical.LunarJapanese.day_of_era(date.year, date.month, date.day)
      {1, 236}

  """
  @spec day_of_era(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.day(), Calendar.era()}
  @impl Calendar
  def day_of_era(year, month, day) do
    iso_days = date_to_iso_days(year, month, day)
    Calendrical.Era.day_of_era(:japanese, iso_days)
  end

  # The calendar year is the era year: Japanese lunisolar dates are
  # displayed as 元号 year plus lunar month and day, which is what
  # CLDR's `y` field renders via this callback.
  @doc false
  @impl true
  def calendar_year(year, month, day) do
    {year, _era} = year_of_era(year, month, day)
    year
  end

  # Era names come from the Japanese CLDR calendar even though month
  # and day names come from the Chinese one (`cldr_calendar_type/0`).
  # `Calendrical.localize/3` consults this optional callback when
  # localizing the `:era` part.
  @doc false
  @impl Calendrical
  def era_calendar_type do
    :japanese
  end

  @doc false
  def new_moon_before(iso_days) do
    Lunisolar.new_moon_before(iso_days, &location/1)
  end

  # Since the Japanese calendar is a lunisolar
  # calendar, a reference longitude is required
  # in order to calculate sunset and sunrise.
  #
  # Prior to 1888, the longitude of Tokyo was
  # used. Since 1889, the longitude of the
  # standard Japan timezone (GMT+8) is used.

  @tokyo_local_offset Astro.Time.hours_to_days(9 + 143 / 450)
  @japan_standard_offset Astro.Time.hours_to_days(9)

  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    {year, _month, _day} = Calendrical.Gregorian.date_from_iso_days(trunc(iso_days))

    if year < 1888 do
      {deg(35.7), angle(139, 46, 0), mt(24), @tokyo_local_offset}
    else
      {deg(35), deg(135), mt(0), @japan_standard_offset}
    end
  end
end
