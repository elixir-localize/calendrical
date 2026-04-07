defmodule Calendrical.FiscalYear do
  @moduledoc """
  Pre-built fiscal-year calendars for ISO 3166 territories.

  Many jurisdictions use a fiscal (financial, accounting, tax) year that does
  not start on 1 January. For example, the United States federal fiscal year
  begins on 1 October, and the United Kingdom tax year begins on 6 April.

  This module embeds the fiscal-year start month for ~50 territories at
  compile time (sourced from `priv/fiscal_years_by_territory.csv`) and
  provides a factory, `calendar_for/1`, that returns a Calendrical month-based
  calendar configured for that territory.

  The returned calendar is a fully-fledged `Calendar` implementation: it can be
  used with `Date.new/4`, `Date.shift/2`, `Calendrical.Interval`,
  `Calendrical.localize/3`, the `Calendar.strftime/3` formatter, and the native
  `~D` sigil with calendar suffix.

  ## Examples

      iex> {:ok, us_fy} = Calendrical.FiscalYear.calendar_for(:US)
      iex> us_fy
      Calendrical.FiscalYear.US

      iex> :US in Calendrical.FiscalYear.known_fiscal_calendars()
      true

  """

  @fiscal_year_data "./priv/fiscal_years_by_territory.csv"

  [_headings | rows] =
    @fiscal_year_data
    |> File.read!()
    |> String.split("\r\n")

  rows =
    Enum.map(rows, fn row ->
      String.split(row, ~r/(,\"|\",)/)
      |> Enum.flat_map(fn r ->
        if String.contains?(r, "\"") do
          ["dont_care"]
        else
          String.split(r, ",")
        end
      end)
    end)

  @fiscal_year_by_territory rows
                            |> Enum.map(fn
                              [_, "", _, _, _month, _day, _min_days, _] ->
                                nil

                              [
                                _,
                                territory,
                                _,
                                calendar_name,
                                month,
                                _day,
                                _min_days,
                                _
                              ]
                              when calendar_name in [
                                     "Cldr.Calendar.Gregorian",
                                     "Calendrical.Gregorian"
                                   ] ->
                                {:ok, territory} = Localize.validate_territory(territory)
                                calendar = Calendrical.Gregorian
                                month = String.to_integer(month)
                                {territory, [calendar: calendar, month_of_year: month]}

                              _other ->
                                nil
                            end)
                            |> Enum.reject(&is_nil/1)
                            |> Map.new()

  @known_fiscal_calendars Map.keys(@fiscal_year_by_territory)

  @doc """
  Returns the map of all known fiscal-year configurations keyed by ISO 3166
  territory code.

  Each value is a keyword list with `:calendar` and `:month_of_year` keys
  describing the base calendar and the starting month of the fiscal year.

  ### Returns

  * A map of `%{atom() => Keyword.t()}`.

  ### Examples

      iex> map = Calendrical.FiscalYear.known_fiscal_years()
      iex> Map.has_key?(map, :US)
      true

  """
  def known_fiscal_years do
    @fiscal_year_by_territory
  end

  @doc """
  Returns the list of ISO 3166 territory codes for which a pre-built fiscal
  calendar is available.

  ### Returns

  * A list of atoms (territory codes).

  ### Examples

      iex> :US in Calendrical.FiscalYear.known_fiscal_calendars()
      true

  """
  def known_fiscal_calendars do
    @known_fiscal_calendars
  end

  @doc """
  Returns a Calendrical fiscal-year calendar module for the given ISO 3166
  territory code.

  The calendar module is created on first use and cached as a normal Elixir
  module (e.g. `Calendrical.FiscalYear.US`). Subsequent calls return the same
  module.

  ### Arguments

  * `territory` is any value accepted by `Localize.validate_territory/1`,
    typically an atom such as `:US`, `:UK`, `:AU`, `:JP`.

  ### Returns

  * `{:ok, calendar_module}` on success, where `calendar_module` is a module
    implementing both the `Calendar` and `Calendrical` behaviours.

  * `{:error, exception}` if the territory is unknown or has no pre-built
    fiscal calendar.

  ### Examples

      iex> {:ok, us_fy} = Calendrical.FiscalYear.calendar_for(:US)
      iex> us_fy
      Calendrical.FiscalYear.US

  """
  def calendar_for(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory),
         {:ok, territory} <- known_fiscal_calendar(territory) do
      get_or_create_calendar_for(territory, Map.get(known_fiscal_years(), territory))
    end
  end

  defp known_fiscal_calendar(territory) do
    if territory in @known_fiscal_calendars do
      {:ok, territory}
    else
      {:error, Localize.UnknownCalendarError.exception(calendar: territory)}
    end
  end

  defp get_or_create_calendar_for(territory, config) do
    module = Module.concat(Calendrical.FiscalYear, territory)
    Calendrical.new(module, :month, config)
  end
end
