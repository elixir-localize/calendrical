defmodule Calendrical.InvalidDateError do
  @moduledoc """
  Exception returned when a value is not a date of a calendar: a day the
  month does not have, a month the year does not have, a week the year
  does not have, or a field that is not an integer.

  ### Fields

  * `:calendar` — the calendar module that was asked, or `nil` when no
    calendar was given.

  * `:value` — what was asked for: a `{year, month, day}` for a date, or a
    keyword list naming the fields of anything else, such as `[year: 0]`,
    `[year: 2026, quarter: 5]` or `[year: 2026, week: 54]`.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "date"]

  defexception [:calendar, :value]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{calendar: nil, value: value}) do
    value = inspect(value)
    ~t"#{value} is not a date"
  end

  def message(%__MODULE__{calendar: calendar, value: value}) do
    calendar = inspect(calendar)
    value = inspect(value)
    ~t"#{value} is not a date of the #{calendar} calendar"
  end
end
