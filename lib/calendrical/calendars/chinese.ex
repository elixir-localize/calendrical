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
      iex> {date.month, Calendrical.Chinese.lunar_month_of_year(date.year, date.month)}
      {3, {2, :leap}}

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  ## The meridian

  Month starts are reckoned at Beijing in local mean time (UTC+7:46)
  before 1929 and at UTC+8 from 1929, as Dershowitz and Reingold give
  them. Against the Hong Kong Observatory's conversion tables for 1901 to
  1928 this rule misses one month start, 24 April 1906, whose new moon
  fell 14 minutes before midnight in mean time and after it at UTC+8;
  reckoning those years at UTC+8, as ICU does, would miss three.

  """

  use Calendrical.Calendar.Lunisolar,
    epoch: Application.compile_env(:calendrical, :chinese_epoch, ~D[-2636-02-15]),
    cldr_calendar_type: :chinese,
    location: &__MODULE__.location/1

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  @dragon_month 5
  @dragon_day 5
  @beijing_local_offset Astro.Time.hours_to_days(1397 / 180)
  @china_standard_offset Astro.Time.hours_to_days(8)
  @china_1929 Calendrical.Gregorian.date_to_iso_days(1929, 1, 1)

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

  # Since the Chinese calendar is a lunisolar
  # calendar, a reference longitude is required
  # in order to calculate sunset and sunrise.
  #
  # Prior to 1929, the longitude of Beijing was
  # used. Since 1929, the longitude of the
  # standard China timezone (GMT+8) is used.

  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    if iso_days < @china_1929 do
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
