defmodule Calendrical.InvalidDateOrderError do
  @moduledoc """
  Exception raised when two dates or times are not ordered from
  earlier to later as required by the function being called.

  ### Fields

  * `:from` — the earlier value (as supplied).
  * `:to` — the later value (as supplied).

  """

  defexception [:from, :to]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{from: from, to: to}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "date",
      "The values must be ordered from earlier to later. Found %{from} and %{to}",
      from: inspect(from),
      to: inspect(to)
    )
  end
end
