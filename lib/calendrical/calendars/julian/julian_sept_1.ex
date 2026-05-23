defmodule Calendrical.Julian.Sept1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 September (the
  *Byzantine* indictional year, used by the Byzantine Empire and in
  the Eastern Orthodox liturgical year).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {9, 1}
end
