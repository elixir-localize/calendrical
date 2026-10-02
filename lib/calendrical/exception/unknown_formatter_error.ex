defmodule Calendrical.Formatter.UnknownFormatterError do
  @moduledoc """
  Exception raised when a calendar formatter module cannot be
  resolved.

  ### Fields

  * `:formatter` — the value that was supplied as a formatter.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "format"]

  defexception [:formatter]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{formatter: formatter}) do
    formatter = inspect(formatter)

    ~t"Invalid formatter #{formatter}"
  end
end
