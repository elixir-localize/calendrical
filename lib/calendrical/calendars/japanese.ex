defmodule Calendrical.Japanese do
  @moduledoc """
  Implements the Japanese calendar that is calendrically
  the same as the proleptic Gregorian calendar but has a
  different era structure.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0001-01-01],
    month_of_year: 1,
    min_days_in_first_week: 1,
    day_of_week: Calendrical.monday(),
    cldr_calendar_type: :japanese

  def calendar_year(year, month, day) do
    {year, _era} = year_of_era(year, month, day)
    year
  end

  defdelegate date_from_iso_days(iso_days), to: Calendrical.Gregorian
  defdelegate date_to_iso_days(year, month, day), to: Calendrical.Gregorian

  @impl Calendar
  defdelegate leap_year?(year), to: Calendrical.Gregorian
end
