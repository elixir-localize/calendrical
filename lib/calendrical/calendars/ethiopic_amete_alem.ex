defmodule Calendrical.Ethiopic.AmeteAlem do
  @moduledoc """
  Implementation of the Ethiopic calendar with the *Amete Alem* (Era
  of the World, *Anno Mundi*) year numbering.

  This calendar is structurally identical to `Calendrical.Ethiopic` —
  same 13-month layout, same leap-year rule, same days-in-month — but
  the year is counted from the traditional Ethiopian Christian date
  of the creation of the world rather than from the Era of Mercy:

      amete_alem_year = amete_mihret_year + 5500

  So 1 Amete Alem = -5499 Julian = -5492-07-17 proleptic Gregorian
  (per CLDR era data) and modern Ethiopic year 2017 (Amete Mihret) =
  7517 Amete Alem.

  Days are assumed to begin at midnight rather than at sunset.

  ## Reference

  - Dershowitz & Reingold, *Calendrical Calculations* (4th ed.),
    §4.2 ("Ethiopic and Coptic Calendars").
  - CLDR `:ethiopic_amete_alem` calendar type. The CLDR era data
    places the *aa* era at proleptic Gregorian `-5492-07-17`.

  See `Calendrical.Ethiopic` for the month structure and the
  `mod(year, 4) == 3` leap-year rule.

  """

  use Calendrical.Behaviour,
    epoch: Date.new!(-5492, 7, 17, Calendrical.Gregorian),
    cldr_calendar_type: :ethiopic_amete_alem,
    months_in_ordinary_year: 13,
    months_in_leap_year: 13

  # The 13-month Ethiopic year does not define quarters.
  @dialyzer [
    {:nowarn_function, quarter_of_year: 3}
  ]

  @type year :: integer()
  @type month :: 1..13
  @type day :: 1..30

  @era_offset 5500

  @doc """
  Returns the offset (in years) between the Amete Alem (Era of the
  World) and the Amete Mihret (Era of Mercy) used by
  `Calendrical.Ethiopic`.

  Subtracting this offset from an Amete Alem year yields the
  corresponding Amete Mihret year.

  ### Returns

  * The integer `5500`.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.era_offset()
      5500

  """
  @spec era_offset() :: 5500
  def era_offset, do: @era_offset

  @doc """
  Returns the corresponding `Calendrical.Ethiopic` (Amete Mihret)
  year for the given Amete Alem year.

  ### Arguments

  * `amete_alem_year` is any Amete Alem year as an integer.

  ### Returns

  * An integer Amete Mihret year (5500 less than the input).

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.amete_mihret_year(7518)
      2018

  """
  @spec amete_mihret_year(year) :: integer()
  def amete_mihret_year(amete_alem_year) when is_integer(amete_alem_year),
    do: amete_alem_year - @era_offset

  @doc """
  Returns the Amete Alem year for the given Amete Mihret
  (`Calendrical.Ethiopic`) year.

  ### Arguments

  * `amete_mihret_year` is any Amete Mihret (Ethiopic) year as an
    integer.

  ### Returns

  * An integer Amete Alem year (5500 more than the input).

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.amete_alem_year(2018)
      7518

  """
  @spec amete_alem_year(integer()) :: year
  def amete_alem_year(amete_mihret_year) when is_integer(amete_mihret_year),
    do: amete_mihret_year + @era_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @doc """
  Returns whether the given Amete Alem `year` is a leap year.

  The leap-year rule is that of `Calendrical.Ethiopic` applied to
  the corresponding Amete Mihret year.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  ### Returns

  * `true` if the year contains 366 days; otherwise `false`.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.leap_year?(7519)
      true

      iex> Calendrical.Ethiopic.AmeteAlem.leap_year?(7518)
      false

  """
  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Ethiopic.leap_year?(amete_mihret_year(year))
  end

  @doc """
  Returns the number of days in the given Amete Alem `year` and
  `month`.

  Months 1-12 always have 30 days; month 13 has 5 days, or 6
  in a leap year.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  ### Returns

  * An integer number of days.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.days_in_month(7518, 13)
      5

      iex> Calendrical.Ethiopic.AmeteAlem.days_in_month(7519, 13)
      6

  """
  @impl true
  @spec days_in_month(year, month) :: 5..30
  def days_in_month(year, month) do
    Calendrical.Ethiopic.days_in_month(amete_mihret_year(year), month)
  end

  @doc """
  Returns the number of days in the given Amete Alem `year`.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  ### Returns

  * `365` for an ordinary year or `366` for a leap year.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.days_in_year(7518)
      365

      iex> Calendrical.Ethiopic.AmeteAlem.days_in_year(7519)
      366

  """
  @impl true
  @spec days_in_year(year) :: 365..366
  def days_in_year(year) do
    Calendrical.Ethiopic.days_in_year(amete_mihret_year(year))
  end

  @doc """
  Returns `{:error, :not_defined}` because the Ethiopic calendar
  does not define quarters; the year has 13 months and so does not
  divide evenly into four quarters.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  ### Returns

  * `{:error, :not_defined}`.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.quarter_of_year(7518, 1, 1)
      {:error, :not_defined}

  """
  @impl true
  def quarter_of_year(_year, _month, _day), do: {:error, :not_defined}

  @doc """
  Returns whether the given `year`, `month`, and `day` form a valid
  Amete Alem date.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month. Months `1..12` have 30 days;
    month 13 has 5 days, or 6 in a leap year.

  ### Returns

  * `true` if the date is valid; otherwise `false`.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.valid_date?(7518, 1, 30)
      true

      iex> Calendrical.Ethiopic.AmeteAlem.valid_date?(7519, 13, 6)
      true

      iex> Calendrical.Ethiopic.AmeteAlem.valid_date?(7518, 13, 6)
      false

  """
  @impl true
  @spec valid_date?(year, month, day) :: boolean()
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Calendrical.Ethiopic.valid_date?(amete_mihret_year(year), month, day)
  end

  def valid_date?(_year, _month, _day), do: false

  @doc """
  Returns the day of the week for the given Amete Alem `year`,
  `month`, and `day`.

  Ethiopic weeks begin on Saturday, so the returned tuple has
  `first_day_of_week = 6` and `last_day_of_week = 5`.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  * `starting_on` is `:default` for the calendar's natural week
    boundary (Saturday).

  ### Returns

  * A three-tuple `{day_of_week, first_day_of_week, last_day_of_week}`.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.day_of_week(7518, 1, 1, :default)
      {4, 6, 5}

  """
  @impl true
  @spec day_of_week(year, month, day, :default) :: {1..7, 6, 5}
  def day_of_week(year, month, day, starting_on) do
    Calendrical.Ethiopic.day_of_week(amete_mihret_year(year), month, day, starting_on)
  end

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Amete Alem `year`,
  `month`, and `day`.

  ### Arguments

  * `year` is any Amete Alem year as an integer.

  * `month` is an Ethiopic month in the range `1..13`.

  * `day` is an Ethiopic day-of-month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.date_to_iso_days(7518, 1, 1)
      739870

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Calendrical.Ethiopic.date_to_iso_days(amete_mihret_year(year), month, day)
  end

  @doc """
  Returns an Amete Alem `{year, month, day}` tuple for the given
  ISO day number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic
    ISO epoch.

  ### Returns

  * A three-tuple `{year, month, day}` in Amete Alem numbering.

  ### Examples

      iex> Calendrical.Ethiopic.AmeteAlem.date_from_iso_days(740_000)
      {7518, 5, 11}

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    {am_year, month, day} = Calendrical.Ethiopic.date_from_iso_days(iso_days)
    {amete_alem_year(am_year), month, day}
  end
end
