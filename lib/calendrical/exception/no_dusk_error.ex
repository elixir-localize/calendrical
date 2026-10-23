defmodule Calendrical.NoDuskError do
  @moduledoc """
  Exception returned when a day that begins at dusk has no dusk: at a
  place and date where the sun does not set, or does not go as far below
  the horizon as nightfall asks, as in a polar summer.

  ### Fields

  * `:day_start` — `:sunset` or `:nightfall`, the dusk the day begins at.

  * `:location` — the place the dusk was sought at.

  * `:date` — the Gregorian date the dusk was sought on.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "date"]

  defexception [:day_start, :location, :date]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{day_start: :nightfall, location: location, date: date}) do
    location = place(location)
    date = inspect(date)
    ~t"Nightfall does not occur at #{location} on #{date}"
  end

  def message(%__MODULE__{location: location, date: date}) do
    location = place(location)
    date = inspect(date)
    ~t"The sun does not set at #{location} on #{date}"
  end

  # A place is written by its coordinates, as `{longitude, latitude}`.
  defp place(%{coordinates: coordinates}), do: inspect(coordinates)
  defp place(location), do: inspect(location)
end
