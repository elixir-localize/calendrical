defmodule Calendrical.InvalidPartError do
  @moduledoc """
  Exception raised when an unknown date part is supplied to a
  localization function.

  ### Fields

  * `:part` — the unknown part that was supplied.
  * `:valid_parts` — the list of valid date parts.

  """

  defexception [:part, :valid_parts]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{part: part, valid_parts: valid_parts}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "format",
      "The date part %{part} is not known. Valid date parts are %{valid_parts}",
      part: inspect(part),
      valid_parts: inspect(valid_parts)
    )
  end
end
