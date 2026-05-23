defmodule Calendrical.Roc do
  @moduledoc """
  Implementation of the Republic of China (Minguo) calendar.

  The ROC calendar is the proleptic Gregorian calendar with year
  numbering starting from the founding of the Republic of China on
  **1 January 1912**:

      roc_year = gregorian_year - 1911

  So 1 ROC = 1912 CE and 113 ROC = 2024 CE. The calendar is the
  official calendar of Taiwan and is also used in some legal contexts
  in mainland China for documents that pre-date 1949.

  Months and leap years follow the standard proleptic Gregorian rules
  exactly. Day boundaries are at midnight.

  ## Reference

  - CLDR `:roc` calendar type. The CLDR era data places the start of
    the *Minguo Era* (`:roc`) at proleptic Gregorian `1912-01-01` and
    the *Before R.O.C.* era (`:broc`) at all earlier dates.

  """

  use Calendrical.Behaviour,
    epoch: ~D[1912-01-01 Calendrical.Gregorian],
    cldr_calendar_type: :roc,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..31

  @gregorian_offset 1911

  @doc """
  Returns the offset (in years) between the ROC era and the proleptic
  Gregorian calendar.

  Adding this offset to a ROC year yields the corresponding Gregorian
  year.

  ### Returns

  * The integer `1911`.

  ### Examples

      iex> Calendrical.Roc.gregorian_offset()
      1911

  """
  @spec gregorian_offset() :: 1911
  def gregorian_offset, do: @gregorian_offset

  @doc """
  Returns the Gregorian year corresponding to the given ROC year.

  ### Arguments

  * `roc_year` is any ROC year as an integer.

  ### Returns

  * An integer Gregorian year (1911 more than the input).

  ### Examples

      iex> Calendrical.Roc.gregorian_year(115)
      2026

  """
  @spec gregorian_year(year) :: integer()
  def gregorian_year(roc_year), do: roc_year + @gregorian_offset

  @doc """
  Returns the ROC year corresponding to the given Gregorian year.

  ### Arguments

  * `gregorian_year` is any proleptic Gregorian year as an integer.

  ### Returns

  * An integer ROC year (1911 less than the input).

  ### Examples

      iex> Calendrical.Roc.roc_year(2026)
      115

  """
  @spec roc_year(integer()) :: year
  def roc_year(gregorian_year), do: gregorian_year - @gregorian_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Gregorian.leap_year?(gregorian_year(year))
  end

  @impl true
  @spec days_in_month(year, month) :: 28..31
  def days_in_month(year, month) do
    Calendrical.Gregorian.days_in_month(gregorian_year(year), month)
  end

  @impl true
  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Calendrical.Gregorian.valid_date?(gregorian_year(year), month, day)
  end

  def valid_date?(_year, _month, _day), do: false

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given ROC `year`, `month`,
  and `day`.

  ### Arguments

  * `year` is any ROC year as an integer.

  * `month` is a month in the range `1..12`.

  * `day` is a day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Roc.date_to_iso_days(115, 1, 1)
      739982

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Calendrical.Gregorian.date_to_iso_days(gregorian_year(year), month, day)
  end

  @doc """
  Returns a ROC `{year, month, day}` tuple for the given ISO day
  number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in the ROC calendar.

  ### Examples

      iex> Calendrical.Roc.date_from_iso_days(739_252)
      {113, 1, 2}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    {greg_year, month, day} = Calendrical.Gregorian.date_from_iso_days(iso_days)
    {roc_year(greg_year), month, day}
  end
end
