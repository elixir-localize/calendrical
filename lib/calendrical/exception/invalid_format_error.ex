defmodule Calendrical.InvalidFormatError do
  @moduledoc """
  Exception raised when an unknown date format width is supplied
  to a localization function.

  ### Fields

  * `:format` — the unknown format that was supplied.
  * `:valid_formats` — the list of valid format widths.

  """

  defexception [:format, :valid_formats]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{format: format, valid_formats: valid_formats}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "format",
      "The date format %{format} is not known. Valid formats are %{valid_formats}",
      format: inspect(format),
      valid_formats: inspect(valid_formats)
    )
  end
end
