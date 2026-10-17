defmodule Calendrical.Fiscal.UK do
  use Calendrical.Calendar.Shifted, year_begins: {4, 1}, year_number: :majority
end
