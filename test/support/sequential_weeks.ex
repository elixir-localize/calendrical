defmodule Calendrical.SequentialWeeks do
  @moduledoc false

  # Weeks start on day 1 of the year and therefore
  # we have a partial last week of year.

  use Calendrical.Calendar.Shifted, weeks: :from_first_day
end
