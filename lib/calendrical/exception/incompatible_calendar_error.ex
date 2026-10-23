defmodule Calendrical.IncompatibleCalendarError do
  @moduledoc """
  Exception raised when an operation is attempted between two
  dates or datetimes that use incompatible calendars.

  ### Fields

  * `:from` — the first calendar (or value carrying it).

  * `:to` — the second calendar (or value carrying it).

  * `:reason` — `:day_rollover` where a date cannot be converted from one
    calendar to the other because their days begin at different times, as
    `Date.convert/2` answers, or `nil` where the two must be the same.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:from, :to, :reason]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{from: from, to: to, reason: :day_rollover}) do
    from = inspect(from)
    to = inspect(to)

    ~t"A date cannot be converted from #{from} to #{to}: their days begin at different times"
  end

  def message(%__MODULE__{from: from, to: to}) do
    from = inspect(from)
    to = inspect(to)

    ~t"The two values must be in the same calendar. Found #{from} and #{to}"
  end
end
