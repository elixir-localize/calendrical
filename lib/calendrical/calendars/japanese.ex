defmodule Calendrical.Japanese do
  @moduledoc """
  Implements the Japanese calendar that is calendrically
  the same as the proleptic Gregorian calendar but has a
  different era structure.

  """

  use Calendrical.Calendar,
    epoch: ~D[0001-01-01],
    weeks: [first_day: Calendrical.monday()],
    cldr_calendar_type: :japanese,
    years_in_cycle: 400

  @impl true
  defdelegate date_from_iso_days(iso_days), to: Calendrical.Gregorian
  @impl true
  defdelegate date_to_iso_days(year, month, day), to: Calendrical.Gregorian

  @impl Calendar
  defdelegate leap_year?(year), to: Calendrical.Gregorian
end
