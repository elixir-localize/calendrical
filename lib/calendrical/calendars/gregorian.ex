require Calendrical.Compiler.Month

defmodule Calendrical.Gregorian do
  @moduledoc """
  Implements the proleptic Gregorian calendar.

  Intended to be plug-compatible with `Calendar.ISO`
  with additional functions to support localisation,
  date ranges for `year`, `quarter`, `month` and `week`.

  When calling `Calendrical.localize/3` on a
  `Calendar.ISO`-based date, those dates are first
  moved to this calendar acting as a localisation
  proxy.

  """

  use Calendrical.Base.Month,
    month_of_year: 1,
    min_days_in_first_week: 1,
    day_of_week: Calendrical.monday()
end
