defmodule Calendrical.Reform.Sweden.Transitional do
  @moduledoc """
  The transitional "Swedish calendar" in use between 1700 and 1712.

  In 1700 Sweden began a gradual transition to the Gregorian calendar by
  omitting the leap day that year (there was no 29 February 1700). The plan was
  to drop every leap day from 1700 to 1740, at which point Sweden would have
  aligned with the Gregorian calendar. The plan was abandoned after 1700, so for
  the years 1700 to 1712 Sweden ran a unique calendar that was **one day ahead
  of the Julian calendar** and ten days behind the Gregorian calendar.

  In 1712 Sweden reverted to the Julian calendar by inserting a second leap day
  that year — the only known instance of a **30 February**. From 1 March 1712
  the calendar realigned with the Julian calendar.

  This module models that transitional calendar. It is not intended for direct
  use; it exists as the 1700–1712 segment of the `Calendrical.Reform.Sweden` composite
  calendar. Within that window each date maps to the same physical day as the
  Julian date bearing the same numbers, shifted back by one day, and the date
  30 February 1712 is valid.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0001-01-01 Calendrical.Julian],
    cldr_calendar_type: :gregorian

  # The one physical day that the Swedish calendar labelled 30 February 1712.
  # In the (proleptic) Julian calendar that day is 29 February 1712.
  @february_30_1712 Calendrical.Julian.date_to_iso_days(1712, 2, 29)

  @doc """
  Converts a `year`, `month` and `day` in the transitional Swedish calendar to
  an ISO day number.

  ### Arguments

  * `year`, `month` and `day` are the parts of a Swedish calendar date in the
    1700–1712 window (30 February 1712 is accepted).

  ### Returns

  * The integer ISO day number of the given date.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.date_to_iso_days(1712, 2, 30) ==
      ...>   Calendrical.Julian.date_to_iso_days(1712, 2, 29)
      true

  """
  @spec date_to_iso_days(Calendar.year(), Calendar.month(), Calendar.day()) ::
          Calendrical.iso_day_number()
  def date_to_iso_days(year, month, day) do
    Calendrical.Julian.date_to_iso_days(year, month, day) + offset(year, month, day)
  end

  # 1700-03-01 through 1712-02-30 run one day behind Julian; from 1712-03-01 the
  # calendar is realigned with Julian. Julian's date_to_iso_days is a
  # non-validating arithmetic formula, so 30 February 1712 rolls to 1 March and
  # the -1 offset brings it back to the physical 29 February 1712.
  defp offset(year, month, day) when {year, month, day} < {1712, 3, 1}, do: -1
  defp offset(_year, _month, _day), do: 0

  @doc """
  Converts an ISO day number to a `{year, month, day}` in the transitional
  Swedish calendar.

  ### Arguments

  * `iso_days` is an integer ISO day number within the 1700–1712 window.

  ### Returns

  * A `{year, month, day}` tuple.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.date_from_iso_days(
      ...>   Calendrical.Julian.date_to_iso_days(1712, 2, 29))
      {1712, 2, 30}

  """
  @spec date_from_iso_days(Calendrical.iso_day_number()) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  def date_from_iso_days(@february_30_1712), do: {1712, 2, 30}

  def date_from_iso_days(iso_days) do
    Calendrical.Julian.date_from_iso_days(iso_days + 1)
  end

  @doc """
  Returns whether `year` is a leap year in the transitional Swedish calendar.

  Leap years follow the Julian rule; 1712 additionally carried the extra
  30 February day.

  ### Arguments

  * `year` is the year to test.

  ### Returns

  * A boolean.

  ### Examples

      iex> Calendrical.Reform.Sweden.Transitional.leap_year?(1704)
      true

  """
  @impl true
  @spec leap_year?(Calendar.year()) :: boolean()
  def leap_year?(year) do
    Calendrical.Julian.leap_year?(year)
  end
end
