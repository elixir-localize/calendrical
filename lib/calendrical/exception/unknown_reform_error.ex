defmodule Calendrical.UnknownReformError do
  @moduledoc """
  Exception returned by `Calendrical.Reform` for a territory whose change
  from the Julian to the Gregorian calendar it does not know, or a value
  that is no territory.

  ### Fields

  * `:territory` — the territory as it was given.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:territory]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{territory: territory}) do
    territory = inspect(territory)
    ~t"No calendar reform is known for the territory #{territory}"
  end
end
