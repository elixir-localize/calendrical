defmodule Calendrical.Julian.Dec25 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 25 December (the
  *Nativity style* / *Christmas style*, used in parts of medieval
  Europe and the early Holy Roman Empire).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {12, 25}
end
