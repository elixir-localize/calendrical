defmodule Calendrical.DayStart do
  @moduledoc false

  # Shared "instant -> calendar date under a chosen day-start convention" logic
  # for calendars whose day begins at (or after) sunset observed from a
  # reference location: the Islamic calendars at Mecca/Cairo and the Hebrew
  # calendar at the observer's location (default Jerusalem). The public contract
  # is documented on each calendar's `date_at/2`.
  #
  # The caller resolves and passes the reference `location` and its
  # `utc_offset_seconds`; the offset fixes the 18:00 evening proxy and the civil
  # day whose boundary delimits the calendar day. `:sunset` is upper-limb
  # Maghrib and `:nightfall` is a solar-depression dusk, both computed via
  # `Astro` as real instants at the location (independent of daylight saving).

  @evening_day_start ~T[18:00:00]
  @default_nightfall_angle 8.5
  @valid_day_starts [:midnight, :evening, :sunset, :nightfall]

  @spec date_at(
          DateTime.t(),
          module(),
          Geo.PointZ.t() | Geo.Point.t(),
          integer(),
          Keyword.t()
        ) :: {:ok, Date.t()} | {:error, Exception.t()}
  def date_at(%DateTime{} = datetime, calendar, location, utc_offset_seconds, options) do
    day_start = Keyword.get(options, :day_start, :midnight)
    {reference_date, reference_time, instant} = reference_wall_clock(datetime, utc_offset_seconds)
    dusk = %{calendar: calendar, location: location, date: reference_date, instant: instant}

    with :ok <- validate_day_start(day_start),
         {:ok, roll} <- day_roll(day_start, dusk, reference_time, options) do
      reference_date
      |> Date.add(roll)
      |> to_calendar(calendar)
    end
  end

  defp validate_day_start(day_start) when day_start in @valid_day_starts, do: :ok

  defp validate_day_start(other),
    do: {:error, Calendrical.InvalidOptionValueError.exception(option: :day_start, value: other)}

  # The instant in the reference location's standard-time wall clock: its
  # Gregorian date, its time of day, and the original instant for absolute
  # comparisons.
  defp reference_wall_clock(%DateTime{} = datetime, utc_offset_seconds) do
    unix = DateTime.to_unix(datetime, :second)
    local = DateTime.from_unix!(unix + utc_offset_seconds)
    {DateTime.to_date(local), DateTime.to_time(local), datetime}
  end

  defp day_roll(:midnight, _dusk, _time, _options), do: {:ok, 0}

  defp day_roll(:evening, _dusk, reference_time, _options) do
    rolled(Time.compare(reference_time, @evening_day_start) in [:eq, :gt])
  end

  # `:geometric` (Astro's default) is upper-limb sunset — h0 = -50' — i.e. Maghrib.
  defp day_roll(:sunset, dusk, _time, _options) do
    dusk_roll(:sunset, dusk, [])
  end

  defp day_roll(:nightfall, dusk, _time, options) do
    case Keyword.get(options, :nightfall_angle, @default_nightfall_angle) do
      angle when is_number(angle) ->
        # solar_elevation N maps to a sun altitude of -(N - 90), so a dusk at
        # `angle` degrees below the horizon is solar_elevation 90 + angle.
        dusk_roll(:nightfall, dusk, solar_elevation: 90.0 + angle)

      other ->
        {:error,
         Calendrical.InvalidOptionValueError.exception(option: :nightfall_angle, value: other)}
    end
  end

  # Astro answers `:not_found` for a date outside the installed ephemeris
  # and `:no_time` where the sun does not reach the altitude that day.
  defp dusk_roll(day_start, dusk, astro_options) do
    case Astro.sunset(dusk.location, dusk.date, [{:time_zone, :utc} | astro_options]) do
      {:ok, moment} ->
        rolled(DateTime.compare(dusk.instant, moment) in [:eq, :gt])

      {:error, :not_found} ->
        {:error,
         Calendrical.UnsupportedDateRangeError.exception(
           calendar: dusk.calendar,
           value: dusk.date,
           range: :jpl_ephemeris
         )}

      {:error, _no_dusk} ->
        {:error,
         Calendrical.NoDuskError.exception(
           day_start: day_start,
           location: dusk.location,
           date: dusk.date
         )}
    end
  end

  defp rolled(true), do: {:ok, 1}
  defp rolled(false), do: {:ok, 0}

  # A date outside the range raises from deep in the calculation, about the
  # day the calculation reached; the error names the calendar and the date
  # that was being converted instead.
  defp to_calendar(%Date{} = gregorian_date, calendar) do
    Calendrical.convert_date(gregorian_date, calendar)
  rescue
    error in Calendrical.UnsupportedDateRangeError ->
      {:error, %{error | calendar: calendar, value: gregorian_date}}

    error in Calendrical.IslamicYearOutOfRangeError ->
      {:error, error}
  end
end
