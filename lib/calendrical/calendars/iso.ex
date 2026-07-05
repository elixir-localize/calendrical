require Calendrical.Compiler.Month

defmodule Calendrical.ISO do
  @moduledoc """
  The proleptic Gregorian calendar with ISO 8601 week rules.

  Dates are identical to `Calendrical.Gregorian`; the calendars
  differ only in their week convention. ISO 8601 defines week 1
  as the first week containing at least four days of the year
  (equivalently, the week containing the first Thursday), whereas
  `Calendrical.Gregorian` — the default calendar applied to
  `Calendar.ISO` dates — starts week 1 with the week containing
  January 1. Both start weeks on Monday.

  Use this calendar with functions such as
  `Calendrical.weeks_in_year/2` and `Calendrical.week_of_year/1`
  when ISO 8601 week numbering is required. For week-numbered
  dates (`2026-W01-1`) see `Calendrical.ISOWeek`.

  """

  use Calendrical.Base.Month,
    month_of_year: 1,
    day_of_week: 1,
    min_days_in_first_week: 4,
    day_of_week: Calendrical.monday()
end
