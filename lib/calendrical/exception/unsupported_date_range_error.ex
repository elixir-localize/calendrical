defmodule Calendrical.UnsupportedDateRangeError do
  @moduledoc """
  Exception raised when a date lies outside the range a calendar
  can compute.

  Astronomical calendars depend on underlying solar or lunar
  computations that are only valid over a bounded span of years,
  such as the ephemeris data used by the observational Islamic
  calendars.
  Dates outside that span raise this error rather than crashing
  inside the underlying computation.

  ### Fields

  * `:calendar` — the calendar module that could not compute the date.

  * `:value` — the out-of-range date, year, or day count as given.

  * `:range` — a description of the supported range.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "date"]

  defexception [:calendar, :value, :range]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{calendar: nil, value: value, range: range}) do
    value = inspect(value)
    range = description(range)

    ~t"The date #{value} is outside the supported range of #{range}"
  end

  def message(%__MODULE__{calendar: calendar, value: value, range: range}) do
    calendar = inspect(calendar)
    value = inspect(value)
    range = description(range)

    ~t"The #{calendar} calendar supports dates in #{range}. Found #{value}"
  end

  # The range is described in words. Whatever else an exception was built
  # with is shown as it is: a message is no place to raise.
  defp description(range) when is_binary(range), do: range
  defp description(range), do: inspect(range)
end
