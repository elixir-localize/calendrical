defmodule Calendrical.NRF do
  @moduledoc """
  Implements the US National Retail Federation
  (NRF) calendar.

  The NRF calendar is defined to end on the
  last Saturday of January.

  This week-based approach allows for easier
  comparison of seasonal business performance
  with most US seasonal holidays falling into
  the same week of the year.

  """
  use Calendrical.Calendar.Weeks, year_ends: {:saturday, :nearest, {1, 31}}
end
