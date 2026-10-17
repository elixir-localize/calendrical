defmodule Calendrical.ISO do
  @moduledoc """
  The proleptic Gregorian calendar with ISO 8601 week rules.

  Its dates are `Calendrical.Gregorian`'s; its weeks begin on Monday and
  its week 1 is the week with at least four days of the year, the first
  with the year's first Thursday, as ISO 8601 numbers them.

  """

  use Calendrical.Calendar,
    epoch: ~D[0001-01-01],
    cldr_calendar_type: :gregorian,
    years_in_cycle: 400,
    weeks: [first_day: 1, min_days_in_first_week: 4]

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
  @spec days_in_month(Calendar.year(), Calendar.month()) :: Calendar.day()
  def days_in_month(year, month), do: Calendar.ISO.days_in_month(year, month)

  @impl Calendar
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day),
      do: Calendar.ISO.valid_date?(year, month, day)

  def valid_date?(_year, _month, _day), do: false
end
