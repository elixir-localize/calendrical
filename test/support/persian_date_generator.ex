defmodule Calendrical.Persian.DateGenerator do
  require ExUnitProperties

  # Persian years from 600 to 2400 AD, each beginning from the equinox and
  # true noon in Tehran: from Astro's series before 1900 and after 2100, and
  # from the ephemeris it bundles between.
  def generate_date do
    ExUnitProperties.gen all(
                           year <- StreamData.integer(-21..1779),
                           month <- StreamData.integer(1..12),
                           day <-
                             StreamData.integer(1..Calendrical.Persian.days_in_month(year, month))
                         ) do
      {:ok, date} = Date.new(year, month, day, Calendrical.Persian)
      date
    end
  end
end
