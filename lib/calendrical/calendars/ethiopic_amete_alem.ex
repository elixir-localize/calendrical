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
  `Calendrical.Ethiopic`. `amete_alem_year - era_offset()` yields
  the corresponding Amete Mihret year.

  """
  @spec era_offset() :: 5500
  def era_offset, do: @era_offset

  @doc """
  Returns the corresponding `Calendrical.Ethiopic` (Amete Mihret)
  year for the given Amete Alem year.

  """
  @spec amete_mihret_year(year) :: integer()
  def amete_mihret_year(amete_alem_year), do: amete_alem_year - @era_offset

  @doc """
  Returns the Amete Alem year for the given Amete Mihret
  (`Calendrical.Ethiopic`) year.

  """
  @spec amete_alem_year(integer()) :: year
  def amete_alem_year(amete_mihret_year), do: amete_mihret_year + @era_offset

  # ── Configuration overrides ──────────────────────────────────────────────

  @impl true
  @spec leap_year?(year) :: boolean()
  def leap_year?(year) do
    Calendrical.Ethiopic.leap_year?(amete_mihret_year(year))
  end

  @impl true
  @spec days_in_month(year, month) :: 5..30
  def days_in_month(year, month) do
    Calendrical.Ethiopic.days_in_month(amete_mihret_year(year), month)
  end

  @impl true
  def days_in_year(year) do
    Calendrical.Ethiopic.days_in_year(amete_mihret_year(year))
  end

  @impl true
  def quarter_of_year(_year, _month, _day), do: {:error, :not_defined}

  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Calendrical.Ethiopic.valid_date?(amete_mihret_year(year), month, day)
  end

  def valid_date?(_year, _month, _day), do: false

  @impl true
  def day_of_week(year, month, day, starting_on) do
    Calendrical.Ethiopic.day_of_week(amete_mihret_year(year), month, day, starting_on)
  end

  # ── Calendar conversion ──────────────────────────────────────────────────

  @doc """
  Returns the number of ISO days for the given Amete Alem `year`,
  `month`, and `day`.

  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day) do
    Calendrical.Ethiopic.date_to_iso_days(amete_mihret_year(year), month, day)
  end

  @doc """
  Returns an Amete Alem `{year, month, day}` for the given ISO day
  number.

  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days) do
    {am_year, month, day} = Calendrical.Ethiopic.date_from_iso_days(iso_days)
    {amete_alem_year(am_year), month, day}
  end
end
