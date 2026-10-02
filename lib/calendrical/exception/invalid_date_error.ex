defmodule Calendrical.Formatter.InvalidDateError do
  @moduledoc """
  Exception raised when a value supplied to a calendar formatter
  is not a recognised date.

  ### Fields

  * `:date` — the value that was supplied as a date.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "format"]

  defexception [:date]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{date: date}) do
    date = inspect(date)

    ~t"Invalid date #{date}"
  end
end
