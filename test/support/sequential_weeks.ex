require Calendrical.Compiler.Month

defmodule Calendrical.SequentialWeeks do
  @moduledoc false

  # Weeks start on day 1 of the year and therefore
  # we have a partial last week of year.

  use Calendrical.Base.Month,
    month_of_year: 1,
    day_of_week: :first
end
