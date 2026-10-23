defmodule Calendrical.UnknownFiscalYearError do
  @moduledoc """
  Exception returned by `Calendrical.FiscalYear.calendar_for/1` for a
  territory whose fiscal year it does not know.

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
    ~t"No fiscal year is known for the territory #{territory}"
  end
end
