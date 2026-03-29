defmodule Calendrical.Japanese.DateGenerator do
  require ExUnitProperties

  def generate_date do
    ExUnitProperties.gen all(
                           year <- StreamData.integer(0001..3000),
                           month <-
                             StreamData.integer(1..Calendrical.Japanese.months_in_year(year)),
                           day <-
                             StreamData.integer(
                               1..Calendrical.Japanese.days_in_month(year, month)
                             )
                         ) do
      case Date.new(year, month, day, Calendrical.Japanese) do
        {:ok, date} -> date
        _other -> raise inspect({year, month, day})
      end
    end
  end
end
