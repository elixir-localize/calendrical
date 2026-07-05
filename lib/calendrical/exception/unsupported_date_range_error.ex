defmodule Calendrical.UnsupportedDateRangeError do
  @moduledoc """
  Exception raised when a date lies outside the range a calendar
  can compute.

  Astronomical calendars depend on underlying solar or lunar
  computations that are only valid over a bounded span of years —
  the vernal equinox calculation used by the Persian calendar, or
  the ephemeris data used by the observational Islamic calendars.
  Dates outside that span raise this error rather than crashing
  inside the underlying computation.

  ### Fields

  * `:calendar` — the calendar module that could not compute the date.

  * `:value` — the out-of-range date, year, or day count as given.

  * `:range` — a description of the supported range.

  """

  defexception [:calendar, :value, :range]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{calendar: nil, value: value, range: range}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "date",
      "The date %{value} is outside the supported range of %{range}",
      range: to_string(range),
      value: inspect(value)
    )
  end

  def message(%__MODULE__{calendar: calendar, value: value, range: range}) do
    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "date",
      "The %{calendar} calendar supports dates in %{range}. Found %{value}",
      calendar: inspect(calendar),
      range: to_string(range),
      value: inspect(value)
    )
  end
end
