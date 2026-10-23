defmodule Calendrical.InvalidCompositeError do
  @moduledoc """
  Exception returned, or raised by `use Calendrical.Composite`, for a
  configuration a composite calendar cannot keep.

  ### Fields

  * `:reason` — what makes no composite calendar: `:no_calendars_configured`,
    `:must_be_a_list_of_dates`, `:invalid_date`,
    `:must_not_be_composite_calendars`, `:must_not_be_week_calendars`,
    `:must_take_effect_on_different_days` or `:years_must_not_go_back`.

  * `:value` — the date or calendar that is the reason, or `nil`.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:reason, :value]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{reason: :no_calendars_configured}) do
    ~t"A composite calendar needs :calendars, the first day of each calendar that takes effect"
  end

  def message(%__MODULE__{reason: :must_be_a_list_of_dates, value: value}) do
    value = inspect(value)
    ~t":calendars must be dates, each in the calendar that takes effect on it. Found #{value}"
  end

  def message(%__MODULE__{reason: :invalid_date, value: value}) do
    value = inspect(value)
    ~t"Each of :calendars must be a date of its own calendar. Found #{value}"
  end

  def message(%__MODULE__{reason: :must_not_be_composite_calendars, value: value}) do
    value = inspect(value)
    ~t"The calendars of a composite calendar must not be composite calendars. Found #{value}"
  end

  def message(%__MODULE__{reason: :must_not_be_week_calendars, value: value}) do
    value = inspect(value)
    ~t"The calendars of a composite calendar must not be calendars of weeks. Found #{value}"
  end

  def message(%__MODULE__{reason: :must_take_effect_on_different_days, value: value}) do
    value = inspect(value)
    ~t"Each of :calendars must take effect on a day of its own. Found #{value}"
  end

  def message(%__MODULE__{reason: :years_must_not_go_back, value: value}) do
    value = inspect(value)

    ~t"A calendar must not number its first year before the last year of the calendar before it. Found #{value}"
  end

  def message(%__MODULE__{reason: reason, value: value}) do
    reason = inspect(reason)
    value = inspect(value)
    ~t"The composite calendar cannot be made: #{reason}. Found #{value}"
  end
end
