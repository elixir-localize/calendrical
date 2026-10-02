defmodule Calendrical.IslamicYearOutOfRangeError do
  @moduledoc """
  Exception raised when an operation on the Umm al-Qura Islamic calendar
  references a Hijri year that lies outside the embedded reference data.

  ### Fields

  * `:year` — the Hijri year that was requested, or `nil` when the input
    was not a year (e.g. an out-of-range ISO day number).

  * `:min_year` — the first Hijri year covered by the embedded data.

  * `:max_year` — the last Hijri year covered by the embedded data.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:year, :min_year, :max_year]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  # The years are written as they are given: a number put to a message
  # is otherwise formatted for the locale, with a grouping separator.
  @impl true
  def message(%__MODULE__{year: year, min_year: min_year, max_year: max_year}) do
    year = inspect(year)
    min_year = inspect(min_year)
    max_year = inspect(max_year)

    ~t"Hijri year #{year} is outside the supported Umm al-Qura range #{min_year}..#{max_year}"
  end
end
