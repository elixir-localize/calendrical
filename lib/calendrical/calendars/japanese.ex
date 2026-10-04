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
    case year_of_era(year, month, day) do
      {:error, _reason} = error -> error
      {year, _era} -> year
    end
  end

  defdelegate date_from_iso_days(iso_days), to: Calendrical.Gregorian
  defdelegate date_to_iso_days(year, month, day), to: Calendrical.Gregorian

  @impl Calendar
  defdelegate leap_year?(year), to: Calendrical.Gregorian

  @doc """
  Returns the number of days in the given month, whatever its year.

  Its months are the Gregorian calendar's.

  ### Arguments

  * `month` is a month number, 1..12.

  ### Returns

  * The number of days, where the month has as many in every year.

  * `{:ambiguous, range}` where the month's length depends on the year.

  * `{:error, :undefined}` for any other value.

  ### Examples

      iex> Calendrical.Japanese.days_in_month(1)
      31

      iex> Calendrical.Japanese.days_in_month(2)
      {:ambiguous, 28..29}

  """
  @impl true
  def days_in_month(month) when month in 1..12, do: Calendrical.Gregorian.days_in_month(month)
  def days_in_month(_month), do: {:error, :undefined}
end
