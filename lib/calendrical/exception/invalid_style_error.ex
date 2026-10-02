defmodule Calendrical.InvalidStyleError do
  @moduledoc """
  Exception raised when an unknown date style width is supplied
  to a localization function.

  ### Fields

  * `:style` — the unknown style that was supplied.
  * `:valid_styles` — the list of valid style widths.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "style"]

  defexception [:style, :valid_styles]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{style: style, valid_styles: valid_styles}) do
    style = inspect(style)
    valid_styles = inspect(valid_styles)

    ~t"The date style #{style} is not known. Valid styles are #{valid_styles}"
  end
end
