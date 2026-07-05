defmodule Calendrical.Base.Common do
  @moduledoc false

  # Logic shared verbatim by Calendrical.Base.Month and
  # Calendrical.Base.Week. Only functions whose semantics are
  # identical for both units belong here; unit-specific arithmetic
  # stays in the respective base module. See ARCHITECTURE.md for
  # the division of labour between the compiled-calendar layers.

  @days_in_week 7

  # The middle field is the month for month calendars and the week
  # for week calendars. Week calendars store the week number in the
  # %Date{} struct's :month field, because the stdlib Date struct
  # has no :week field.
  defguard is_date(year, month_or_week, day)
           when is_integer(year) and is_integer(month_or_week) and is_integer(day)

  # Maps a calendar year to its era year via the Gregorian year the
  # configuration designates: the :beginning year, the :ending year,
  # or for :majority the year containing most of the calendar year
  # (the beginning year when the year starts in January..June, the
  # ending year otherwise).
  def year_of_era(year, %{year: :ending} = config) when is_integer(year) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :beginning} = config) when is_integer(year) do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority, month_of_year: starts} = config)
      when is_integer(year) and starts <= 6 do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority} = config) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _month_or_week) do
    @days_in_week
  end
end
