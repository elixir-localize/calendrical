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
        ) :: {:ok, Date.t()} | {:error, term()}
  def date_at(%DateTime{} = datetime, calendar, location, utc_offset_seconds, options) do
    day_start = Keyword.get(options, :day_start, :midnight)
    {reference_date, reference_time, instant} = reference_wall_clock(datetime, utc_offset_seconds)

    with :ok <- validate_day_start(day_start),
         {:ok, roll} <-
           day_roll(day_start, location, reference_date, reference_time, instant, options) do
      reference_date
      |> Date.add(roll)
      |> to_calendar(calendar)
    end
  end

  defp validate_day_start(day_start) when day_start in @valid_day_starts, do: :ok
  defp validate_day_start(other), do: {:error, {:invalid_day_start, other}}

  # The instant in the reference location's standard-time wall clock: its
  # Gregorian date, its time of day, and the original instant for absolute
  # comparisons.
  defp reference_wall_clock(%DateTime{} = datetime, utc_offset_seconds) do
    unix = DateTime.to_unix(datetime, :second)
    local = DateTime.from_unix!(unix + utc_offset_seconds)
    {DateTime.to_date(local), DateTime.to_time(local), datetime}
  end

  defp day_roll(:midnight, _location, _date, _time, _instant, _options), do: {:ok, 0}

  defp day_roll(:evening, _location, _date, reference_time, _instant, _options) do
    rolled(Time.compare(reference_time, @evening_day_start) in [:eq, :gt])
  end

  # `:geometric` (Astro's default) is upper-limb sunset — h0 = -50' — i.e. Maghrib.
  defp day_roll(:sunset, location, reference_date, _time, instant, _options) do
    dusk_roll(location, reference_date, instant, [])
  end

  defp day_roll(:nightfall, location, reference_date, _time, instant, options) do
    case Keyword.get(options, :nightfall_angle, @default_nightfall_angle) do
      angle when is_number(angle) ->
        # solar_elevation N maps to a sun altitude of -(N - 90), so a dusk at
        # `angle` degrees below the horizon is solar_elevation 90 + angle.
        dusk_roll(location, reference_date, instant, solar_elevation: 90.0 + angle)

      other ->
        {:error, {:invalid_nightfall_angle, other}}
    end
  end

  defp dusk_roll(location, reference_date, instant, astro_options) do
    case Astro.sunset(location, reference_date, [{:time_zone, :utc} | astro_options]) do
      {:ok, dusk} ->
        rolled(DateTime.compare(instant, dusk) in [:eq, :gt])

      {:error, _reason} ->
        {:error, :no_sunset}
    end
  end

  defp rolled(true), do: {:ok, 1}
  defp rolled(false), do: {:ok, 0}

  defp to_calendar(%Date{} = gregorian_date, calendar) do
    Date.convert(gregorian_date, calendar)
  rescue
    error in [Calendrical.IslamicYearOutOfRangeError, Calendrical.UnsupportedDateRangeError] ->
      {:error, error}
  end
end
