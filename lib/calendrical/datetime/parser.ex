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
          {:ok, NaiveDateTime.t() | DateTime.t()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    input = String.trim(input)

    case try_iso(input) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_locale_glue(input, locale, options)
    end
  end

  defp try_locale_glue(input, locale, options) do
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

        Enum.find_value(
          candidates,
          {:error, no_match_error(input, locale)},
          fn {_sep, left, right} ->
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
        )
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
      # With offset or Z → DateTime
      String.contains?(input, "T") and
          (String.contains?(input, "Z") or String.contains?(input, "+") or
             String.match?(input, ~r/\d-\d{2}:\d{2}$/u)) ->
        case DateTime.from_iso8601(input) do
          {:ok, dt, _offset} -> {:ok, dt}
          _ -> try_iso_naive(input)
        end

      String.contains?(input, "T") ->
        try_iso_naive(input)

      true ->
        :error
    end
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
    DateTimeParseError.exception(
      input: input,
      locale: locale,
      message:
        "could not parse #{inspect(input)} as a datetime in locale #{inspect(locale)}; " <>
          "ISO-8601 (YYYY-MM-DDTHH:MM:SS[Z|±HH:MM]) is always accepted as a fallback"
    )
  end
end
