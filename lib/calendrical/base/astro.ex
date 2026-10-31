defmodule Calendrical.Base.Astro do
  @moduledoc false

  # `Astro` answers an error with an atom. A calendar answers with an
  # exception, so each `Astro` result a calendar returns is read here.

  # The Gregorian years Astro's equinoxes, solstices, new moons and crescent
  # searches answer for: 50,000 years either side of 2000.
  @astro_years -48_000..52_000

  # An `Astro` result, its error as the exception that says it for the
  # calendar and the year or date the calculation was for.
  def result({:ok, value}, _calendar, _asked), do: {:ok, value}
  def result({:error, reason}, calendar, asked), do: {:error, error(reason, calendar, asked)}

  # The exception for an `Astro` error atom.
  def error(:year_out_of_range, calendar, asked) do
    Calendrical.UnsupportedDateRangeError.exception(
      calendar: calendar,
      value: asked,
      range: @astro_years
    )
  end

  def error(reason, calendar, asked) do
    Calendrical.AstronomyError.exception(calendar: calendar, value: asked, reason: reason)
  end
end
