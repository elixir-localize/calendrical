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
     the parsing locale.

  When the parser captures a wall-clock instant alongside an
  IANA zone, the resolver uses the instant to pick between
  standard / daylight offsets (e.g. `2024-07-15 14:00 America/New_York`
  → `EDT (-04:00)`, while `2024-01-15 14:00 America/New_York`
  → `EST (-05:00)`).

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

      abbrev = Map.get(common_abbreviations(), zone_string) ->
        resolve_iana(abbrev, naive_dt)

      true ->
        case resolve_locale_name(zone_string, naive_dt, options) do
          {:ok, _} = ok -> ok
          _ -> {:error, :unresolvable_zone}
        end
    end
  end

  @doc """
  Returns the configured time-zone database module, or `nil`
  when neither `Tzdata` nor `Tz` is loaded.

  Consumers that want IANA name resolution should add one of
  these to their dependency list. The resolver works without
  them but rejects IANA names.

  ### Returns

  * `Tzdata.TimeZoneDatabase` or `Tz.TimeZoneDatabase` when the
    respective library is loaded (`Tzdata` is preferred when both
    are available).

  * `nil` when neither library is loaded.

  ### Examples

      iex> Calendrical.TimeZone.tz_database()
      Tzdata.TimeZoneDatabase

  """
  @spec tz_database() :: module() | nil
  def tz_database do
    cond do
      Code.ensure_loaded?(Tzdata.TimeZoneDatabase) -> Tzdata.TimeZoneDatabase
      Code.ensure_loaded?(Tz.TimeZoneDatabase) -> Tz.TimeZoneDatabase
      true -> nil
    end
  end

  # ── ISO offsets ──────────────────────────────────────────────

  defp iso_offset?("Z"), do: true

  defp iso_offset?(<<sign, _::binary>>) when sign in [?+, ?-], do: true
  defp iso_offset?(_), do: false

  defp resolve_iso_offset("Z", naive_dt), do: build_dt(naive_dt, 0, "UTC", "UTC")

  defp resolve_iso_offset(<<sign, rest::binary>>, naive_dt) when sign in [?+, ?-] do
    multiplier = if sign == ?+, do: 1, else: -1

    case parse_offset_digits(rest) do
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

  defp parse_offset_digits(rest) do
    rest
    |> String.replace(":", "")
    |> case do
      <<h::binary-size(2), m::binary-size(2), s::binary-size(2)>> ->
        with {hh, ""} when hh <= 14 <- Integer.parse(h),
             {mm, ""} when mm < 60 <- Integer.parse(m),
             {ss, ""} when ss < 60 <- Integer.parse(s) do
          {:ok, hh * 3600 + mm * 60 + ss}
        else
          _ -> :error
        end

      <<h::binary-size(2), m::binary-size(2)>> ->
        with {hh, ""} when hh <= 14 <- Integer.parse(h),
             {mm, ""} when mm < 60 <- Integer.parse(m) do
          {:ok, hh * 3600 + mm * 60}
        else
          _ -> :error
        end

      <<h::binary-size(2)>> ->
        case Integer.parse(h) do
          {hh, ""} when hh <= 14 -> {:ok, hh * 3600}
          _ -> :error
        end

      _ ->
        :error
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
    if zone in ["GMT", "UTC", "UT"] do
      build_dt(naive_dt, 0, "Etc/UTC", "UTC")
    else
      offset_part =
        zone
        |> String.replace_prefix("GMT", "")
        |> String.replace_prefix("UTC", "")
        |> String.replace_prefix("UT", "")

      case resolve_iso_offset(offset_part, naive_dt) do
        {:ok, _} = ok -> ok
        _ -> {:error, :invalid_gmt_offset}
      end
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
  # different defaults should pass an IANA name instead.
  defp common_abbreviations do
    %{
      # North America
      "EST" => "America/New_York",
      "EDT" => "America/New_York",
      "CST" => "America/Chicago",
      "CDT" => "America/Chicago",
      "MST" => "America/Denver",
      "MDT" => "America/Denver",
      "PST" => "America/Los_Angeles",
      "PDT" => "America/Los_Angeles",
      "AKST" => "America/Anchorage",
      "AKDT" => "America/Anchorage",
      "HST" => "Pacific/Honolulu",
      # Europe
      "GMT" => "Etc/UTC",
      "BST" => "Europe/London",
      "WET" => "Europe/Lisbon",
      "WEST" => "Europe/Lisbon",
      "CET" => "Europe/Berlin",
      "CEST" => "Europe/Berlin",
      "EET" => "Europe/Athens",
      "EEST" => "Europe/Athens",
      # Asia / Pacific
      "JST" => "Asia/Tokyo",
      "KST" => "Asia/Seoul",
      "HKT" => "Asia/Hong_Kong",
      "SGT" => "Asia/Singapore",
      "IST" => "Asia/Kolkata",
      "AEST" => "Australia/Sydney",
      "AEDT" => "Australia/Sydney",
      "AWST" => "Australia/Perth",
      "NZST" => "Pacific/Auckland",
      "NZDT" => "Pacific/Auckland"
    }
  end

  # IANA zone ids are case-sensitive, but CLDR locale data keys
  # them lowercased and users type freely. Map case-insensitively
  # onto the canonical zone list (cached in persistent_term).
  defp canonical_iana_zone(zone) do
    Map.get(canonical_zone_map(), String.downcase(zone), zone)
  end

  defp canonical_zone_map do
    key = {__MODULE__, :canonical_zones}

    case :persistent_term.get(key, :__not_loaded__) do
      :__not_loaded__ ->
        value =
          if Code.ensure_loaded?(Tzdata) do
            Map.new(Tzdata.zone_list(), fn zone -> {String.downcase(zone), zone} end)
          else
            %{}
          end

        :persistent_term.put(key, value)
        value

      value ->
        value
    end
  end

  # ── CLDR locale-name zones ─────────────────────────────────

  defp resolve_locale_name(zone_string, naive_dt, options) do
    locale = Keyword.get(options, :locale) || safe_get_locale()
    iana = lookup_cldr_zone_name(zone_string, locale)

    case iana do
      nil -> {:error, :no_cldr_match}
      iana_name -> resolve_iana(iana_name, naive_dt)
    end
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

  defp find_zone_id(zone_map, target) do
    # zone_map looks like %{"America" => %{"New_York" => %{long: %{generic: "Eastern Time", ...}}, ...}, ...}
    Enum.find_value(zone_map, fn {region, cities_or_data} ->
      find_in_branch(cities_or_data, target, region)
    end)
  end

  defp find_in_branch(%{} = sub, target, prefix) when is_map(sub) do
    if match?(%{long: _}, sub) and name_matches?(sub, target) do
      prefix
    else
      Enum.find_value(sub, fn {key, value} ->
        next_prefix = "#{prefix}/#{key}"

        cond do
          match?(%{long: _}, value) and name_matches?(value, target) -> next_prefix
          is_map(value) -> find_in_branch(value, target, next_prefix)
          true -> nil
        end
      end)
    end
  end

  defp find_in_branch(_, _, _), do: nil

  defp name_matches?(data, target) do
    Enum.any?(
      Map.values(Map.get(data, :long, %{})) ++ Map.values(Map.get(data, :short, %{})),
      &(&1 == target)
    )
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
