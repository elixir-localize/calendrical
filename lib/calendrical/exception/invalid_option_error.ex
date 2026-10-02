defmodule Calendrical.Formatter.InvalidOptionError do
  @moduledoc """
  Exception raised when an unknown option, or an option with an
  invalid value, is supplied to a calendar formatter.

  ### Fields

  * `:option` — the option name that was supplied.
  * `:value` — the value that was supplied for the option.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "option"]

  defexception [:option, :value]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{option: option, value: value}) do
    option = inspect(option)
    value = inspect(value)

    ~t"Invalid option or option value. Found option #{option} with value #{value}"
  end
end
