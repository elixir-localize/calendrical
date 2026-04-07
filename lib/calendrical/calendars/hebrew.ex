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
    months_in_leap_year: 13

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

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Hebrew `year` is a leap year (i.e. it
  contains the embolismic month *Adar I*).

  Leap years are determined by a 19-year Metonic cycle: years
  3, 6, 8, 11, 14, 17, and 19 of each cycle are leap years.

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Integer.mod(7 * year + 1, 19) < 7
  end

  @doc """
  Returns the number of months in the given Hebrew `year` (12 in an
  ordinary year, 13 in a leap year).

  """
  @impl true
  @spec months_in_year(year) :: 12..13
  def months_in_year(year) do
    if leap_year?(year), do: 13, else: 12
  end

  @doc """
  The Hebrew calendar does not define quarters because the year has
  a variable number of months (12 or 13).

  """
  @impl true
  def quarter_of_year(_year, _month, _day) do
    {:error, :not_defined}
  end

  @doc """
  Returns the number of days in the given Hebrew `year` and `month`.

  Returns `{:error, :invalid_month}` if `month` is `6` (Adar I) and
  `year` is not a leap year.

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
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

  """
  @impl true
  @spec days_in_year(year) :: 353..355 | 383..385
  def days_in_year(year) do
    hebrew_new_year(year + 1) - hebrew_new_year(year)
  end

  @doc """
  Determines if the given `year`, `month`, and `day` form a valid
  Hebrew date.

  Month 6 (*Adar I*) is only valid in leap years.

  """
  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= 1 and month in 1..13 and day in 1..30 do
    cond do
      month == @adar_i and not leap_year?(year) -> false
      true -> day <= days_in_month(year, month)
    end
  end

  def valid_date?(_year, _month, _day), do: false

  @doc """
  Returns the month of the year for the given Hebrew date.

  In a leap year, month 7 is *Adar II* and is returned as
  `{7, :leap}` so that `Calendrical.localize/3` picks up the
  CLDR `7_yeartype_leap` variant ("Adar II"). All other months
  are returned as plain integers.

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

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    hebrew_new_year(year) + day - 1 + month_offset(year, month)
  end

  @doc """
  Returns a Hebrew `{year, month, day}` for the given ISO day number.

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
  defp month_offset(year, month) do
    year
    |> valid_months()
    |> Enum.take_while(&(&1 != month))
    |> Enum.reduce(0, fn m, acc -> acc + days_in_month(year, m) end)
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
