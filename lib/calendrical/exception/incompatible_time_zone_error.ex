defmodule Calendrical.IncompatibleTimeZoneError do
  @moduledoc """
  Exception raised when two datetimes that should be in the same
  time zone are not.

  ### Fields

  * `:from` — the first datetime (or its time zone).
  * `:to` — the second datetime (or its time zone).

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
      "The two values must be in the same time zone. Found %{from} and %{to}",
      from: inspect(from),
      to: inspect(to)
    )
  end
end
