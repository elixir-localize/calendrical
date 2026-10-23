defmodule Calendrical.NRF do
  @moduledoc """
  Implements the US National Retail Federation
  (NRF) calendar.

  The NRF calendar year ends on the Saturday nearest 31 January, so it
  ends in the first days of February in some years, and begins on the
  Sunday after. Its months follow the 4-5-4 pattern of weeks and are
  named from February, the month the year begins in.

  This week-based approach allows for easier
  comparison of seasonal business performance
  with most US seasonal holidays falling into
  the same week of the year.

  """
  use Calendrical.Calendar.Weeks, year_ends: {:saturday, :nearest, {1, 31}}
end
