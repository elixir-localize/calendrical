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

  The epoch, the first day of year 1, is the lunar new year of the year
  in which the [Taika era](https://en.wikipedia.org/wiki/Taika_(era)),
  the first imperial era, was proclaimed: 5 February 645 in the
  proleptic Gregorian calendar.

  The epoch can be changed by setting the `:lunar_japanese_epoch`
  configuration key in `config.exs`; its default is:

      config :calendrical,
        lunar_japanese_epoch: ~D[0645-02-05]

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
      iex> {date.month, Calendrical.LunarJapanese.lunar_month_of_year(date.year, date.month)}
      {8, {7, :leap}}

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  """

  use Calendrical.Calendar.Lunisolar,
    epoch: Application.compile_env(:calendrical, :lunar_japanese_epoch, ~D[0645-02-05]),
    cldr_calendar_type: :chinese,
    location: &__MODULE__.location/1,
    era_calendar_type: :japanese

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1,
      deg: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  # The Japanese era (元号) year offset: LunarJapanese year 1 began
  # in 645 CE, so the Gregorian year containing the start of lunar
  # year Y is Y + 644. The Japanese era table counts years in
  # Gregorian labels, so the offset normalizes between the two.
  @gregorian_year_offset 644

  # Japan counted era years in lunisolar years until it adopted the
  # Gregorian calendar on 1873-01-01 (`Calendrical.Reform.Japan`), and
  # in Gregorian years since.
  @gregorian_reform_iso_days Date.to_gregorian_days(~D[1873-01-01])
  @tokyo_local_offset Astro.Time.hours_to_days(9 + 143 / 450)
  @japan_standard_offset Astro.Time.hours_to_days(9)
  @japan_1888 Calendrical.Gregorian.date_to_iso_days(1888, 1, 1)

  @doc false
  def new_moon_on_or_after(iso_days) do
    Lunisolar.new_moon_on_or_after(iso_days, &location/1)
  end

  @doc """
  Returns the year of era and era number for a lunisolar Japanese
  date.

  Japanese lunisolar dates are labelled by era (元号) year: the proclamation date of an era begins year one of that era within the current lunar year, exactly as recorded in the historical chronicles. An era proclaimed after Japan adopted the Gregorian calendar on 1873-01-01 numbers its years in Gregorian years instead, so the lunar year that begins in its first Gregorian year is still its year one. Era boundaries come from the Japanese era table, not the Chinese one used for month names.

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
    {day_of_era, era} = Calendrical.Era.day_of_era(:japanese, iso_days)
    era_start = iso_days - day_of_era + 1

    if era_start < @gregorian_reform_iso_days do
      # Year one is the lunar year the proclamation day falls in, and
      # each lunar new year after it begins the next year of the era.
      {era_start_year, _month, _day} = date_from_iso_days(era_start)
      {year - era_start_year + 1, era}
    else
      Calendrical.Era.year_of_era(:japanese, iso_days, year + @gregorian_year_offset)
    end
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

  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    if iso_days < @japan_1888 do
      {deg(35.7), angle(139, 46, 0), mt(24), @tokyo_local_offset}
    else
      {deg(35), deg(135), mt(0), @japan_standard_offset}
    end
  end
end
