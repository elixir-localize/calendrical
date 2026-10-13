defmodule Calendrical.InvalidMonthError do
  @moduledoc """
  Exception returned when a month is one a calendar, or a year of it,
  does not have.

  ### Fields

  * `:calendar` — the calendar module that was asked.

  * `:year` — the year that was asked for the month, or `nil` when the
    question had no year.

  * `:month` — the month as it was given: an ordinal month, or a
    traditional month such as `{2, :leap}`.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:calendar, :year, :month]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  # The year and the month are written as they are given: a number put to
  # a message is otherwise formatted for the locale, with a grouping
  # separator.
  @impl true
  def message(%__MODULE__{calendar: calendar, year: nil, month: month}) do
    calendar = inspect(calendar)
    month = inspect(month)

    ~t"The #{calendar} calendar has no month #{month}"
  end

  def message(%__MODULE__{calendar: calendar, year: year, month: month}) do
    calendar = inspect(calendar)
    year = inspect(year)
    month = inspect(month)

    ~t"The #{calendar} calendar has no month #{month} in the year #{year}"
  end
end
