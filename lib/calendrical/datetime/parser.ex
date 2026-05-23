defmodule Calendrical.DateTime.Parser do
  @moduledoc """
  Locale-aware parser for user-typed date-time strings.

  Public entry point: `Calendrical.DateTime.parse/2`.

  Strategy:

  1. Try bare ISO-8601 (`YYYY-MM-DDTHH:MM:SS[.frac][Z|±HH:MM]`).
     This is the wire format and always works.

  2. Otherwise, consult the locale's CLDR date-time glue
     pattern (`{1}, {0}` in `en`, `{1} {0}` in `ja`, etc.),
     split the input on the literal glue separator, and
     delegate to `Calendrical.Date.parse/2` and
     `Calendrical.Time.parse/2` for the two halves.

  Implements the parts of [TR35 §Parsing Dates
  Times](https://unicode.org/reports/tr35/tr35-dates.html#Parsing_Dates_Times)
  that apply to date+time input. Time-zone resolution is
  documented as a follow-up — when the input carries a `Z` or
  `±HH:MM` suffix that ISO-8601 already accepts, we honour it;
  named timezone suffixes (`EST`, `Asia/Tokyo`, etc.) need
  per-zone IANA-database integration which lives outside this
  parser.

  ### Returns

  * `{:ok, NaiveDateTime.t()}` when no zone info was present.
  * `{:ok, DateTime.t()}` when the input carried an offset or
    `Z` and `Calendar.DateTime.from_iso8601/1` could resolve
    it.
  * `{:error, Calendrical.DateTimeParseError.t()}` on failure.

  """

  alias Localize.DateTime.Format
  alias Calendrical.DateTimeParseError

  @standard_formats [:short, :medium, :long, :full]

  @doc """
  Parses `input` as a locale-formatted datetime string.

  See `Calendrical.DateTime.parse/2` for the public contract.
  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, NaiveDateTime.t() | DateTime.t() | map()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    as = Keyword.get(options, :as, :struct)
    input = String.trim(input)

    case try_iso(input) do
      {:ok, value} ->
        {:ok, finalise_datetime(value, as)}

      :error ->
        try_locale_glue(input, locale, options, as)
    end
  end

  # ISO 8601 always yields full year+month+day+hour+minute+second.
  # The map merges the date and time fields and surfaces the
  # `:time_zone` string when the input carried a `Z` or offset.
  defp finalise_datetime(%NaiveDateTime{} = ndt, :struct), do: ndt
  defp finalise_datetime(%DateTime{} = dt, :struct), do: dt

  defp finalise_datetime(%NaiveDateTime{} = ndt, :map) do
    naive_datetime_to_map(ndt)
  end

  defp finalise_datetime(%DateTime{} = dt, :map) do
    dt
    |> DateTime.to_naive()
    |> naive_datetime_to_map()
    |> Map.put(:time_zone, dt.time_zone)
    |> Map.put(:utc_offset, dt.utc_offset)
    |> Map.put(:std_offset, dt.std_offset)
    |> Map.put(:zone_abbr, dt.zone_abbr)
  end

  defp naive_datetime_to_map(%NaiveDateTime{
         year: y,
         month: m,
         day: d,
         hour: h,
         minute: mi,
         second: s,
         microsecond: us,
         calendar: cal
       }) do
    base = %{
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: mi,
      second: s,
      calendar: cal
    }

    case us do
      {_, 0} -> base
      other -> Map.put(base, :microsecond, other)
    end
  end

  defp try_locale_glue(input, locale, options, as) do
    case glue_separators(locale) do
      [] ->
        {:error, no_match_error(input, locale)}

      separators ->
        # The glue separator (e.g. `, ` in en) often appears
        # inside the date half too — `MMM d, y` puts a comma
        # between day and year. Try every split point for every
        # candidate separator and accept the first that yields
        # parseable date + time halves.
        candidates =
          for sep <- separators,
              {left, right} <- enumerate_splits(input, sep) do
            {sep, left, right}
          end

        finder =
          case as do
            :map -> &try_split_as_map(&1, options)
            :struct -> &try_split_as_struct(&1, options)
          end

        Enum.find_value(
          candidates,
          {:error, no_match_error(input, locale)},
          finder
        )
    end
  end

  defp try_split_as_struct({_sep, left, right}, options) do
    with {:ok, date} <- Calendrical.Date.parse(left, options),
         {:ok, time, zone} <-
           Calendrical.Time.Parser.parse_with_zone(right, options),
         {:ok, ndt} <- NaiveDateTime.new(date, time) do
      # If the time half carried a zone, resolve it
      # into a `DateTime`. Resolution failure (e.g.
      # IANA name with no TZ database loaded) falls
      # back to the `NaiveDateTime` — preserving the
      # parse rather than failing the whole input.
      case zone do
        nil ->
          {:ok, ndt}

        _ ->
          case Calendrical.TimeZone.resolve(zone, ndt, options) do
            {:ok, %DateTime{} = dt} -> {:ok, dt}
            _ -> {:ok, ndt}
          end
      end
    else
      _ -> nil
    end
  end

  defp try_split_as_map({_sep, left, right}, options) do
    date_opts = Keyword.put(options, :as, :map)
    time_opts = Keyword.put(options, :as, :map)

    with {:ok, %{} = date_map} <- Calendrical.Date.parse(left, date_opts),
         {:ok, %{} = time_map, _zone} <-
           Calendrical.Time.Parser.parse_with_zone(right, time_opts) do
      # Date map carries `:calendar`; time map carries the time
      # fields plus `:time_zone` if any. Merge — date's
      # `:calendar` wins (the time map has no calendar key).
      {:ok, Map.merge(time_map, date_map)}
    else
      _ -> nil
    end
  end

  # All non-empty splits of `input` on `sep`, ordered to try
  # the latest-position split first (the "real" glue is usually
  # the last occurrence — date halves like `MMM d, y` consume
  # the earlier comma).
  defp enumerate_splits(input, sep) do
    case String.split(input, sep) do
      [_] ->
        []

      parts ->
        n = length(parts) - 1
        # For n split points, try them right-to-left.
        for i <- n..1//-1 do
          left = parts |> Enum.take(i) |> Enum.join(sep)
          right = parts |> Enum.drop(i) |> Enum.join(sep)
          {String.trim(left), String.trim(right)}
        end
        |> Enum.reject(fn {l, r} -> l == "" or r == "" end)
    end
  end

  # ── ISO 8601 ─────────────────────────────────────────────────

  defp try_iso(input) do
    cond do
      # Shape `YYYY-MM-DD<sep>HH:MM:SS[…]` where <sep> is `T`
      # (RFC 3339 / ISO 8601) or a space (Elixir stdlib also
      # accepts; widely used by Postgres, SQLite, logs, etc.).
      iso_datetime_shape?(input) ->
        case DateTime.from_iso8601(input) do
          {:ok, dt, _offset} -> {:ok, dt}
          _ -> try_iso_naive(input)
        end

      true ->
        :error
    end
  end

  # `Date.from_iso8601/1` and `NaiveDateTime.from_iso8601/1`
  # only accept the *extended* format with hyphens and colons.
  # Cheap shape check to avoid handing arbitrary input to the
  # stdlib parser.
  defp iso_datetime_shape?(input) do
    Regex.match?(~r/\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/u, input)
  end

  defp try_iso_naive(input) do
    case NaiveDateTime.from_iso8601(input) do
      {:ok, ndt} -> {:ok, ndt}
      _ -> :error
    end
  end

  # ── Locale glue split ───────────────────────────────────────

  # The CLDR date-time glue pattern is always `{1}<sep>{0}` —
  # `{1}` is the date portion and `{0}` is the time portion.
  # Extract `<sep>` from each standard glue pattern; the
  # caller backtracks through every split point in the input
  # to find one where both halves parse.
  defp glue_separators(locale) do
    case Format.date_time_formats(locale, :gregorian) do
      {:ok, glue_map} ->
        @standard_formats
        |> Enum.map(&Map.get(glue_map, &1))
        |> Enum.flat_map(&extract_separator/1)
        |> Enum.uniq()
        |> Enum.sort_by(&(-byte_size(&1)))

      _ ->
        []
    end
  end

  # Pattern shape is `{1}<sep>{0}`; pull <sep> via regex.
  # Returns the separator(s) as a list (most patterns yield
  # one; we wrap in a list for `flat_map` ergonomics).
  defp extract_separator(pattern) when is_binary(pattern) do
    case Regex.run(~r/\{1\}(.*?)\{0\}/u, pattern) do
      [_, sep] when sep != "" -> [sep]
      _ -> []
    end
  end

  defp extract_separator(_), do: []

  # ── Errors ───────────────────────────────────────────────────

  defp no_match_error(input, locale) do
    DateTimeParseError.exception(input: input, locale: locale)
  end
end
