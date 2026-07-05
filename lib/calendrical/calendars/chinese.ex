defmodule Calendrical.Chinese do
  @moduledoc """
  Implementation of the Chinese lunisolar calendar.

  In a ‘regular’ Chinese lunisolar calendar, one year
  is divided into 12 months, with one month corresponding
  to the time between two full moons.

  Since the cycle of the moon is not
  an even number of days, a month in the lunar calendar
  can vary between 29 and 30 days and a normal year can
  have 353, 354, or 355 days.

  The default epoch for the Chinese lunisolar calendar
  is `~D[-2636-02-15]` which traditional date of the first
  use of the sexagesimal cycle. It can be changed by setting
  the `:chinese_epoch` configuration key in `config.exs`:

      # Alternative epoch starting from the reign of Emperor
      # Huangdi
      config :calendrical,
        chinese_epoch: ~D[-2696-01-01]

  ## Two month numbering conventions

  The Chinese lunisolar calendar (like the Japanese and Korean ones) has
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
    the convention used by cultural references and primary sources.
    `#{inspect(__MODULE__)}.new/3` and the return value of
    `lunar_month_of_year/1` use this convention.

  As an example, lunar year 4660 (=AD 2023) has its intercalary at
  ordinal m3, equivalent to the traditional `{2, :leap}` (閏2月):

      iex> {:ok, date} = Calendrical.Chinese.new(4660, {2, :leap}, 1)
      iex> Date.convert(date, Calendar.ISO)
      {:ok, ~D[2023-03-22]}

      # Stored ordinally on the Date.t struct:
      iex> {:ok, date} = Calendrical.Chinese.new(4660, {2, :leap}, 1)
      iex> {date.month, Calendrical.Chinese.lunar_month_of_year(date)}
      {3, {2, :leap}}

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  """

  use Calendrical.Behaviour,
    epoch: Application.compile_env(:calendrical, :chinese_epoch, ~D[-2636-02-15]),
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
  cultural references, holidays defined in the lunisolar calendar, or
  any other source that reports a lunisolar date in its native form. To
  build a date from an ordinal (1..13) month number — the form stored on
  the `Date.t` struct itself — use `Date.new/4` instead.

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

      # Lunar new year of 4660 (= AD 2023)
      iex> Calendrical.Chinese.new(4660, 1, 1)
      {:ok, ~D[4660-01-01 Calendrical.Chinese]}

      # First day of the intercalary 2nd month (閏2月) of Y4660
      iex> Calendrical.Chinese.new(4660, {2, :leap}, 1)
      {:ok, ~D[4660-03-01 Calendrical.Chinese]}

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

  * `year` is any year in the `Calendrical.Chinese` calendar.

  * `month` is either a traditional month number between 1 and 12, or
    for an intercalary month the 2-tuple `{month, :leap}` where `month`
    is the preceding traditional month number.

  * `day` is a day-of-month valid for the year and month.

  ### Returns

  * A `t:Date.t/0` in `Calendrical.Chinese`.

  * Raises `ArgumentError` if the date is not valid in this
    calendar.

  ### Examples

      iex> Calendrical.Chinese.new!(4660, 1, 1)
      ~D[4660-01-01 Calendrical.Chinese]

      iex> Calendrical.Chinese.new!(4660, {2, :leap}, 1)
      ~D[4660-03-01 Calendrical.Chinese]

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

      iex> Calendrical.Chinese.leap_year?(4660)
      true

      iex> Calendrical.Chinese.leap_year?(4661)
      false

  """
  @spec leap_year?(date_or_year :: Calendar.year() | Date.t()) :: boolean()
  @impl Calendar

  def leap_year?(%{year: year, calendar: __MODULE}) do
    leap_year?(year)
  end

  def leap_year?(year) do
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

      iex> Calendrical.Chinese.leap_month?(4660, 1)
      false

      iex> Calendrical.Chinese.leap_month?(4660, 3)
      true

  """
  @spec leap_month?(year :: Calendar.year(), month :: Calendar.month()) :: boolean()
  def leap_month?(year, month) do
    Lunisolar.leap_month?(year, month, epoch(), &location/1)
  end

  @doc false
  # For testing only
  def leap_month?(cycle, cyclic_year, month) do
    cycle
    |> Lunisolar.elapsed_years(cyclic_year)
    |> leap_month?(month)
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

      iex> Calendrical.Chinese.leap_month?(~D[4660-01-01 Calendrical.Chinese])
      false

      iex> Calendrical.Chinese.leap_month?(~D[4660-03-29 Calendrical.Chinese])
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

      # Y4660 is a leap year; the intercalary is at ordinal m3
      # (= traditional {2, :leap})
      iex> Calendrical.Chinese.leap_month(4660)
      3

      iex> Calendrical.Chinese.leap_month(~D[4660-13-29 Calendrical.Chinese])
      3

      iex> Calendrical.Chinese.leap_month(4661)
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
  ordinal position 3 of Y4660 is written 閏2月 in traditional notation
  and used as `{2, :leap}` in this module's API.

  ### Arguments

  * `date_or_year` is either an integer year number
    or a `t:Calendar.date/0` in the `#{inspect(__MODULE__)}`
    calendar.

  ### Returns

  * the traditional number of the leap month (1..12), or

  * `nil` if there is no leap month in the given year.

  ### Examples

      iex> Calendrical.Chinese.traditional_leap_month(4660)
      2

      iex> Calendrical.Chinese.traditional_leap_month(4661)
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

      iex> Calendrical.Chinese.lunar_month_of_year(~D[4660-02-01 Calendrical.Chinese])
      2

      iex> Calendrical.Chinese.lunar_month_of_year(~D[4660-03-01 Calendrical.Chinese])
      {2, :leap}

      iex> Calendrical.Chinese.lunar_month_of_year(~D[4660-04-01 Calendrical.Chinese])
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

      iex> Calendrical.Chinese.lunar_month_of_year(4660, 3)
      {2, :leap}

      iex> Calendrical.Chinese.lunar_month_of_year(4660, 4)
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

      # Lunar new year of 2026 (start of lunar year 4663)
      iex> Calendrical.Chinese.gregorian_date_for_lunar(2026, 1, 1)
      ~D[2026-02-17]

      # First day of the intercalary 6th month (閏6月) of lunar
      # year 4662
      iex> Calendrical.Chinese.gregorian_date_for_lunar(2025, {6, :leap}, 1)
      ~D[2025-07-25]

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

      iex> Calendrical.Chinese.new_year_for_gregorian_year(2021)
      ~D[2021-02-12]

      iex> Calendrical.Chinese.new_year_for_gregorian_year(2022)
      ~D[2022-02-01]

      iex> Calendrical.Chinese.new_year_for_gregorian_year(2023)
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

      iex> Calendrical.Chinese.cyclic_year(~D[4662-04-01 Calendrical.Chinese])
      42

      iex> Calendrical.Chinese.cyclic_year(~D[4357-01-01 Calendrical.Chinese])
      37

      iex> Calendrical.Chinese.cyclic_year(~D[4321-01-01 Calendrical.Chinese])
      1

      iex> Calendrical.Chinese.cyclic_year(~D[4320-01-01 Calendrical.Chinese])
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

      iex> Calendrical.Chinese.cyclic_year(4662, 4)
      42

      iex> Calendrical.Chinese.cyclic_year(4321, 1)
      1

  """
  @spec cyclic_year(year :: Calendar.year(), month :: Calendar.month()) :: Lunisolar.cycle()
  def cyclic_year(year, month) do
    Lunisolar.cyclic_year(year, month, 1)
  end

  @doc """
  Returns the gregorian date of the
  dragon festival (5th day of 5th lunar month)
  for a given gregorian year.

  ### Arguments

  * `year` is any year in the Gregorian calendar.

  ### Returns

  * The gregorian date of the dragon festival for
    the given year.

  ### Examples

      iex> Calendrical.Chinese.dragon_festival_for_gregorian_year(2021)
      ~D[2021-06-14]

      iex> Calendrical.Chinese.dragon_festival_for_gregorian_year(2022)
      ~D[2022-06-03]

      iex> Calendrical.Chinese.dragon_festival_for_gregorian_year(2023)
      ~D[2023-06-22]

  """
  @dragon_month 5
  @dragon_day 5

  @spec dragon_festival_for_gregorian_year(Calendar.year()) :: Date.t()
  def dragon_festival_for_gregorian_year(gregorian_year) when is_integer(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, @dragon_month, @dragon_day)
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

  # Since the Chinese calendar is a lunisolar
  # calendar, a reference longitude is required
  # in order to calculate sunset and sunrise.
  #
  # Prior to 1929, the longitude of Beijing was
  # used. Since 1929, the longitude of the
  # standard China timezone (GMT+8) is used.

  @beijing_local_offset Astro.Time.hours_to_days(1397 / 180)
  @china_standard_offset Astro.Time.hours_to_days(8)

  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    {year, _month, _day} = Calendrical.Gregorian.date_from_iso_days(trunc(iso_days))

    if year < 1929 do
      {angle(39, 55, 0), angle(116, 25, 0), mt(43.5), @beijing_local_offset}
    else
      {angle(39, 55, 0), angle(116, 25, 0), mt(43.5), @china_standard_offset}
    end
  end

  # The following are for testing purposes only

  @doc false
  def chinese_date_from_iso_days(iso_days) do
    Lunisolar.cyclical_date_from_iso_days(iso_days, epoch(), &location/1)
  end

  @doc false
  def alt_chinese_date_from_iso_days(iso_days) do
    Lunisolar.alt_cyclical_date_from_iso_days(iso_days, epoch(), &location/1)
  end

  @doc false
  def chinese_date_to_iso_days({cycle, cyclic_year, lunar_month, lunar_day}) do
    chinese_date_to_iso_days(cycle, cyclic_year, lunar_month, lunar_day)
  end

  @doc false
  def chinese_date_to_iso_days(cycle, cyclic_year, lunar_month, lunar_day) do
    Lunisolar.cyclical_date_to_iso_days(
      cycle,
      cyclic_year,
      lunar_month,
      lunar_day,
      epoch(),
      &location/1
    )
  end
end
