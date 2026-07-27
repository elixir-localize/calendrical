defmodule Calendrical.InvalidStyleError do
  @moduledoc """
  Exception raised when an unknown date style width is supplied
  to a localization function.

  ### Fields

  * `:style` — the unknown style that was supplied.
  * `:valid_styles` — the list of valid style widths.

  """

  defexception [:style, :valid_styles]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{style: style, valid_styles: valid_styles}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "style",
      "The date style %{style} is not known. Valid styles are %{valid_styles}",
      style: inspect(style),
      valid_styles: inspect(valid_styles)
    )
  end
end
