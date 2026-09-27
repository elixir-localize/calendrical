defmodule Calendrical.TimeZone do
  @moduledoc """
  Resolve textual time-zone identifiers captured by the
  parser into UTC offsets.

  The resolver tries these strategies in order:

  1. ISO 8601 offset — `Z`, `±HHMM`, `±HH:MM`, `±HH:MM:SS`.

  2. GMT/UTC format — `GMT`, `GMT+10`, `UTC-5:30`.

  3. IANA region/city — `Asia/Tokyo`, `America/New_York`.
     Looked up via the host application's installed time-zone
     database (`Tzdata` or `Tz`) — whichever is loaded at
     runtime. If neither is loaded, IANA names are rejected
     (consumer should add `:tzdata` or `:tz` as a dependency
     to support them).

  4. Short abbreviation — `PST`, `EST`, `JST`. Resolved via a
     small static table for the most common abbreviations.
     Note that abbreviations are inherently ambiguous (CST
     could be Central or China Standard); the table picks
     the most common North-American/Asian/European reading.

  5. CLDR locale name — `Pacific Time`, `Greenwich Mean Time`.
     Looked up via `Localize`'s CLDR `timeZoneNames` data for
     the parsing locale. Zone-specific names are tried first,
     then metazone names (`Pacific Standard Time`,
     `Mitteleuropäische Zeit`), which cover most localized
     zone names in CLDR. A metazone resolves to its
     representative zone for the locale's territory —
     `Mitteleuropäische Zeit` under a `:de` locale is
     `Europe/Berlin` — falling back to the metazone's golden
     zone (`Europe/Paris`).

  When the parser captures a wall-clock instant alongside an
  IANA zone, the resolver uses the instant to pick between
  standard / daylight offsets (e.g. `2024-07-15 14:00 America/New_York`
  → `EDT (-04:00)`, while `2024-01-15 14:00 America/New_York`
  → `EST (-05:00)`). A generic name (`Eastern Time`) does the same.

  A name specific to standard or daylight time (`EST`,
  `Pacific Daylight Time`) keeps its own offset, as ICU parses
  it: `2024-07-15 14:00 EST` is 14:00 at `-05:00`, a fixed offset
  labelled `EST`, since New York keeps daylight time in July. On
  a date the zone keeps that time, the result is the zone's own.

  """

  @doc """
  Resolves `zone_string` against a wall-clock `NaiveDateTime`.

  ### Arguments

  * `zone_string` is the captured zone token (e.g. `"PST"`,
    `"+0530"`, `"Asia/Tokyo"`, `"Pacific Time"`).

  * `naive_dt` is the parsed wall-clock instant. Used to
    disambiguate standard vs daylight offsets for IANA
    zones (e.g. `America/New_York` is `-05:00` in January
    and `-04:00` in July).

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — locale to use when looking up CLDR-style
    names like `"Pacific Time"`. Defaults to
    `Localize.get_locale/0`.

  ### Returns

  * `{:ok, DateTime.t()}` when the zone resolves.

  * `{:error, reason}` when the zone string isn't
    recognizable.

  ### Examples

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("+05:30", ~N[2024-07-15 14:00:00])
      iex> to_string(datetime)
      "2024-07-15 14:00:00+05:30"

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("GMT+02:00", ~N[2024-01-15 09:00:00])
      iex> to_string(datetime)
      "2024-01-15 09:00:00+02:00"

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Asia/Tokyo", ~N[2024-07-15 14:00:00])
      iex> {datetime.zone_abbr, datetime.utc_offset}
      {"JST", 32400}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Pacific Time", ~N[2024-07-15 14:00:00])
      iex> {datetime.time_zone, datetime.zone_abbr}
      {"America/Los_Angeles", "PDT"}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("EST", ~N[2024-07-15 14:00:00])
      iex> {to_string(datetime), datetime.zone_abbr}
      {"2024-07-15 14:00:00-05:00", "EST"}

      iex> {:ok, datetime} = Calendrical.TimeZone.resolve("Mitteleuropäische Zeit", ~N[2024-07-15 14:00:00], locale: :de)
      iex> datetime.time_zone
      "Europe/Berlin"

      iex> Calendrical.TimeZone.resolve("Middle Earth Time", ~N[2024-07-15 14:00:00])
      {:error, :unresolvable_zone}

  """
  @spec resolve(String.t(), NaiveDateTime.t(), Keyword.t()) ::
          {:ok, DateTime.t()} | {:error, atom() | Exception.t()}
  def resolve(zone_string, %NaiveDateTime{} = naive_dt, options \\ [])
      when is_binary(zone_string) do
    cond do
      iso_offset?(zone_string) ->
        resolve_iso_offset(zone_string, naive_dt)

      gmt_format?(zone_string) ->
        resolve_gmt(zone_string, naive_dt)

      iana_name?(zone_string) ->
        resolve_iana(zone_string, naive_dt)

      named_time = Map.get(common_abbreviations(), zone_string) ->
        {zone, time_type} = named_time
        resolve_named_time(zone, time_type, zone_string, naive_dt)

      true ->
        case resolve_locale_name(zone_string, naive_dt, options) do
          {:ok, _} = ok -> ok
          _ -> {:error, :unresolvable_zone}
        end
    end
  end

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

  # Bidi controls that CLDR embeds in the `hourFormat` of `fa` and `he`,
  # and that travel with an offset pasted out of rendered text. They
  # carry no numeric meaning.
  @bidi_marks ["\u200E", "\u200F", "\u061C"]

  # ── ISO offsets ──────────────────────────────────────────────

  defp iso_offset?("Z"), do: true

  defp iso_offset?(<<sign, _::binary>>) when sign in [?+, ?-], do: true
  defp iso_offset?(_), do: false

  defp resolve_iso_offset(zone, naive_dt) do
    resolve_iso_offset(zone, naive_dt, :two_digit_hour)
  end

  defp resolve_iso_offset("Z", naive_dt, _hour_digits), do: build_dt(naive_dt, 0, "UTC", "UTC")

  defp resolve_iso_offset(<<sign, rest::binary>>, naive_dt, hour_digits)
       when sign in [?+, ?-] do
    multiplier = if sign == ?+, do: 1, else: -1

    case parse_offset_digits(rest, hour_digits) do
      {:ok, total_seconds} ->
        build_dt(
          naive_dt,
          multiplier * total_seconds,
          "Etc/UTC",
          format_offset(sign, total_seconds)
        )

      :error ->
        {:error, :invalid_offset}
    end
  end

  # Anything else carries no offset. Returning an error rather than
  # failing to match is what keeps `resolve/3` total: `resolve_gmt/2`
  # reaches here with whatever followed the GMT literal, which is
  # arbitrary caller input.
  defp resolve_iso_offset(_zone, _naive_dt, _hour_digits), do: {:error, :invalid_offset}

  # `:two_digit_hour` is ISO 8601, which writes `+05`. `:short_hour` also
  # accepts the one-digit hour of the localized GMT format — `GMT-8` is
  # what CLDR's short `gmtFormat` renders, and `cs` and `fi` write
  # `+H:mm` and `+H.mm`.
  defp parse_offset_digits(rest, hour_digits) do
    rest
    |> String.replace([":", "."], "")
    |> case do
      <<h::binary-size(2), m::binary-size(2), s::binary-size(2)>> ->
        offset_total(h, m, s)

      <<h::binary-size(2), m::binary-size(2)>> ->
        offset_total(h, m, "00")

      <<h::binary-size(1), m::binary-size(2)>> when hour_digits == :short_hour ->
        offset_total(h, m, "00")

      <<h::binary-size(2)>> ->
        offset_total(h, "00", "00")

      <<h::binary-size(1)>> when hour_digits == :short_hour ->
        offset_total(h, "00", "00")

      _ ->
        :error
    end
  end

  defp offset_total(hours, minutes, seconds) do
    with {hh, ""} when hh <= 14 <- Integer.parse(hours),
         {mm, ""} when mm < 60 <- Integer.parse(minutes),
         {ss, ""} when ss < 60 <- Integer.parse(seconds) do
      {:ok, hh * 3600 + mm * 60 + ss}
    else
      _invalid -> :error
    end
  end

  defp format_offset(sign, total_seconds) do
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    sign_char = <<sign>>
    "#{sign_char}#{pad(hours)}:#{pad(minutes)}"
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"

  # ── GMT format ──────────────────────────────────────────────

  defp gmt_format?(zone), do: String.starts_with?(zone, ["GMT", "UTC", "UT"])

  defp resolve_gmt(zone, naive_dt) do
    offset_part =
      zone
      |> String.replace_prefix("GMT", "")
      |> String.replace_prefix("UTC", "")
      |> String.replace_prefix("UT", "")
      |> String.replace(@bidi_marks, "")
      |> String.trim()

    cond do
      # A bare literal, and the `["GMT ", 0]` spelling that 14 locales
      # use, both leave nothing behind.
      offset_part == "" ->
        build_dt(naive_dt, 0, "Etc/UTC", "UTC")

      # `GMT0`, `GMT+0` and `GMT-0` are canonical spellings of UTC and
      # appear in `etc_zones/0`, but they reach here rather than the
      # IANA branch because they carry no `/`.
      zero_offset?(offset_part) ->
        build_dt(naive_dt, 0, "Etc/UTC", "UTC")

      true ->
        case resolve_iso_offset(offset_part, naive_dt, :short_hour) do
          {:ok, _} = ok -> ok
          _not_an_offset -> {:error, :invalid_gmt_offset}
        end
    end
  end

  defp zero_offset?(offset_part) do
    case String.replace(offset_part, ["+", "-", "\u2212", "\u2013", ":", "."], "") do
      "" -> false
      digits -> digits |> String.to_charlist() |> Enum.all?(&(&1 == ?0))
    end
  end

  # ── IANA names ──────────────────────────────────────────────

  defp iana_name?(zone), do: String.contains?(zone, "/")

  defp resolve_iana(zone, naive_dt) do
    case tz_database() do
      nil ->
        {:error, :no_tz_database_loaded}

      module ->
        zone = canonical_iana_zone(zone)

        case DateTime.from_naive(naive_dt, zone, module) do
          {:ok, dt} ->
            {:ok, dt}

          {:ambiguous, first, _second} ->
            # DST fall-back ambiguity — pick the earlier
            # offset (the standard convention for unmarked
            # local times in fall transitions).
            {:ok, first}

          {:gap, _just_before, just_after} ->
            # Spring-forward gap — the wall time doesn't
            # exist. Snap to just after the gap.
            {:ok, just_after}

          {:error, _} ->
            {:error, :unknown_iana_zone}
        end
    end
  end

  # ── Common abbreviations ────────────────────────────────────

  # Picks the most-common reading per abbreviation. Documented
  # ambiguities (CST = Central US vs China Standard) resolve
  # to the more commonly-typed form (US). Consumers needing
  # different defaults should pass an IANA name instead. Each
  # abbreviation names the zone's standard or its daylight time.
  defp common_abbreviations do
    %{
      # North America
      "EST" => {"America/New_York", :standard},
      "EDT" => {"America/New_York", :daylight},
      "CST" => {"America/Chicago", :standard},
      "CDT" => {"America/Chicago", :daylight},
      "MST" => {"America/Denver", :standard},
      "MDT" => {"America/Denver", :daylight},
      "PST" => {"America/Los_Angeles", :standard},
      "PDT" => {"America/Los_Angeles", :daylight},
      "AKST" => {"America/Anchorage", :standard},
      "AKDT" => {"America/Anchorage", :daylight},
      "HST" => {"Pacific/Honolulu", :standard},
      # Europe
      "GMT" => {"Etc/UTC", :standard},
      "BST" => {"Europe/London", :daylight},
      "WET" => {"Europe/Lisbon", :standard},
      "WEST" => {"Europe/Lisbon", :daylight},
      "CET" => {"Europe/Berlin", :standard},
      "CEST" => {"Europe/Berlin", :daylight},
      "EET" => {"Europe/Athens", :standard},
      "EEST" => {"Europe/Athens", :daylight},
      # Asia / Pacific
      "JST" => {"Asia/Tokyo", :standard},
      "KST" => {"Asia/Seoul", :standard},
      "HKT" => {"Asia/Hong_Kong", :standard},
      "SGT" => {"Asia/Singapore", :standard},
      "IST" => {"Asia/Kolkata", :standard},
      "AEST" => {"Australia/Sydney", :standard},
      "AEDT" => {"Australia/Sydney", :daylight},
      "AWST" => {"Australia/Perth", :standard},
      "NZST" => {"Pacific/Auckland", :standard},
      "NZDT" => {"Pacific/Auckland", :daylight}
    }
  end

  # ── Standard and daylight names ────────────────────────────

  # A name specific to standard or daylight time keeps its own
  # offset, as ICU parses it: "14:00 EST" in May is 14:00 at
  # -05:00, an hour after 14:00 EDT. The zone's own `DateTime` is
  # the answer when the zone keeps that time at the wall clock
  # given; otherwise it is a fixed offset labelled with the name.
  # A generic name ("Eastern Time") follows the zone.
  defp resolve_named_time(zone, :generic, _label, naive_dt), do: resolve_iana(zone, naive_dt)

  defp resolve_named_time(zone, time_type, label, naive_dt) do
    case tz_database() do
      nil -> {:error, :no_tz_database_loaded}
      database -> named_time(canonical_iana_zone(zone), time_type, label, naive_dt, database)
    end
  end

  defp named_time(zone, time_type, label, naive_dt, database) do
    case DateTime.from_naive(naive_dt, zone, database) do
      {:error, _reason} ->
        {:error, :unknown_iana_zone}

      from_naive ->
        {candidates, others} = zone_readings(from_naive)
        readings = candidates ++ others ++ nearby_readings(zone, naive_dt, database)
        totals = Enum.map(readings, &total_offset/1)
        offset = named_time_offset(time_type, Enum.min(totals), Enum.max(totals))

        candidates
        |> Enum.find(&(total_offset(&1) == offset))
        |> named_time_datetime(offset, label, naive_dt)
    end
  end

  defp named_time_datetime(%DateTime{} = datetime, _offset, _label, _naive_dt),
    do: {:ok, datetime}

  defp named_time_datetime(nil, offset, nil, naive_dt),
    do: build_dt(naive_dt, offset, "Etc/UTC", offset_label(offset))

  defp named_time_datetime(nil, offset, label, naive_dt),
    do: build_dt(naive_dt, offset, "Etc/UTC", label)

  defp offset_label(offset) when offset < 0, do: format_offset(?-, -offset)
  defp offset_label(offset), do: format_offset(?+, offset)

  # The zone's readings of the wall clock that could be the
  # answer — one, or both sides of a fall-back overlap — and, in a
  # spring-forward gap, which has none, the gap's two sides, whose
  # offsets are still the zone's.
  defp zone_readings({:ok, datetime}), do: {[datetime], []}
  defp zone_readings({:ambiguous, first, second}), do: {[first, second], []}
  defp zone_readings({:gap, just_before, just_after}), do: {[], [just_after, just_before]}

  # The same wall clock every three months for nine months either
  # side, which meets both the zone's standard and its daylight
  # time if it keeps both.
  defp nearby_readings(zone, naive_dt, database) do
    Enum.flat_map([-9, -6, -3, 3, 6, 9], fn months ->
      naive_dt
      |> NaiveDateTime.shift(month: months)
      |> DateTime.from_naive(zone, database)
      |> nearby_reading()
    end)
  end

  defp nearby_reading({:ok, datetime}), do: [datetime]
  defp nearby_reading({:ambiguous, first, _second}), do: [first]
  defp nearby_reading({:gap, _just_before, just_after}), do: [just_after]
  defp nearby_reading({:error, _reason}), do: []

  # Daylight time is the zone's greater offset and standard time
  # its lesser, however the time zone database divides them (it
  # may write Europe/Dublin's winter as a negative saving). A
  # daylight name for a zone keeping no daylight time is an hour
  # on its standard offset, as ICU falls back to.
  defp named_time_offset(:standard, standard, _greatest), do: standard
  defp named_time_offset(:daylight, standard, standard), do: standard + 3600
  defp named_time_offset(:daylight, _standard, daylight), do: daylight

  defp total_offset(%DateTime{utc_offset: utc_offset, std_offset: std_offset}),
    do: utc_offset + std_offset

  # IANA zone ids are case-sensitive, but CLDR locale data keys
  # them lowercased and users type freely. Map case-insensitively
  # onto the canonical zone list (cached in persistent_term). The
  # list is built from Localize's CLDR bcp47 timezone data — every
  # IANA id and alias in its canonical spelling — so it works with
  # any `Calendar.TimeZoneDatabase` implementation.
  defp canonical_iana_zone(zone) do
    Map.get(canonical_zone_map(), String.downcase(zone), zone)
  end

  # The territory-less zones. Per TR35, only LOCODE-derived short
  # codes carry an implicit region; the `gmt`, `utc`, `utce01–14`,
  # and `utcw01–12` codes are region-less by design, which is why
  # they are absent from CLDR's per-territory data. This list is the
  # exact long-alias inventory of those codes from CLDR's
  # `bcp47/timezone.xml` (guaranteed stable by TR35). `Etc/Unknown`
  # (`unk`) is deliberately excluded — it is TR35's unknown-zone
  # sentinel, not a resolvable zone.
  defp etc_zones do
    # bcp47 `gmt`: Etc/GMT Etc/GMT+0 Etc/GMT-0 Etc/GMT0 Etc/Greenwich
    #              GMT GMT+0 GMT-0 GMT0 Greenwich
    # bcp47 `utc`: Etc/UTC Etc/UCT Etc/Universal Etc/Zulu
    #              UCT UTC Universal Zulu
    gmt_and_utc = [
      "Etc/GMT",
      "Etc/GMT+0",
      "Etc/GMT-0",
      "Etc/GMT0",
      "Etc/Greenwich",
      "GMT",
      "GMT+0",
      "GMT-0",
      "GMT0",
      "Greenwich",
      "Etc/UTC",
      "Etc/UCT",
      "Etc/Universal",
      "Etc/Zulu",
      "UCT",
      "UTC",
      "Universal",
      "Zulu"
    ]

    # bcp47 `utcw01–12` (behind UTC) and `utce01–14` (ahead of UTC).
    gmt_and_utc ++
      Enum.map(1..12, &"Etc/GMT+#{&1}") ++
      Enum.map(1..14, &"Etc/GMT-#{&1}")
  end

  defp canonical_zone_map do
    key = {__MODULE__, :canonical_zones}

    case :persistent_term.get(key, :__not_loaded__) do
      :__not_loaded__ ->
        value =
          Localize.DateTime.Timezone.timezones_by_territory()
          |> Map.values()
          |> List.flatten()
          |> Enum.flat_map(& &1.aliases)
          |> Kernel.++(etc_zones())
          |> Map.new(fn zone -> {String.downcase(zone), zone} end)

        :persistent_term.put(key, value)
        value

      value ->
        value
    end
  end

  # ── CLDR locale-name zones ─────────────────────────────────

  defp resolve_locale_name(zone_string, naive_dt, options) do
    locale = Keyword.get(options, :locale) || safe_get_locale()

    named_zone =
      lookup_cldr_zone_name(zone_string, locale) ||
        lookup_cldr_metazone_name(zone_string, locale)

    case named_zone do
      nil -> {:error, :no_cldr_match}
      {iana_name, names} -> resolve_cldr_name(iana_name, names, zone_string, naive_dt)
    end
  end

  # A CLDR name is the zone's generic, standard or daylight name —
  # generic first, where a locale spells two the same. A standard or
  # daylight time the zone does not keep on the date is labelled
  # with the locale's short name for it, or else its offset.
  defp resolve_cldr_name(iana_name, names, zone_string, naive_dt) do
    time_type = name_type(names, zone_string)
    resolve_named_time(iana_name, time_type, get_in(names, [:short, time_type]), naive_dt)
  end

  defp safe_get_locale do
    Localize.get_locale()
  rescue
    _ -> :en
  end

  # CLDR `timeZoneNames` is a deeply-nested map keyed by region.
  # Rather than mirror the full traversal here, do a flat scan
  # for any entry whose `:long.generic` / `:short.generic` /
  # `:long.standard` / etc. value matches the input string,
  # returning that entry's IANA zone id.
  defp lookup_cldr_zone_name(zone_string, locale) do
    case Localize.Locale.get(locale, [:dates, :time_zone_names, :zone]) do
      {:ok, zone_map} when is_map(zone_map) ->
        find_zone_id(zone_map, zone_string)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # Most localized zone names ("Pacific Standard Time", "heure
  # normale d'Europe centrale") belong to a CLDR metazone rather
  # than an individual zone. On a name match, the metazone maps to
  # its representative IANA zone for the locale's territory —
  # "Central European Time" under a German locale resolves to
  # Europe/Berlin — falling back to the metazone's golden zone.
  defp lookup_cldr_metazone_name(zone_string, locale) do
    case Localize.Locale.get(locale, [:dates, :time_zone_names, :metazone]) do
      {:ok, metazone_map} when is_map(metazone_map) ->
        Enum.find_value(metazone_map, fn {metazone, names} ->
          if name_type(names, zone_string), do: metazone_zone(metazone, names, locale)
        end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp metazone_zone(metazone, names, locale) do
    case Localize.DateTime.Timezone.zone_for_metazone(metazone, locale_territory(locale)) do
      zone when is_binary(zone) -> {zone, names}
      _no_zone -> nil
    end
  end

  defp locale_territory(locale) do
    case Localize.Territory.territory_from_locale(locale) do
      {:ok, territory} -> territory
      _ -> :"001"
    end
  rescue
    _ -> :"001"
  end

  defp find_zone_id(zone_map, target) do
    # zone_map looks like %{"America" => %{"New_York" => %{long: %{generic: "Eastern Time", ...}}, ...}, ...}
    Enum.find_value(zone_map, fn {region, cities_or_data} ->
      find_in_branch(cities_or_data, target, region)
    end)
  end

  defp find_in_branch(%{} = sub, target, prefix) when is_map(sub) do
    if match?(%{long: _}, sub) and name_type(sub, target) do
      {prefix, sub}
    else
      Enum.find_value(sub, fn {key, value} ->
        next_prefix = "#{prefix}/#{key}"

        cond do
          match?(%{long: _}, value) and name_type(value, target) -> {next_prefix, value}
          is_map(value) -> find_in_branch(value, target, next_prefix)
          true -> nil
        end
      end)
    end
  end

  defp find_in_branch(_, _, _), do: nil

  # Which of the zone's names `target` is — `:generic`, `:standard`
  # or `:daylight`, in its long or short form — or `nil`.
  defp name_type(data, target) do
    Enum.find([:generic, :standard, :daylight], fn time_type ->
      target in [get_in(data, [:long, time_type]), get_in(data, [:short, time_type])]
    end)
  end

  # ── Common builder ──────────────────────────────────────────

  # `DateTime` stores local-time fields + offset, so we keep
  # the naive instant's wall fields and attach the offset.
  # The Elixir formatter renders `<local +offset>` which is
  # what the user typed.
  defp build_dt(naive_dt, offset_seconds, zone, abbrev) do
    {:ok,
     %DateTime{
       calendar: naive_dt.calendar,
       year: naive_dt.year,
       month: naive_dt.month,
       day: naive_dt.day,
       hour: naive_dt.hour,
       minute: naive_dt.minute,
       second: naive_dt.second,
       microsecond: naive_dt.microsecond,
       std_offset: 0,
       utc_offset: offset_seconds,
       zone_abbr: abbrev,
       time_zone: zone
     }}
  end
end
