# A week that starts on day one of the year
defmodule Calendrical.BasicWeek do
  use Calendrical.Calendar.Shifted, weeks: :from_first_day
end
