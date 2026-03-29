require Calendrical.Compiler.Week

defmodule Calendrical.ISOWeek do
  @moduledoc """
  Implements the ISO Week calendar.

  The ISO Week calendar manages dates
  in a `yyyy-ww-dd` format with each year
  having either 52 or 53 weeks.

  """
  use Calendrical.Base.Week,
    day_of_week: 1,
    min_days_in_first_week: 4
end
