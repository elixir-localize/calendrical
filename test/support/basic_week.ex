require Calendrical.Compiler.Month

# A week that starts on day one of the year
defmodule Calendrical.BasicWeek do
  use Calendrical.Base.Month, day_of_week: :first
end
