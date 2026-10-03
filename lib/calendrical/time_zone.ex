defmodule Calendrical.TimeZone do
  @moduledoc """
  Resolves a time zone as a locale writes it, with the date and time
  written with it, to a `t:DateTime.t/0`.

  `resolve/3` is Localize's `Localize.DateTime.Timezone.resolve/3`, which
  reads every form a locale writes a zone in: ISO 8601 and localized GMT
  offsets (`+05:30`, `GMT+2`, `UTC−4`), IANA names (`Asia/Tokyo`), and
  CLDR's names and abbreviations of zones and metazones (`Pacific Time`,
  `EST`, `Mitteleuropäische Zeit`). A zone's offset on the date comes from
  the time zone database the application configures.

  A name of standard or daylight time keeps its own offset, as ICU reads
  it: `2024-07-15 14:00 EST` is 14:00 at `-05:00`, since New York keeps
  daylight time in July. Any other form follows the zone's clock, and a
  wall time its clocks pass twice is read in standard time, one they skip
  at the offset before the change, as ICU reads them.

  """

  @doc """
  Resolves a time zone as a locale writes it, at a date and time, to the
  `t:DateTime.t/0` it names, as `Localize.DateTime.Timezone.resolve/3`
  does.

  ### Arguments

  * `zone_string` is the zone as written (`"PST"`, `"+0530"`,
    `"Asia/Tokyo"`, `"Pacific Time"`).

  * `naive_datetime` is the date and time written with it, a
    `t:NaiveDateTime.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` is the locale whose names are read. The default is
    `Localize.get_locale/0`.

  ### Returns

  * `{:ok, datetime}`, or

  * `{:error, exception}` when the string is not a zone the locale
    writes, or names a time zone the configured database does not
    resolve.

  ### Examples

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Asia/Tokyo", ~N[2024-07-15 14:00:00])
      iex> {datetime.zone_abbr, datetime.utc_offset}
      {"JST", 32400}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Pacific Time", ~N[2024-07-15 14:00:00])
      iex> {datetime.time_zone, datetime.zone_abbr}
      {"America/Los_Angeles", "PDT"}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("EST", ~N[2024-07-15 14:00:00])
      iex> {DateTime.to_naive(datetime), datetime.utc_offset + datetime.std_offset}
      {~N[2024-07-15 14:00:00], -18000}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Mitteleuropäische Zeit", ~N[2024-07-15 14:00:00], locale: :de)
      iex> datetime.time_zone
      "Europe/Berlin"

      iex> {:error, %Localize.UnknownTimezoneError{}} =
      ...>   Calendrical.TimeZone.resolve("Middle Earth Time", ~N[2024-07-15 14:00:00])

  """
  @spec resolve(String.t(), NaiveDateTime.t(), Keyword.t()) ::
          {:ok, DateTime.t()} | {:error, Exception.t()}
  defdelegate resolve(zone_string, naive_datetime, options \\ []),
    to: Localize.DateTime.Timezone

  @doc """
  Returns the time-zone database module, or `nil` when none is
  configured and no known implementation is loaded.

  The database resolves, in order, from:

  1. The `:elixir` `:time_zone_database` application environment
     (`config :elixir, :time_zone_database, Tz.TimeZoneDatabase`) —
     Elixir's own UTC-only default is treated as "not configured".

  2. Tz.TimeZoneDatabase or `Tzdata.TimeZoneDatabase` when the
     respective library is loaded (Tz is preferred when both are
     available).

  Consumers that want IANA name resolution should add a
  `Calendar.TimeZoneDatabase` implementation to their dependency
  list and configure it. The resolver works without one but
  rejects IANA names.

  ### Returns

  * A module implementing `Calendar.TimeZoneDatabase`, or

  * `nil` when nothing is configured and neither known library
    is loaded.

  ### Examples

      iex> Calendrical.TimeZone.tz_database()
      Tz.TimeZoneDatabase

  """
  @spec tz_database() :: module() | nil
  def tz_database do
    configured_time_zone_database() ||
      cond do
        Code.ensure_loaded?(Tz.TimeZoneDatabase) -> Tz.TimeZoneDatabase
        Code.ensure_loaded?(Tzdata.TimeZoneDatabase) -> Tzdata.TimeZoneDatabase
        true -> nil
      end
  end

  defp configured_time_zone_database do
    case Application.get_env(:elixir, :time_zone_database) do
      nil -> nil
      Calendar.UTCOnlyTimeZoneDatabase -> nil
      module -> module
    end
  end
end
