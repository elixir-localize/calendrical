defmodule Calendrical.Base.Astro do
  @moduledoc false

  # `Astro` answers an error with an atom. A calendar answers with an
  # exception, so each `Astro` result a calendar returns is read here.

  # The years `Astro.equinox/3` calculates.
  @equinox_years 1000..3000

  # An `Astro` result, its error as the exception that says it for the
  # calendar and the year or date the calculation was for.
  def result({:ok, value}, _calendar, _asked), do: {:ok, value}
  def result({:error, reason}, calendar, asked), do: {:error, error(reason, calendar, asked)}

  defp error(:not_found, calendar, asked) do
    Calendrical.UnsupportedDateRangeError.exception(
      calendar: calendar,
      value: asked,
      range: :jpl_ephemeris
    )
  end

  defp error(:year_out_of_range, calendar, asked) do
    Calendrical.UnsupportedDateRangeError.exception(
      calendar: calendar,
      value: asked,
      range: @equinox_years
    )
  end

  defp error(reason, calendar, asked) do
    Calendrical.AstronomyError.exception(calendar: calendar, value: asked, reason: reason)
  end
end
