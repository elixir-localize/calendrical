defmodule Calendrical.Base.Common do
  @moduledoc false

  # Logic shared verbatim by Calendrical.Base.Month and
  # Calendrical.Base.Week, plus calendar-aligned week numbering
  # shared by the Behaviour calendars that define weeks (Hebrew and
  # the Islamic family). Only functions whose semantics are
  # identical across their users belong here; unit-specific
  # arithmetic stays in the respective base module. See
  # ARCHITECTURE.md for the division of labour between the layers.

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

  # Calendar-aligned week numbering for Behaviour calendars: weeks
  # run on the calendar's own week boundary (its `first_day_of_week`
  # option) and week 1 is the week containing the first day of the
  # year, so a year that opens mid-week has a short week 1. Every
  # date numbers within its own year — no ISO-style spill into the
  # adjacent year's numbering.
  def week_of_year(calendar, year, month, day) do
    day_of_year =
      calendar.date_to_iso_days(year, month, day) - calendar.date_to_iso_days(year, 1, 1) + 1

    {year, div(day_of_year - 2 + first_day_offset(calendar, year), @days_in_week) + 1}
  end

  def weeks_in_year(calendar, year) do
    days_in_year = calendar.days_in_year(year)
    offset = first_day_offset(calendar, year)
    weeks = div(days_in_year - 2 + offset, @days_in_week) + 1
    days_in_last_week = days_in_year + offset - 1 - (weeks - 1) * @days_in_week
    {weeks, days_in_last_week}
  end

  # Position of the year's first day within its (calendar-native)
  # week, 1-based: 1 when the year opens on the week's first day.
  defp first_day_offset(calendar, year) do
    {first_dow, 1, 7} = calendar.day_of_week(year, 1, 1, :default)
    first_dow
  end
end
