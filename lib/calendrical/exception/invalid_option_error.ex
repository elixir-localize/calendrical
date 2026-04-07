defmodule Calendrical.Formatter.InvalidOptionError do
  @moduledoc """
  Exception raised when an unknown option, or an option with an
  invalid value, is supplied to a calendar formatter.

  ### Fields

  * `:option` — the option name that was supplied.
  * `:value` — the value that was supplied for the option.

  """

  defexception [:option, :value]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{option: option, value: value}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "option",
      "Invalid option or option value. Found option %{option} with value %{value}",
      option: inspect(option),
      value: inspect(value)
    )
  end
end
