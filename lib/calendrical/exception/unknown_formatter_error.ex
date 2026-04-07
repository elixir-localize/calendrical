defmodule Calendrical.Formatter.UnknownFormatterError do
  @moduledoc """
  Exception raised when a calendar formatter module cannot be
  resolved.

  ### Fields

  * `:formatter` — the value that was supplied as a formatter.

  """

  defexception [:formatter]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{formatter: formatter}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "format",
      "Invalid formatter %{formatter}",
      formatter: inspect(formatter)
    )
  end
end
