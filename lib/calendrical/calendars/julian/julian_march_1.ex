defmodule Calendrical.Julian.March1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 March (the
  *Venetian style*, *more veneto*, used by the Republic of Venice).

  The year begins two months after 1 January of the same number: year
  1699 runs from 1 March 1699 to the last day of February 1700, so
  January and February carry the number of the year before. Months are
  counted from the new-year day: month 1 is March and month 12
  February.

      iex> Date.convert!(~D[1700-02-29 Calendrical.Julian], Calendrical.Julian.March1)
      ~D[1699-12-29 Calendrical.Julian.March1]

      iex> Date.convert!(~D[1700-03-01 Calendrical.Julian], Calendrical.Julian.March1)
      ~D[1700-01-01 Calendrical.Julian.March1]

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {3, 1}, year: :beginning
end
