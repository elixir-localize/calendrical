defmodule Calendrical.Chinese.DateGenerator do
  require ExUnitProperties

  @from Calendrical.date_to_iso_days(~D[1800-01-01])
  @to Calendrical.date_to_iso_days(~D[2100-12-31])

  def generate_iso_days do
    ExUnitProperties.gen all(iso_days <- StreamData.integer(@from..@to)) do
      iso_days
    end
  end
end
