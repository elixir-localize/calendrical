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
  use Calendrical.Calendar.Lunisolar,
    epoch: Application.compile_env(:calendrical, :vietnamese_epoch, ~D[-2636-02-15]),
    cldr_calendar_type: :chinese,
    location: &__MODULE__.location/1

  import Astro.Math,
    only: [
      angle: 3,
      mt: 1
    ]

  alias Astro.Time
  alias Calendrical.Lunisolar

  @mid_autumn_month 8
  @mid_autumn_day 15

  # 1 January 1968: North Vietnam's switch from UTC+8 to UTC+7 (decree of
  # 8 August 1967). No new moon or solstice falls near a day boundary between
  # the decree and the year boundary, so 1968-01-01 and 1967-08-08 yield
  # identical dates.
  @vietnam_1968 Calendrical.Gregorian.date_to_iso_days(1968, 1, 1)

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
  @spec mid_autumn_for_gregorian_year(Calendar.year()) :: Date.t()
  def mid_autumn_for_gregorian_year(gregorian_year) when is_integer(gregorian_year) do
    gregorian_date_for_lunar(gregorian_year, @mid_autumn_month, @mid_autumn_day)
  end

  @doc false
  def new_moon_on_or_after(iso_days) do
    Lunisolar.new_moon_on_or_after(iso_days, &location/1)
  end

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
