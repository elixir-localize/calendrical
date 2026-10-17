defmodule Calendrical.Korean do
  @moduledoc """
  Implementation of the Korean lunisolar calendar.

  In a ‘regular’ Korean lunisolar calendar, one year
  is divided into 12 months, with one month corresponding
  to the time between two full moons.

  Since the cycle of the moon is not
  an even number of days, a month in the lunar calendar
  can vary between 29 and 30 days and a normal year can
  have 353, 354, or 355 days.

  The default epoch for the Korean lunisolar calendar
  is `~D[-2332-02-15]` which is the traditional year of
  the founding of the first Korean nation. The epoch can
  be changed by setting the `:korean_epoch` configuration
  key in `config.exs`:

      config :calendrical,
        korean_epoch: ~D[-2332-02-15]

  ## Two month numbering conventions

  The Korean lunisolar (Dangi) calendar (like the Japanese and Chinese
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
    expressed as `{month, :leap}` (read 윤N월 in Korean — "intercalary Nth
    month") where `month` is the *preceding* traditional month number.
    This is the convention used by cultural references and primary
    sources. `#{inspect(__MODULE__)}.new/3` and the return value of
    `lunar_month_of_year/1` use this convention.

  Converting between the two: if a year is a leap year, traditional
  numbers below the leap-month position equal the ordinal numbers, and
  traditional numbers at or above the leap-month position equal
  ordinal-minus-one. `leap_month/1` returns the **ordinal** position of
  the intercalary; `traditional_leap_month/1` returns the **traditional**
  number that the intercalary repeats.

  """
  use Calendrical.Calendar.Lunisolar,
    epoch: Application.compile_env(:calendrical, :korean_epoch, ~D[-2332-02-15]),
    cldr_calendar_type: :dangi,
    location: &__MODULE__.location/1

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  @doc """
  Returns the Gregorian date of Korean thanksgiving
  (15th day of 8th lunar month) for a given Gregorian year.

  ### Arguments

  * `year` is any year in the Gregorian calendar.

  ### Returns

  * The Gregorian date of the Korean thanksgiving date for
    the given year.

  ### Examples

      iex> Calendrical.Korean.thanksgiving_for_gregorian_year(2021)
      ~D[2021-09-21]

      iex> Calendrical.Korean.thanksgiving_for_gregorian_year(2022)
      ~D[2022-09-10]

      iex> Calendrical.Korean.thanksgiving_for_gregorian_year(2023)
      ~D[2023-09-29]

  """
  @thanksgiving_month 8
  @thanksgiving_day 15

  @spec thanksgiving_for_gregorian_year(Calendar.year()) :: Date.t()
  def thanksgiving_for_gregorian_year(gregorian_year) when is_integer(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, @thanksgiving_month, @thanksgiving_day)
  end

  @doc false
  def new_moon_on_or_after(iso_days) do
    Lunisolar.new_moon_on_or_after(iso_days, &location/1)
  end

  # Since the Korean (dangi) calendar is a lunisolar
  # calendar, a reference longitude is required
  # in order to calculate sunset and sunrise.

  @doc false
  @spec location(Time.time()) :: {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()}
  def location(iso_days) do
    offset = korean_offset(iso_days)
    {angle(37, 34, 0), angle(126, 58, 0), mt(0), Astro.Time.hours_to_days(offset)}
  end

  @korea_1908 Calendrical.Gregorian.date_to_iso_days(1908, 4, 1)
  @korea_1912 Calendrical.Gregorian.date_to_iso_days(1912, 1, 1)
  @korea_1954 Calendrical.Gregorian.date_to_iso_days(1954, 3, 21)
  @korea_1961 Calendrical.Gregorian.date_to_iso_days(1961, 8, 10)

  @doc false
  def korean_offset(iso_days) do
    cond do
      iso_days < @korea_1908 -> 3809 / 450
      iso_days < @korea_1912 -> 8.5
      iso_days < @korea_1954 -> 9
      iso_days < @korea_1961 -> 8.5
      true -> 9
    end
  end
end
