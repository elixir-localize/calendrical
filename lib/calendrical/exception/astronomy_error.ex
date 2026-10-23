defmodule Calendrical.AstronomyError do
  @moduledoc """
  Exception returned when an astronomical calculation behind a calendar
  cannot be made for a reason other than the dates it covers, which
  `Calendrical.UnsupportedDateRangeError` describes.

  ### Fields

  * `:calendar` — the calendar or module whose calculation it was.

  * `:value` — the year or date the calculation was made for.

  * `:reason` — the reason `Astro` gave, such as `:no_time`.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "date"]

  defexception [:calendar, :value, :reason]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{calendar: calendar, value: value, reason: reason}) do
    calendar = inspect(calendar)
    value = inspect(value)
    reason = inspect(reason)

    ~t"#{calendar} cannot make its astronomical calculation for #{value}. Astro answered #{reason}"
  end
end
