defmodule Calendrical.Time.Parser do
  @moduledoc """
  Locale-aware parser for user-typed time strings.

  Public entry point: `Calendrical.Time.parse/2`. Mirrors the
  structure of `Calendrical.Date.Parser` — try bare ISO-8601
  first, then the locale's CLDR `:short` / `:medium` / `:long`
  / `:full` time patterns.

  Implements the parts of [TR35 §Parsing Dates
  Times](https://unicode.org/reports/tr35/tr35-dates.html#Parsing_Dates_Times)
  and [§Parsing Day
  Periods](https://unicode.org/reports/tr35/tr35-dates.html#Parsing_Day_Periods)
  that matter for time-only input:

  * Numeric hour tokens `h` (1-12), `H` (0-23), `K` (0-11),
    `k` (1-24) — relaxed to 1-2 digits regardless of pattern
    count, matching the ICU lenient mode behaviour.

  * Minute `m`/`mm` and second `s`/`ss` — relaxed similarly.

  * Fractional seconds `S` — variable-precision; we capture
    1-9 digits and store as microseconds.

  * Day-period tokens `a` (AM/PM) and `b` (AM/PM + noon /
    midnight) — case-insensitive match against the locale's
    `day_periods` data plus the universal ASCII forms
    (`am`/`pm`/`a.m.`/`p.m.`/`AM`/`PM`).

  * Locale's CLDR `lenient-scope-date` data drives separator
    equivalences for `:`, fractional separator, and surrounding
    whitespace.

  Time-zone tokens (`z`, `Z`, `v`, `V`, `x`, `X`, `O`) are
  captured permissively but not currently resolved to an IANA
  zone. See `Calendrical.DateTime.Parser` for the datetime
  case where timezone resolution actually matters.

  """

  alias Localize.Calendar, as: LCalendar
  alias Localize.DateTime.Format
  alias Calendrical.TimeParseError

  @standard_formats [:short, :medium, :long, :full]

  # CLDR commonly uses NBSP / NNBSP / narrow-NBSP / ideographic
  # space between time fields and AM/PM markers. Accept any of
  # them where the pattern has a space.
  @space_class "[    　]*"

  @doc """
  Parses `input` as a locale-formatted time string.

  See `Calendrical.Time.parse/2` for the public contract.
  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, Time.t()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    input = String.trim(input)

    case try_iso(input) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_locale_patterns(input, locale)
    end
  end

  # ── ISO 8601 ─────────────────────────────────────────────────

  defp try_iso(input) do
    case Time.from_iso8601(input) do
      {:ok, time} -> {:ok, time}
      _ -> :error
    end
  end

  # ── Locale patterns (stubbed; filled out by subsequent edits)─

  defp try_locale_patterns(input, locale) do
    with {:ok, time_formats} <- Format.time_formats(locale, :gregorian),
         {:ok, available} <- Format.available_formats(locale, :gregorian),
         {:ok, day_periods} <- LCalendar.day_periods(locale, :gregorian) do
      patterns = collect_patterns(time_formats, available)
      lenient = load_lenient_date(locale)

      result =
        Enum.find_value(patterns, fn {_kind, pattern} ->
          case match_pattern(input, pattern, day_periods, lenient) do
            {:ok, time} -> {:ok, time}
            :error -> nil
          end
        end)

      result || {:error, no_match_error(input, locale)}
    end
  end

  defp collect_patterns(time_formats, available) do
    for kind <- @standard_formats,
        skeleton = Map.get(time_formats, kind),
        not is_nil(skeleton),
        pattern <- resolve_pattern_variants(Map.get(available, skeleton)),
        do: {kind, pattern}
  end

  defp resolve_pattern_variants(nil), do: []
  defp resolve_pattern_variants(pattern) when is_binary(pattern), do: [pattern]

  defp resolve_pattern_variants(%{variant: variant, standard: standard})
       when is_binary(variant) and is_binary(standard),
       do: [variant, standard]

  defp resolve_pattern_variants(%{unicode: u, ascii: a}) when is_binary(u) and is_binary(a),
    do: [u, a]

  defp resolve_pattern_variants(%{format: pattern}) when is_binary(pattern), do: [pattern]
  defp resolve_pattern_variants(_), do: []

  defp load_lenient_date(locale) do
    case Localize.Locale.get(locale, [:lenient_parse, :date]) do
      {:ok, data} when is_map(data) -> build_equivalence_map(data)
      _ -> %{}
    end
  end

  defp build_equivalence_map(data) do
    Enum.reduce(data, %{}, fn {_key, set_string}, acc ->
      case parse_cldr_set(set_string) do
        [] -> acc
        chars -> Enum.reduce(chars, acc, &Map.put(&2, &1, chars))
      end
    end)
  end

  defp parse_cldr_set(set) when is_binary(set) do
    case Regex.run(~r/^\[(.*)\]$/u, set) do
      [_, inner] ->
        inner
        |> String.replace("\\-", "-")
        |> String.graphemes()
        |> Enum.reject(&(&1 == " "))
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp parse_cldr_set(_), do: []

  defp no_match_error(input, locale) do
    TimeParseError.exception(
      input: input,
      locale: locale,
      message:
        "could not parse #{inspect(input)} as a time in locale #{inspect(locale)}; " <>
          "ISO-8601 (HH:MM[:SS[.frac]]) is always accepted as a fallback"
    )
  end

  # ── Pattern → regex ──────────────────────────────────────────

  defp match_pattern(input, pattern, day_periods, lenient) do
    tokens = tokenize_pattern(pattern)
    regex_string = compile_regex(tokens, day_periods, lenient)

    regex =
      case Regex.compile(regex_string, "u") do
        {:ok, r} -> r
        {:error, _} -> nil
      end

    with %Regex{} <- regex,
         %{} = caps <- Regex.named_captures(regex, input),
         {:ok, hour} <- extract_hour(caps, tokens),
         {:ok, minute} <- extract_field(caps, "minute"),
         {:ok, second} <- extract_field(caps, "second", 0),
         {:ok, microsecond} <- extract_microsecond(caps),
         {:ok, time} <- Time.new(hour, minute, second, microsecond) do
      {:ok, time}
    else
      _ -> :error
    end
  end

  # Walk a CLDR pattern string and emit alternating literal /
  # field tokens. Fields are runs of identical CLDR letters
  # (h H K k m s S a b B z Z v V x X O).
  defp tokenize_pattern(pattern) do
    pattern
    |> String.graphemes()
    |> tokenize([], nil)
    |> Enum.reverse()
  end

  defp tokenize([], acc, nil), do: acc
  defp tokenize([], acc, current), do: [field_token(current) | acc]

  defp tokenize(["'" | rest], acc, current) do
    {literal, rest} = take_quoted(rest, [])
    acc = if current, do: [field_token(current) | acc], else: acc
    tokenize(rest, [{:lit, literal} | acc], nil)
  end

  defp tokenize([char | rest], acc, current) do
    cond do
      cldr_letter?(char) ->
        case current do
          {^char, count} -> tokenize(rest, acc, {char, count + 1})
          nil -> tokenize(rest, acc, {char, 1})
          other -> tokenize(rest, [field_token(other) | acc], {char, 1})
        end

      true ->
        acc = if current, do: [field_token(current) | acc], else: acc
        tokenize(rest, prepend_literal(acc, char), nil)
    end
  end

  defp take_quoted(["'" | rest], acc), do: {acc |> Enum.reverse() |> Enum.join(), rest}
  defp take_quoted([char | rest], acc), do: take_quoted(rest, [char | acc])
  defp take_quoted([], acc), do: {acc |> Enum.reverse() |> Enum.join(), []}

  defp prepend_literal([{:lit, prev} | rest], char), do: [{:lit, prev <> char} | rest]
  defp prepend_literal(acc, char), do: [{:lit, char} | acc]

  defp field_token({char, count}), do: {String.to_atom(char), count}

  defp cldr_letter?(char) when char in ~w(h H K k m s S a b B z Z v V x X O), do: true
  defp cldr_letter?(_), do: false

  defp compile_regex(tokens, day_periods, lenient) do
    parts =
      tokens
      |> Enum.map(fn token -> field_regex(token, day_periods, lenient) end)

    "\\A" <> Enum.join(parts) <> "\\z"
  end

  # Numeric hour fields — relaxed to 1-2 digits regardless of
  # `h` vs `hh` per ICU lenient mode.
  defp field_regex({letter, _count}, _dp, _lenient) when letter in [:h, :H, :K, :k] do
    "(?P<hour_#{letter}>\\d{1,2})"
  end

  defp field_regex({:m, _count}, _dp, _lenient), do: "(?P<minute>\\d{1,2})"
  defp field_regex({:s, _count}, _dp, _lenient), do: "(?P<second>\\d{1,2})"

  # Fractional second — variable precision 1-9 digits.
  defp field_regex({:S, count}, _dp, _lenient) do
    max = max(count, 9)
    "(?P<microsecond>\\d{1,#{max}})"
  end

  # Day period (a) — match locale's wide / abbreviated / narrow
  # AM/PM names plus universal ASCII forms. `b` adds noon /
  # midnight markers (CLDR ≥ 41).
  defp field_regex({letter, _count}, day_periods, _lenient) when letter in [:a, :b] do
    day_period_regex(day_periods, letter)
  end

  # Flexible day period (B) — morning1/afternoon1/evening1/
  # night1/etc. Permissive match.
  defp field_regex({:B, _count}, _dp, _lenient), do: "[\\p{L}\\.\\s]+?"

  # Time zones — captured but not validated. The `Calendrical.DateTime.Parser`
  # path tightens this when timezone resolution matters.
  defp field_regex({letter, _count}, _dp, _lenient) when letter in [:z, :Z, :v, :V, :x, :X, :O],
    do: "(?P<zone>[\\p{L}\\d:+\\-/_]+)"

  # Literal text — expand each char via lenient equivalence.
  defp field_regex({:lit, text}, _dp, lenient) do
    text
    |> String.graphemes()
    |> Enum.map(&expand_char(&1, lenient))
    |> Enum.join()
  end

  defp expand_char(char, lenient) do
    cond do
      space_char?(char) ->
        @space_class

      true ->
        case Map.get(lenient, char) do
          nil -> Regex.escape(char)
          [_ | _] = chars -> "[" <> Enum.map_join(chars, &Regex.escape/1) <> "]"
        end
    end
  end

  defp space_char?(" "), do: true
  defp space_char?(" "), do: true
  defp space_char?(" "), do: true
  defp space_char?(" "), do: true
  defp space_char?("　"), do: true
  defp space_char?(_), do: false

  # ── Day-period regex (a / b) ────────────────────────────────

  # AM/PM names per locale plus a baseline of universal ASCII
  # forms (`AM`, `PM`, `a.m.`, `p.m.`, mixed case). Captured
  # in a single named group, value resolved against the
  # locale's day_period map at extract time.
  defp day_period_regex(day_periods, letter) do
    names =
      collect_period_names(day_periods, letter) ++
        ~w(AM PM am pm A.M. P.M. a.m. p.m.)

    alternation =
      names
      |> Enum.uniq()
      |> Enum.sort_by(&(-byte_size(&1)))
      |> Enum.map(&Regex.escape/1)
      |> Enum.join("|")

    "(?P<day_period>#{alternation})"
  end

  defp collect_period_names(day_periods, letter) do
    widths =
      case letter do
        :a -> [:wide, :abbreviated, :narrow]
        :b -> [:wide, :abbreviated, :narrow]
      end

    contexts = [:format, :stand_alone]

    for context <- contexts,
        width <- widths,
        {_period, name} <- get_in(day_periods, [context, width]) || %{},
        is_binary(name),
        do: name
  end

  # ── Field extraction ────────────────────────────────────────

  defp extract_hour(caps, tokens) do
    # Find which hour-letter actually fired. We named each as
    # `hour_h` / `hour_H` / `hour_K` / `hour_k` so we can
    # discriminate.
    hour_field =
      Enum.find(["hour_h", "hour_H", "hour_K", "hour_k"], fn key ->
        Map.get(caps, key, "") != ""
      end)

    with raw when is_binary(raw) and raw != "" <- caps[hour_field],
         {n, ""} <- Integer.parse(raw) do
      letter = hour_field |> String.replace_prefix("hour_", "") |> String.to_atom()
      resolve_hour(n, letter, caps, tokens)
    else
      _ -> :error
    end
  end

  # Resolve 12-hour vs 24-hour and AM/PM. CLDR conventions:
  #   h: 1-12, paired with a/b for AM/PM disambiguation
  #   H: 0-23, no AM/PM
  #   K: 0-11, paired with a/b
  #   k: 1-24 (k=24 == midnight start of day)
  defp resolve_hour(n, :H, _caps, _tokens) when n in 0..23, do: {:ok, n}
  defp resolve_hour(24, :k, _caps, _tokens), do: {:ok, 0}
  defp resolve_hour(n, :k, _caps, _tokens) when n in 1..23, do: {:ok, n}

  defp resolve_hour(n, letter, caps, _tokens) when letter in [:h, :K] do
    base = if letter == :h, do: rem(n, 12), else: n

    period = caps |> Map.get("day_period", "") |> String.downcase()

    cond do
      period in ["pm", "p.m."] ->
        {:ok, base + 12}

      period in ["am", "a.m.", ""] ->
        {:ok, base}

      # Locale-specific day-period name — look up via heuristic.
      String.contains?(period, "pm") or String.contains?(period, "p.m") ->
        {:ok, base + 12}

      true ->
        # No PM signal — treat as morning (12-hour with no period
        # is ambiguous; we pick AM as the conservative default).
        {:ok, base}
    end
  end

  defp resolve_hour(_, _, _, _), do: :error

  defp extract_field(caps, key, default \\ nil) do
    case caps[key] do
      nil when is_integer(default) ->
        {:ok, default}

      raw when is_binary(raw) and raw != "" ->
        case Integer.parse(raw) do
          {n, ""} -> {:ok, n}
          _ -> :error
        end

      _ when is_integer(default) ->
        {:ok, default}

      _ ->
        :error
    end
  end

  defp extract_microsecond(caps) do
    case caps["microsecond"] do
      nil ->
        {:ok, {0, 0}}

      "" ->
        {:ok, {0, 0}}

      raw ->
        # CLDR `S` is decimal-truncated, not rounded. Pad / trim
        # to 6 digits for Elixir's `Time` microsecond field.
        precision = min(String.length(raw), 6)
        padded = String.pad_trailing(String.slice(raw, 0, 6), 6, "0")

        case Integer.parse(padded) do
          {n, ""} -> {:ok, {n, precision}}
          _ -> :error
        end
    end
  end
end
