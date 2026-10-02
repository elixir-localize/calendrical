defmodule Calendrical.Julian.Dec25 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 25 December (the
  *Nativity style* / *Christmas style*, used in parts of medieval
  Europe and the early Holy Roman Empire).

  The year begins a week before 1 January of the same number: year 1100
  runs from 25 December 1099 to 24 December 1100, so the last seven days
  of December carry the number of the year to come.

      iex> Date.convert!(~D[1099-12-25 Calendrical.Julian], Calendrical.Julian.Dec25)
      ~D[1100-12-25 Calendrical.Julian.Dec25]

      iex> Date.convert!(~D[1100-01-01 Calendrical.Julian], Calendrical.Julian.Dec25)
      ~D[1100-01-01 Calendrical.Julian.Dec25]

  This is the reckoning from Christmas Day that C. R. Cheney's *A
  Handbook of Dates* describes for the year of grace. Matthew Paris
  used it, and so gives 26 December 1250 for a birth on 26 December
  1249:

      iex> Date.convert!(~D[1249-12-26 Calendrical.Julian], Calendrical.Julian.Dec25)
      ~D[1250-12-26 Calendrical.Julian.Dec25]

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {12, 25}, year: :ending
end
