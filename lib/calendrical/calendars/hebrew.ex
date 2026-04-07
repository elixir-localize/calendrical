defmodule Calendrical.Hebrew do
  @moduledoc """
  Implementation of the Hebrew (Jewish) calendar.

  The Hebrew calendar is a *lunisolar* calendar with 12 months in an
  ordinary year and 13 months in a leap year. The leap month, *Adar II*
  (month 13), is inserted in the 3rd, 6th, 8th, 11th, 14th, 17th and
  19th years of each 19-year *Metonic* cycle.

  Year length varies between 353, 354, 355 (ordinary years) and 383,
  384, 385 (leap years) days. The variability comes from two of the
  twelve "fixed" months — *Marheshvan* (month 8) and *Kislev* (month 9)
  — which can each be either 29 or 30 days, plus the *molad of Tishri*
  delay rules (`hebrew-calendar-elapsed-days` and the year-length
  correction `dehiyyah`) used to keep the calendar aligned with both
  the lunar and solar cycles and to prevent certain holidays from
  falling on prohibited days of the week.

  ## Month numbering

  Month numbers run from **Nisan = 1** through **Adar II = 13**, but
  the *year* changes on **1 Tishri** (month 7), not on 1 Nisan. This
  means that 30 Adar (or 29 Adar II in a leap year) of year *y* is
  immediately followed by 1 Nisan of the *same* year *y*, while 29 Elul
  of year *y* is immediately followed by 1 Tishri of year *y + 1*.

  | # | Name        | Length |
  |---|-------------|--------|
  | 1 | Nisan       | 30 |
  | 2 | Iyyar       | 29 |
  | 3 | Sivan       | 30 |
  | 4 | Tammuz      | 29 |
  | 5 | Av          | 30 |
  | 6 | Elul        | 29 |
  | 7 | Tishri      | 30 *(year start)* |
  | 8 | Marheshvan  | 29 or 30 |
  | 9 | Kislev      | 30 or 29 |
  | 10| Tevet       | 29 |
  | 11| Shevat      | 30 |
  | 12| Adar (I)    | 29 ordinary, 30 leap |
  | 13| Adar II     | 29 *(leap years only)* |

  Days are assumed to begin at midnight rather than at sunset.

  ## Reference

  Algorithms are taken from Dershowitz & Reingold, *Calendrical
  Calculations* (4th ed.), Chapter 8, "The Hebrew Calendar".

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

  # Hebrew month constants used by the algorithms below
  # (1 = Nisan ... 13 = Adar II).
  @nisan 1
  @iyyar 2
  @tammuz 4
  @elul 6
  @tishri 7
  @marheshvan 8
  @kislev 9
  @tevet 10
  @adar 12
  @adar_ii 13

  # Months that are always 29 days (regardless of year type).
  @short_months_always [@iyyar, @tammuz, @elul, @tevet, @adar_ii]

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Hebrew `year` is a leap year (i.e. it
  contains the embolismic month *Adar II*).

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

  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month) when month in 1..13 do
    cond do
      month in @short_months_always -> 29
      month == @adar and not leap_year?(year) -> 29
      month == @marheshvan and not long_marheshvan?(year) -> 29
      month == @kislev and short_kislev?(year) -> 29
      true -> 30
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

  """
  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= 1 and month in 1..13 and day in 1..30 do
    month <= months_in_year(year) and day <= days_in_month(year, month)
  end

  def valid_date?(_year, _month, _day), do: false

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
    # than the true year, so we search forward from approx - 1.
    approx = div((iso_days - epoch()) * 98_496, 35_975_351) + 1
    year = find_year(iso_days, approx - 1)

    # If the date is before 1 Nisan of the found year, the month is
    # in the second half of the year (Tishri-Elul) — i.e. month ≥ 7.
    # Otherwise it is in the first half (Nisan-Av).
    nisan_1_iso = date_to_iso_days(year, @nisan, 1)
    start_month = if iso_days < nisan_1_iso, do: @tishri, else: @nisan

    month = find_month(iso_days, year, start_month)
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

  # True when Marheshvan has 30 days in this year.
  defp long_marheshvan?(year) do
    days_in_year(year) in [355, 385]
  end

  # True when Kislev has 29 days in this year.
  defp short_kislev?(year) do
    days_in_year(year) in [353, 383]
  end

  # Number of days from 1 Tishri of the given year to 1-of-the-given-month
  # of the same year, *not* counting the day itself.
  #
  # The Hebrew year begins on 1 Tishri (month 7), so for months in the
  # second half of the calendar (Nisan-Elul = 1-6) we have to first add
  # the days from Tishri through the end of the year, then continue
  # from Nisan up to the requested month.
  defp month_offset(year, month) when month >= @tishri do
    sum_month_lengths(year, @tishri, month - 1)
  end

  defp month_offset(year, month) do
    last = months_in_year(year)
    sum_month_lengths(year, @tishri, last) + sum_month_lengths(year, @nisan, month - 1)
  end

  defp sum_month_lengths(_year, from, to) when from > to, do: 0

  defp sum_month_lengths(year, from, to) do
    Enum.reduce(from..to, 0, fn m, acc -> acc + days_in_month(year, m) end)
  end

  # Search forward from a candidate year for the first year whose 1
  # Tishri is on or before iso_days. The approximation in
  # `date_from_iso_days/1` is at most one year too low, so this loop
  # iterates at most twice.
  defp find_year(iso_days, year) do
    if hebrew_new_year(year + 1) > iso_days do
      year
    else
      find_year(iso_days, year + 1)
    end
  end

  # Search forward from a starting month for the first month of the
  # given year whose last day is on or after iso_days.
  defp find_month(iso_days, year, month) do
    last_iso_of_month = date_to_iso_days(year, month, days_in_month(year, month))

    if iso_days <= last_iso_of_month do
      month
    else
      find_month(iso_days, year, month + 1)
    end
  end
end
