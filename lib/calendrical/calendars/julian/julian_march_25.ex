defmodule Calendrical.Julian.March25 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 25 March (the
  *Annunciation style* / *Lady Day*, used in England before 1752
  and in Florence during the Middle Ages).

  The year begins nearly three months after 1 January of the same
  number: year 1750 runs from 25 March 1750 to 24 March 1751, so
  January to 24 March carry the number of the year before. Months are
  counted from the new-year day: month 1 is 25-31 March, day 1 being
  25 March, and month 13 is 1-24 March of the Julian year after.

      iex> Date.convert!(~D[1751-03-24 Calendrical.Julian], Calendrical.Julian.March25)
      ~D[1750-13-24 Calendrical.Julian.March25]

      iex> Date.convert!(~D[1751-03-25 Calendrical.Julian], Calendrical.Julian.March25)
      ~D[1751-01-01 Calendrical.Julian.March25]

  Pisa began its year on the 25 March before, a year ahead of Florence.
  That reckoning is `use Calendrical.Julian,
  new_year_starting_month_and_day: {3, 25}, year: :ending`.

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {3, 25}, year: :beginning
end
