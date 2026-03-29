defmodule Calendrical.Coptic.DateGenerator do
  require ExUnitProperties

  def generate_date do
    ExUnitProperties.gen all(
                           year <- StreamData.integer(0001..3000),
                           month <- StreamData.integer(1..13),
                           day <-
                             StreamData.integer(1..Calendrical.Coptic.days_in_month(year, month))
                         ) do
      {:ok, date} = Date.new(year, month, day, Calendrical.Coptic)
      date
    end
  end
end
