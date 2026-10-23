defmodule Calendrical.Persian.DateGenerator do
  require ExUnitProperties

  # The Persian years whose new year is computed from the equinox and
  # true noon in Tehran, within the ephemeris Astro bundles.
  def generate_date do
    ExUnitProperties.gen all(
                           year <- StreamData.integer(1279..1479),
                           month <- StreamData.integer(1..12),
                           day <-
                             StreamData.integer(1..Calendrical.Persian.days_in_month(year, month))
                         ) do
      {:ok, date} = Date.new(year, month, day, Calendrical.Persian)
      date
    end
  end
end
