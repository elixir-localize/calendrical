defmodule Calendrical.Julian.Jan1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 January
  (the modern "Circumcision style", widely adopted after 1582).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Julian, new_year_starting_month_and_day: {1, 1}
end
