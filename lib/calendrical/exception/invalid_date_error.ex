defmodule Calendrical.Formatter.InvalidDateError do
  @moduledoc """
  Exception raised when a value supplied to a calendar formatter
  is not a recognised date.

  ### Fields

  * `:date` — the value that was supplied as a date.

  """

  defexception [:date]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{date: date}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "format",
      "Invalid date %{date}",
      date: inspect(date)
    )
  end
end
