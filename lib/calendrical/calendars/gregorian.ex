defmodule Calendrical.Gregorian do
  @moduledoc """
  Implements the proleptic Gregorian calendar.

  Intended to be plug-compatible with `Calendar.ISO`
  with additional functions to support localisation,
  date ranges for `year`, `quarter`, `month` and `week`.

  When calling `Calendrical.localize/3` on a
  `Calendar.ISO`-based date, those dates are first
  moved to this calendar acting as a localisation
  proxy.

  Its dates are `Calendar.ISO`'s, and it is the base calendar of the
  fiscal years `Calendrical.FiscalYear` builds and of the month
  calendars `Calendrical.new/3` makes.

  """

  use Calendrical.Calendar,
    epoch: ~D[0001-01-01],
    cldr_calendar_type: :gregorian,
    years_in_cycle: 400

  @impl true
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) :: integer()
  def date_to_iso_days(year, month, day) do
    {days, _fraction} = Calendar.ISO.naive_datetime_to_iso_days(year, month, day, 0, 0, 0, {0, 0})
    days
  end

  @impl true
  @spec date_from_iso_days(integer()) :: {Calendar.year(), Calendar.month(), Calendar.day()}
  def date_from_iso_days(iso_days), do: Calendar.ISO.date_from_iso_days(iso_days)

  @impl Calendar
  @spec leap_year?(Calendar.year()) :: boolean()
  def leap_year?(year), do: Calendar.ISO.leap_year?(year)

  @impl Calendar
  @spec days_in_month(Calendar.year(), Calendar.month()) ::
          Calendar.day() | {:error, Exception.t()}
  def days_in_month(year, month), do: Calendar.ISO.days_in_month(year, month)

  @impl Calendar
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day),
      do: Calendar.ISO.valid_date?(year, month, day)

  def valid_date?(_year, _month, _day), do: false
end
