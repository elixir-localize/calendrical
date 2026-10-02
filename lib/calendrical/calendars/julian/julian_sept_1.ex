defmodule Calendrical.Julian.Sept1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 September (the
  *Byzantine* year, used by the Byzantine Empire and in the Eastern
  Orthodox liturgical year).

  The year begins four months before 1 January of the same number: year
  1700 runs from 1 September 1699 to 31 August 1700, so September to
  December carry the number of the year to come.

      iex> Date.convert!(~D[1699-09-01 Calendrical.Julian], Calendrical.Julian.Sept1)
      ~D[1700-09-01 Calendrical.Julian.Sept1]

      iex> Date.convert!(~D[1700-08-31 Calendrical.Julian], Calendrical.Julian.Sept1)
      ~D[1700-08-31 Calendrical.Julian.Sept1]

  A Byzantine year of the world is 5509 more than the Julian year from
  September to December and 5508 more from January to August, which is
  5508 more than the year here throughout: the year of the world 7208
  began on 1 September 1699, the first day of 1700 above.

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {9, 1}, year: :ending
end
