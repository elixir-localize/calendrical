defmodule Calendrical.Julian.March25 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 25 March (the
  *Annunciation style* / *Lady Day*, used in England before 1752
  and in Florence and Pisa during the Middle Ages).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {3, 25}
end
