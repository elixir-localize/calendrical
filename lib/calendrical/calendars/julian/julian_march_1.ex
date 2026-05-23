defmodule Calendrical.Julian.March1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 March (the
  *Mos Bonnensis*, used in parts of medieval Europe).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {3, 1}
end
