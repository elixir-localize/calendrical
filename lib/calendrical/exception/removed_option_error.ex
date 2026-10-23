defmodule Calendrical.RemovedOptionError do
  @moduledoc """
  Exception returned when an option Calendrical 2.0 removed is given, such
  as the parse functions' `:return_calendar`, so that a caller written for
  1.x is told rather than silently given another result. The CHANGELOG and
  the migration guide say what replaces each.

  ### Fields

  * `:option` — the option that was given.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "option"]

  defexception [:option]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{option: option}) do
    option = inspect(option)
    ~t"The option #{option} was removed in Calendrical 2.0"
  end
end
