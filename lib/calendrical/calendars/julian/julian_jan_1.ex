defmodule Calendrical.Julian.Jan1 do
  @moduledoc """
  Proleptic Julian calendar whose year begins on 1 January
  (the modern "Circumcision style", widely adopted after 1582).

  See `Calendrical.Julian` for the calendar's structure, leap-year
  rule and the full public API.

  """

  use Calendrical.Calendar.Shifted,
    base: Calendrical.Julian,
    year_begins: {1, 1},
    written_year: :label
end
