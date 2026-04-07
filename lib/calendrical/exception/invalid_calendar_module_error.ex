defmodule Calendrical.InvalidCalendarModuleError do
  @moduledoc """
  Exception raised when a module is referenced as a calendar but
  does not implement the `Calendar` (and `Calendrical`) behaviour.

  ### Fields

  * `:module` — the module that was expected to be a calendar.

  """

  defexception [:module]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{module: module}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "calendar",
      "%{module} is not a calendar module.",
      module: inspect(module)
    )
  end
end
