defmodule Calendrical.Fiscal.US do
  use Calendrical.Calendar.Shifted,
    year_begins: {10, 1},
    year_number: :majority,
    weeks: [first_day: 7, min_days_in_first_week: 4]
end
