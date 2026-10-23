defmodule Calendrical.NotDefinedError do
  @moduledoc """
  Exception returned when a calendar does not define what was asked of
  it: weeks in a calendar without them, a cycle of years in a calendar
  whose years do not repeat, or one count of days for a month whose days
  change from year to year.

  ### Fields

  * `:calendar` — the calendar module that was asked.

  * `:question` — what was asked, such as `:week`, `:quarter`,
    `:years_in_cycle` or `:days_in_month`.

  * `:value` — the value it was asked about, or `nil`.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:calendar, :question, :value]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{calendar: calendar, question: question, value: nil}) do
    calendar = inspect(calendar)
    question = inspect(question)
    ~t"The #{calendar} calendar does not define #{question}"
  end

  def message(%__MODULE__{calendar: calendar, question: question, value: value}) do
    calendar = inspect(calendar)
    question = inspect(question)
    value = inspect(value)
    ~t"The #{calendar} calendar does not define #{question} for #{value}"
  end
end
