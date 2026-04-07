defmodule Calendrical.Indian do
  @moduledoc """
  Implementation of the Indian National (Saka) calendar.

  The Indian National Calendar is the official civil calendar of
  India, adopted in 1957 by the Indian Calendar Reform Committee. It
  is a *solar* calendar with twelve months whose lengths are derived
  from the proleptic Gregorian calendar but use historical Indian
  month names. Year numbering follows the *Saka* era:

      saka_year = gregorian_year - 78

  So Saka 1 corresponds to Gregorian 79 CE and 1 Chaitra 1947 Saka =
  22 March 2025 CE.

  ## Month structure

  | # | Name       | Days (ordinary) | Days (leap) |
  |---|------------|-----------------|-------------|
  | 1 | Chaitra    | 30              | 31          |
  | 2 | Vaisakha   | 31              | 31          |
  | 3 | Jyaistha   | 31              | 31          |
  | 4 | Asadha     | 31              | 31          |
  | 5 | Sravana    | 31              | 31          |
  | 6 | Bhadra     | 31              | 31          |
  | 7 | Asvina     | 30              | 30          |
  | 8 | Kartika    | 30              | 30          |
  | 9 | Agrahayana | 30              | 30          |
  | 10| Pausa      | 30              | 30          |
  | 11| Magha      | 30              | 30          |
  | 12| Phalguna   | 30              | 30          |

  Total year length is 365 days (366 in leap years). The year is a
  leap year exactly when the corresponding Gregorian year (`saka_year
  + 78`) is a Gregorian leap year. In a Gregorian leap year, the
  first day of the Saka year (1 Chaitra) falls on **21 March**;
  in an ordinary Gregorian year it falls on **22 March**.

  Days are assumed to begin at midnight rather than at sunrise.

  ## Reference

  - Indian Calendar Reform Committee, *Report of the Calendar Reform
    Committee*, Government of India (1955).
  - Dershowitz & Reingold, *Calendrical Calculations* (4th ed.),
    Chapter 11, "The Modern Hindu Calendars".
  - CLDR `:indian` calendar type.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0079-03-22 Calendrical.Gregorian],
    cldr_calendar_type: :indian,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..31

  @gregorian_offset 78

  # Days in each month for an ordinary Saka year (Chaitra = 30).
  # In a leap year, Chaitra (month 1) is 31 days; the others are
  # unchanged.
  @month_lengths_ordinary {30, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30}
  @month_lengths_leap {31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30}

  @doc """
  Returns the offset (in years) between the Saka era and the
  proleptic Gregorian calendar. `saka_year + gregorian_offset()`
  yields the corresponding Gregorian year.

  """
  @spec gregorian_offset() :: 78
  def gregorian_offset, do: @gregorian_offset

  @doc """
  Returns the Gregorian year corresponding to the given Saka year.

  """
  @spec gregorian_year(year) :: integer()
  def gregorian_year(saka_year), do: saka_year + @gregorian_offset

  @doc """
  Returns the Saka year corresponding to the given Gregorian year.

  """
  @spec saka_year(integer()) :: year
  def saka_year(gregorian_year), do: gregorian_year - @gregorian_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Saka year is a leap year. The leap year
  rule is the proleptic Gregorian rule applied to the corresponding
  Gregorian year.

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Gregorian.leap_year?(gregorian_year(year))
  end

  @doc """
  Returns the number of days in the given Saka `year` and `month`.

  """
  @impl true
  @spec days_in_month(year, month) :: 30..31
  def days_in_month(year, month) when month in 1..12 do
    table = if leap_year?(year), do: @month_lengths_leap, else: @month_lengths_ordinary
    elem(table, month - 1)
  end

  @doc """
  Returns the number of days in the given Saka `year` (365 or 366).

  """
  @impl true
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @doc """
  Determines if the given `year`, `month`, and `day` form a valid
  Saka date.

  """
  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             month in 1..12 and day in 1..31 do
    day <= days_in_month(year, month)
  end

  def valid_date?(_year, _month, _day), do: false

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Saka `year`,
  `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    chaitra_1(year) + month_offset(year, month) + day - 1
  end

  @doc """
  Returns a Saka `{year, month, day}` for the given ISO day number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    # The Saka year is determined by which Saka new-year falls on or
    # before iso_days. Start from the Saka year corresponding to the
    # Gregorian year of the input date and walk back at most one year.
    {greg_year, _, _} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    candidate = saka_year(greg_year)

    saka_year =
      if iso_days >= chaitra_1(candidate) do
        candidate
      else
        candidate - 1
      end

    day_of_year = iso_days - chaitra_1(saka_year) + 1
    {month, day_of_month} = month_and_day(saka_year, day_of_year)

    {saka_year, month, day_of_month}
  end

  # ── Internal helpers ─────────────────────────────────────────────────────

  # ISO day number of 1 Chaitra of the given Saka year. In a Gregorian
  # leap year, Chaitra 1 falls on 21 March; otherwise on 22 March.
  defp chaitra_1(saka_year) do
    g_year = gregorian_year(saka_year)

    chaitra_day =
      if Calendrical.Gregorian.leap_year?(g_year), do: 21, else: 22

    Calendrical.Gregorian.date_to_iso_days(g_year, 3, chaitra_day)
  end

  # Number of days from 1 Chaitra of the given year to 1-of-the-given
  # month of the same year.
  defp month_offset(year, month) do
    table = if leap_year?(year), do: @month_lengths_leap, else: @month_lengths_ordinary

    Enum.reduce(0..(month - 2)//1, 0, fn idx, acc -> acc + elem(table, idx) end)
  end

  # Find the (month, day_of_month) for the given 1-based day_of_year
  # within the given Saka year.
  defp month_and_day(year, day_of_year) do
    table = if leap_year?(year), do: @month_lengths_leap, else: @month_lengths_ordinary

    Enum.reduce_while(1..12, day_of_year, fn month, remaining ->
      length = elem(table, month - 1)

      if remaining <= length do
        {:halt, {month, remaining}}
      else
        {:cont, remaining - length}
      end
    end)
  end
end
