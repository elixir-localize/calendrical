require Calendrical.Compiler.Month

defmodule Calendrical.Fiscal.UK do
  use Calendrical.Base.Month,
    first_or_last: :first,
    month_of_year: 4,
    year: :majority
end
