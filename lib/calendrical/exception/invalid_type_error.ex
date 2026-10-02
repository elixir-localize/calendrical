defmodule Calendrical.InvalidTypeError do
  @moduledoc """
  Exception raised when an unknown date format type is supplied
  to a localization function.

  ### Fields

  * `:type` — the unknown type that was supplied.
  * `:valid_types` — the list of valid format types.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "format"]

  defexception [:type, :valid_types]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{type: type, valid_types: valid_types}) do
    type = inspect(type)
    valid_types = inspect(valid_types)

    ~t"The date format type #{type} is not known. Valid format types are #{valid_types}"
  end
end
