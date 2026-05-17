defmodule Calendrical.Date.Parser do
  @moduledoc """
  Locale-aware parser for user-typed date strings, with full
  multi-calendar support.

  Public entry point: `Calendrical.Date.parse/2`. This module
  is the underlying engine.

  Strategy, in order:

  * Bare ISO-8601 (`YYYY-MM-DD`) — accepted in every locale.
    This is the wire format and the unambiguous escape hatch.

  * Locale-specific CLDR patterns. The parser pulls
    `:short`, `:medium`, `:long`, `:full` for the (locale,
    calendar) tuple and tries each as a regex template. CLDR
    encodes the locale's preferred field order
    (`M/d/yy` in `en`, `dd.MM.y` in `de`, `Gy年M月d日` in
    Japanese imperial), so the same input may parse to
    different dates under different locales — by design.

  ### Calendar support

  Any CLDR calendar that has a `Calendrical.*` module
  implementation: `:gregorian`, `:buddhist`, `:islamic_civil`,
  `:islamic_umalqura`, `:islamic_tbla`, `:islamic_rgsa`,
  `:islamic`, `:japanese`, `:persian`, `:hebrew`, `:coptic`,
  `:ethiopic`, `:ethiopic_amete_alem`, `:indian`, `:roc`,
  `:chinese`, `:dangi`.

  The `:calendar` option says **what calendar to interpret
  the input as**. The result is always a `t:Date.t/0` whose
  `:calendar` field is the corresponding Calendrical module
  (or `Calendar.ISO` for `:gregorian`). Convert to ISO with
  `Date.convert/2` if needed.

  ### Lenient matching

  * `dd` and `MM` accept 1–2 digits (so `3/4/26` parses
    under `en-GB`'s `dd/MM/y`).

  * Any 2-digit typed year pivots into the 80-back/20-forward
    window relative to the reference year (overridable via
    `:reference_date`).

  * Literal separators in the format pattern expand to the
    locale's CLDR `lenient-scope-date` equivalence class —
    `-`, `/`, `.`, non-breaking hyphen, etc. all match in
    locales where CLDR considers them equivalent.

  * Spaces between adjacent fields are accepted regardless of
    whether the pattern includes them — so
    `民國 115年5月16日` (with a space after the era marker)
    parses correctly under the CLDR pattern `Gy年M月d日`.

  * Non-Latin digits are transliterated to Latin before
    integer parsing using the locale's default number system.
    `٢٤` (Arabic-Indic 24) and `24` both parse identically.

  ### Era handling

  For era-aware calendars (Japanese imperial, Islamic Hijri,
  ROC, etc.), the `G` field in CLDR patterns marks the era
  marker (`平成`, `هـ`, `AH`, `BCE`, `民國`). The parser
  captures the era name, resolves it via
  `Localize.Calendar.eras/2`, and computes the calendar-year
  from the era-year for calendars that need it (Japanese).

  """

  alias Localize.Calendar, as: LCalendar
  alias Localize.DateTime.Format
  alias Calendrical.{DateParseError, DateRangeParseError}

  @standard_formats [:short, :medium, :long, :full]
  @month_name_widths %{3 => :abbreviated, 4 => :wide, 5 => :narrow}
  @era_widths %{1 => :abbreviated, 2 => :abbreviated, 3 => :abbreviated, 4 => :wide, 5 => :narrow}

  # CLDR formats often use narrow no-break space (U+2009),
  # NBSP (U+00A0), narrow NBSP (U+202F), and ideographic
  # space (U+3000) around separators. Real-world input uses
  # plain ASCII space. Accept any of them as the same slot.
  @space_class "[    　]*"

  @doc """
  Parses `input` as a locale-formatted date.

  See `Calendrical.Date.parse/2` for the public contract.
  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    cldr_calendar = Keyword.get(options, :calendar, :gregorian)
    reference_year = (Keyword.get(options, :reference_date) || Date.utc_today()).year
    return_calendar = Keyword.get(options, :return_calendar, :iso)
    input = String.trim(input)

    case try_iso(input, return_calendar) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_locale_patterns(
          input,
          locale,
          cldr_calendar,
          reference_year,
          return_calendar
        )
    end
  end

  @doc """
  Parses a single-string date range. See
  `Calendrical.Date.parse_range/2` for the public contract.
  """
  @spec parse_range(String.t(), Keyword.t()) ::
          {:ok, Date.Range.t()} | {:error, Exception.t()}
  def parse_range(input, options \\ []) when is_binary(input) do
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    cldr_calendar = Keyword.get(options, :calendar, :gregorian)
    reference_year = (Keyword.get(options, :reference_date) || Date.utc_today()).year
    allow_inverted = Keyword.get(options, :allow_inverted, false)
    input = String.trim(input)

    # Strategy:
    # 1. Try the locale's CLDR interval patterns first — these
    #    are the only way to parse inputs where one endpoint is
    #    partial (e.g. "May 5 – May 10, 2026" where left has no
    #    year and inherits from right).
    # 2. Fall back to a naive split-then-parse-each-side. Catches
    #    inputs the interval patterns don't cover (e.g. mixed
    #    formats, ISO endpoints).
    case match_any_interval_pattern(input, locale, cldr_calendar, reference_year) do
      {:ok, from_date, to_date} ->
        case build_range(from_date, to_date, allow_inverted) do
          {:ok, _} = ok -> ok
          {:error, _} = err -> err
        end

      :error ->
        case split_on_interval_separator(input, locale, cldr_calendar) do
          {:ok, from_string, to_string} ->
            parse_range_pair(from_string, to_string, options)

          :error ->
            {:error,
             DateRangeParseError.exception(
               input: input,
               reason: :no_separator,
               message:
                 "could not find an interval separator in #{inspect(input)} for locale " <>
                   "#{inspect(locale)}; expected CLDR interval-fallback separator (e.g. \" – \") " <>
                   "or one of `-`, `/`, `~`, `〜`"
             )}
        end
    end
  end

  # ── Interval pattern matching (skeleton inheritance) ─────────

  # Walk every interval pattern published for the locale's
  # standard date skeletons (`:yMd`, `:yMMMd`, `:yMMMMd`,
  # `:Md`, `:MMMd`, `:MMMMd`, `:GyMd`, etc.) and try each one
  # against the full input. The CLDR convention is that the
  # *first* occurrence of each field belongs to the left
  # endpoint and the *second* occurrence (after the implicit
  # separator) belongs to the right endpoint. Endpoint-1
  # fields not present in the pattern inherit from endpoint-2
  # (and vice versa), which is how `"May 5 – May 10, 2026"`
  # parses correctly even though the left side has no year.
  defp match_any_interval_pattern(input, locale, cldr_calendar, reference_year) do
    with {:ok, intervals} <- Format.interval_formats(locale, cldr_calendar),
         {:ok, months_data} <- LCalendar.months(locale, cldr_calendar) do
      lenient = load_lenient_date(locale)
      transliterated = transliterate_digits(input, locale)
      eras_data = maybe_load_eras(locale, cldr_calendar)

      patterns =
        for {skeleton, by_field} <- intervals,
            is_atom(skeleton),
            is_map(by_field),
            {_field, pattern} <- by_field,
            is_binary(pattern) do
          pattern
        end

      Enum.find_value(patterns, :error, fn pattern ->
        case match_interval_pattern(
               transliterated,
               pattern,
               months_data,
               eras_data,
               lenient,
               reference_year,
               cldr_calendar
             ) do
          {:ok, left, right} -> {:ok, left, right}
          :error -> nil
        end
      end)
    else
      _ -> :error
    end
  end

  defp match_interval_pattern(
         input,
         pattern,
         months_data,
         eras_data,
         lenient,
         reference_year,
         cldr_calendar
       ) do
    {tokens_l, tokens_r} = split_interval_tokens(tokenize_pattern(pattern))

    if tokens_r == [] do
      # Pattern with no repeating field — not a usable interval
      # pattern (would parse only a single endpoint).
      :error
    else
      left_regex =
        compile_capture_regex(tokens_l, months_data, eras_data, lenient, "left_")

      right_regex =
        compile_capture_regex(tokens_r, months_data, eras_data, lenient, "right_")

      full_regex_string = "\\A" <> left_regex <> right_regex <> "\\z"

      with {:ok, regex} <- Regex.compile(full_regex_string, "u"),
           %{} = caps <- Regex.named_captures(regex, input),
           {:ok, left_partial} <- extract_partial(caps, "left_", reference_year, cldr_calendar),
           {:ok, right_partial} <- extract_partial(caps, "right_", reference_year, cldr_calendar),
           {:ok, left_date} <- materialise(left_partial, right_partial, cldr_calendar),
           {:ok, right_date} <- materialise(right_partial, left_partial, cldr_calendar) do
        {:ok, left_date, right_date}
      else
        _ -> :error
      end
    end
  end

  # Walk the token stream: a field that's already been seen
  # marks the start of the right endpoint. The tokens between
  # the first and second occurrence of any field (typically
  # just literal separator text) get appended to the left
  # side. We accept day-of-week (`E`/`c`) repeats as well as
  # the date fields.
  defp split_interval_tokens(tokens) do
    {left, right, _} =
      Enum.reduce(tokens, {[], [], MapSet.new()}, fn token, {l, r, seen} ->
        case classify_token(token) do
          {:field, letter} ->
            if MapSet.member?(seen, letter) or r != [] do
              {l, r ++ [token], seen}
            else
              {l ++ [token], r, MapSet.put(seen, letter)}
            end

          :literal ->
            if r == [] do
              {l ++ [token], r, seen}
            else
              {l, r ++ [token], seen}
            end
        end
      end)

    {left, right}
  end

  defp classify_token({:lit, _}), do: :literal
  defp classify_token({letter, _count}) when is_atom(letter), do: {:field, letter}

  # Like compile_regex/4 but each capture is prefixed (so
  # left/right halves of the interval pattern produce
  # distinguishable captures in the same regex). Lenient-gap
  # injection between adjacent field tokens applies here too.
  defp compile_capture_regex(tokens, months_data, eras_data, lenient, prefix) do
    tokens
    |> build_regex_parts(months_data, eras_data, lenient, prefix)
    |> Enum.join()
  end

  # Rewrite a single `(?P<name>...)` capture group's name to
  # `<prefix><name>` so left- and right-half captures don't
  # collide.
  defp rename_capture(regex, prefix) do
    Regex.replace(~r/\(\?P<([^>]+)>/, regex, fn _, name ->
      "(?P<#{prefix}#{name}>"
    end)
  end

  # Extract the `{year, month, day}` triple for one side of an
  # interval. Any field may be absent (missing from this
  # endpoint's portion of the pattern); represented as `nil`
  # so `materialise/3` can fill from the other side.
  defp extract_partial(caps, prefix, reference_year, cldr_calendar) do
    year =
      case Map.get(caps, prefix <> "year") do
        nil ->
          nil

        "" ->
          nil

        raw ->
          case Integer.parse(raw) do
            {n, ""} ->
              if cldr_calendar == :gregorian and String.length(raw) == 2 do
                pivot_year(n, reference_year)
              else
                n
              end

            _ ->
              nil
          end
      end

    month =
      case Map.get(caps, prefix <> "month") do
        raw when is_binary(raw) and raw != "" ->
          case Integer.parse(raw) do
            {n, ""} when n in 1..13 -> n
            _ -> nil
          end

        _ ->
          # No numeric-month capture (nil or ""), so look for a
          # name-based month capture (`__mN__` with the prefix).
          extract_month_by_name(caps, prefix)
      end

    day =
      case Map.get(caps, prefix <> "day") do
        nil ->
          nil

        "" ->
          nil

        raw ->
          case Integer.parse(raw) do
            {n, ""} when n in 1..31 -> n
            _ -> nil
          end
      end

    # Era field (Japanese imperial) — capture index, use it to
    # convert era_year into Gregorian year.
    era_index =
      case Enum.find(caps, fn
             {key, value} ->
               String.starts_with?(key, prefix <> "__e") and value != ""

             _ ->
               false
           end) do
        {key, _} ->
          # key looks like "<prefix>__e<index>__"
          case Regex.run(~r/__e(\d+)__$/, key) do
            [_, idx] ->
              case Integer.parse(idx) do
                {n, ""} -> n
                _ -> nil
              end

            _ ->
              nil
          end

        nil ->
          nil
      end

    year =
      case {cldr_calendar, era_index, year} do
        {:japanese, era, y} when is_integer(era) and is_integer(y) ->
          case japanese_era_start_year(era) do
            {:ok, start_year} -> start_year + y - 1
            :error -> y
          end

        _ ->
          year
      end

    {:ok, %{year: year, month: month, day: day}}
  end

  defp extract_month_by_name(caps, prefix) do
    case Enum.find(caps, fn
           {key, value} -> String.starts_with?(key, prefix <> "__m") and value != ""
           _ -> false
         end) do
      {key, _} ->
        case Regex.run(~r/__m(\d+)__$/, key) do
          [_, idx] ->
            case Integer.parse(idx) do
              {n, ""} when n in 1..13 -> n
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Fill missing fields from `inherit_from`, then construct
  # the date in the requested calendar and convert to ISO.
  defp materialise(%{year: y, month: m, day: d}, inherit_from, cldr_calendar) do
    year = y || inherit_from.year
    month = m || inherit_from.month
    day = d || inherit_from.day

    cond do
      is_nil(year) or is_nil(month) or is_nil(day) ->
        :error

      true ->
        with {:ok, calendar_module} <- resolve_calendar_module(cldr_calendar),
             {:ok, date} <- build_date(year, month, day, calendar_module),
             iso_date <-
               if(date.calendar == Calendar.ISO,
                 do: date,
                 else: Date.convert!(date, Calendar.ISO)
               ) do
          {:ok, iso_date}
        else
          _ -> :error
        end
    end
  end

  @doc """
  Parses pre-split range endpoints. See
  `Calendrical.Date.parse_range/2` for the public contract.
  """
  @spec parse_range_pair(String.t(), String.t(), Keyword.t()) ::
          {:ok, Date.Range.t()} | {:error, Exception.t()}
  def parse_range_pair(from_string, to_string, options)
      when is_binary(from_string) and is_binary(to_string) do
    allow_inverted = Keyword.get(options, :allow_inverted, false)

    with {:ok, from_date} <- parse_or_wrap(from_string, options, :from_parse_failed),
         {:ok, to_date} <- parse_or_wrap(to_string, options, :to_parse_failed),
         {:ok, range} <- build_range(from_date, to_date, allow_inverted) do
      {:ok, range}
    end
  end

  defp parse_or_wrap(string, options, reason_tag) do
    case parse(string, options) do
      {:ok, %Date{} = date} ->
        {:ok, date}

      {:error, %DateParseError{} = err} ->
        {:error,
         DateRangeParseError.exception(
           input: string,
           reason: reason_tag,
           cause: err,
           message: "range endpoint #{inspect(string)} could not be parsed: " <> err.message
         )}
    end
  end

  defp build_range(from, to, allow_inverted) do
    case Date.compare(from, to) do
      :gt when not allow_inverted ->
        {:error,
         DateRangeParseError.exception(
           input: {from, to},
           reason: :inverted,
           message:
             "range end #{inspect(to)} is before start #{inspect(from)}; " <>
               "pass `allow_inverted: true` to permit descending ranges"
         )}

      :gt ->
        {:ok, Date.range(from, to, -1)}

      _ ->
        {:ok, Date.range(from, to)}
    end
  end

  # Find the interval separator for this locale by consulting
  # CLDR's `intervalFormatFallback` (`[0, separator, 1]`).
  # Lenient: also accept `-`, `/`, `~`, `〜`, the en/em dashes,
  # and the locale separator with optional surrounding
  # whitespace.
  defp split_on_interval_separator(input, locale, cldr_calendar) do
    cldr_sep = lookup_interval_separator(locale, cldr_calendar)

    candidates =
      [cldr_sep | ["–", "—", "−", "〜", "~", "to", " - ", " / "]]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.find_value(candidates, :error, fn sep ->
      case String.split(input, sep, parts: 2) do
        [left, right] ->
          left = String.trim(left)
          right = String.trim(right)

          if left != "" and right != "" do
            {:ok, left, right}
          else
            nil
          end

        _ ->
          nil
      end
    end)
  end

  defp lookup_interval_separator(locale, cldr_calendar) do
    case Format.interval_formats(locale, cldr_calendar) do
      {:ok, intervals} ->
        case Map.get(intervals, :interval_format_fallback) do
          [0, separator, 1] when is_binary(separator) -> String.trim(separator)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # ── ISO 8601 ─────────────────────────────────────────────────

  defp try_iso(input, return_calendar) do
    case Date.from_iso8601(input) do
      {:ok, date} -> {:ok, maybe_convert(date, return_calendar)}
      _ -> :error
    end
  end

  # ── Locale patterns ──────────────────────────────────────────

  defp try_locale_patterns(input, locale, cldr_calendar, reference_year, return_calendar) do
    with {:ok, calendar_module} <- resolve_calendar_module(cldr_calendar),
         {:ok, date_formats} <- Format.date_formats(locale, cldr_calendar),
         {:ok, available} <- Format.available_formats(locale, cldr_calendar),
         {:ok, months_data} <- LCalendar.months(locale, cldr_calendar) do
      eras_data = maybe_load_eras(locale, cldr_calendar)
      lenient = load_lenient_date(locale)
      transliterated = transliterate_digits(input, locale)
      patterns = collect_patterns(date_formats, available)

      result =
        Enum.find_value(patterns, fn {_kind, pattern} ->
          case match_pattern(
                 transliterated,
                 pattern,
                 months_data,
                 eras_data,
                 lenient,
                 reference_year,
                 calendar_module,
                 cldr_calendar
               ) do
            {:ok, date} -> {:ok, maybe_convert(date, return_calendar)}
            :error -> nil
          end
        end)

      result || {:error, no_match_error(input, locale, cldr_calendar)}
    end
  end

  defp resolve_calendar_module(:gregorian), do: {:ok, Calendar.ISO}

  defp resolve_calendar_module(cldr_calendar) do
    case Calendrical.calendar_from_cldr_calendar_type(cldr_calendar) do
      {:ok, module} -> {:ok, module}
      {:error, _} -> {:ok, Calendar.ISO}
    end
  end

  defp maybe_convert(%Date{calendar: Calendar.ISO} = date, _), do: date
  defp maybe_convert(%Date{} = date, :iso), do: Date.convert!(date, Calendar.ISO)
  defp maybe_convert(%Date{} = date, _other), do: date

  # ── Digit transliteration ────────────────────────────────────

  # Translate non-Latin digit runs to Latin before integer
  # parsing. Walk the locale's default number system; for
  # numeric systems with custom digit sets, build the
  # translation table on the fly.
  defp transliterate_digits(input, locale) do
    with {:ok, system} <- Localize.Number.System.number_system_from_locale(locale),
         {:ok, digits} when is_binary(digits) and byte_size(digits) > 0 <-
           Localize.Number.System.number_system_digits(system) do
      digit_translate(input, digits)
    else
      _ -> input
    end
  end

  defp digit_translate(input, "0123456789"), do: input

  defp digit_translate(input, digits) do
    table =
      digits
      |> String.graphemes()
      |> Enum.with_index()
      |> Map.new(fn {char, index} -> {char, Integer.to_string(index)} end)

    input
    |> String.graphemes()
    |> Enum.map_join(fn char -> Map.get(table, char, char) end)
  end

  # ── Lenient-scope-date equivalence map ──────────────────────

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

  # ── Eras ─────────────────────────────────────────────────────

  defp maybe_load_eras(locale, calendar) do
    case LCalendar.eras(locale, calendar) do
      {:ok, data} -> data
      _ -> %{}
    end
  end

  defp collect_patterns(date_formats, available) do
    for kind <- @standard_formats,
        skeleton = Map.get(date_formats, kind),
        not is_nil(skeleton),
        pattern <- resolve_pattern_variants(Map.get(available, skeleton)),
        do: {kind, pattern}
  end

  defp resolve_pattern_variants(nil), do: []
  defp resolve_pattern_variants(pattern) when is_binary(pattern), do: [pattern]

  defp resolve_pattern_variants(%{variant: variant, standard: standard})
       when is_binary(variant) and is_binary(standard),
       do: [variant, standard]

  defp resolve_pattern_variants(%{format: pattern}) when is_binary(pattern),
    do: [pattern]

  defp resolve_pattern_variants(_), do: []

  # ── Pattern → regex ──────────────────────────────────────────

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

  defp cldr_letter?(char) when char in ~w(y M d E G L c), do: true
  defp cldr_letter?(_), do: false

  defp compile_regex(tokens, months_data, eras_data, lenient) do
    parts = build_regex_parts(tokens, months_data, eras_data, lenient, "")
    "\\A" <> Enum.join(parts) <> "\\z"
  end

  # Build the list of regex fragments, inserting optional
  # whitespace between adjacent *field* tokens where the
  # pattern has no literal separator. This makes
  # `民國 115年5月16日` (with a space after the era marker)
  # parse under the CLDR pattern `Gy年M月d日`. Literal
  # separators in the pattern keep their natural-vs-lenient
  # equivalence — only the *empty* gap between fields is
  # relaxed.
  defp build_regex_parts(tokens, months_data, eras_data, lenient, prefix) do
    tokens
    |> Enum.reduce({[], nil}, fn token, {acc, prev_kind} ->
      {kind, regex} =
        case field_regex(token, months_data, eras_data, lenient) do
          {:capture, _name, regex} -> {:field, maybe_prefix_capture(regex, prefix)}
          {:plain, regex} -> {classify_plain(token), regex}
        end

      regex_with_gap =
        if prev_kind == :field and kind == :field do
          @space_class <> regex
        else
          regex
        end

      {[regex_with_gap | acc], kind}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp classify_plain({:lit, _}), do: :literal
  defp classify_plain(_), do: :field

  defp maybe_prefix_capture(regex, ""), do: regex
  defp maybe_prefix_capture(regex, prefix), do: rename_capture(regex, prefix)

  defp field_regex({:lit, text}, _months, _eras, lenient) do
    {:plain, expand_literal(text, lenient)}
  end

  defp field_regex({:y, count}, _months, _eras, _lenient) do
    regex =
      case count do
        2 -> "(?P<year>\\d{2})"
        _ -> "(?P<year>\\d{1,4})"
      end

    {:capture, :year, regex}
  end

  defp field_regex({:M, count}, _months, _eras, _lenient) when count <= 2 do
    {:capture, :month, "(?P<month>\\d{1,2})"}
  end

  defp field_regex({:M, count}, months, _eras, _lenient) when count in 3..5 do
    {:capture, :month, month_name_regex(months, @month_name_widths[count])}
  end

  defp field_regex({:L, count}, months, eras, lenient),
    do: field_regex({:M, count}, months, eras, lenient)

  defp field_regex({:d, _count}, _months, _eras, _lenient) do
    {:capture, :day, "(?P<day>\\d{1,2})"}
  end

  # Day-of-week names: tolerate and skip.
  defp field_regex({letter, _count}, _months, _eras, _lenient) when letter in [:E, :c],
    do: {:plain, "[\\p{L}\\.]+"}

  # Era marker. Try to capture against the locale's era names
  # so we can resolve era → year offset for Japanese imperial.
  # If no era names are available, fall back to tolerate-and-skip.
  defp field_regex({:G, count}, _months, eras, _lenient) do
    width = Map.get(@era_widths, count, :abbreviated)

    case era_name_regex(eras, width) do
      {:branches, regex} -> {:capture, :era, regex}
      :none -> {:plain, "[\\p{L}\\.]+"}
    end
  end

  defp expand_literal(text, lenient) do
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

  defp month_name_regex(months_data, width) do
    names =
      months_data
      |> get_in([:format, width]) ||
        get_in(months_data, [:stand_alone, width]) ||
        %{}

    branches =
      names
      |> Enum.sort_by(fn {_index, name} -> -byte_size(name) end)
      |> Enum.map(fn {index, name} -> "(?P<__m#{index}__>#{Regex.escape(name)})" end)

    "(?:" <> Enum.join(branches, "|") <> ")"
  end

  defp era_name_regex(eras_data, width) when is_map(eras_data) do
    names =
      eras_data
      |> get_era_names_for_width(width)

    if Enum.empty?(names) do
      :none
    else
      branches =
        names
        |> Enum.sort_by(fn {_index, name} -> -byte_size(name) end)
        |> Enum.map(fn {index, name} -> "(?P<__e#{index}__>#{Regex.escape(name)})" end)

      {:branches, "(?:" <> Enum.join(branches, "|") <> ")"}
    end
  end

  # `Localize.Calendar.eras/2` returns `%{width => %{index =>
  # name}}` — top-level keys are width atoms (`:wide`,
  # `:abbreviated`, `:narrow`), inner maps are
  # `era_index => era_name`.
  defp get_era_names_for_width(eras_data, width) do
    inner = Map.get(eras_data, width) || Map.get(eras_data, :abbreviated) || %{}

    Enum.flat_map(inner, fn
      {index, name} when is_integer(index) and is_binary(name) -> [{index, name}]
      _ -> []
    end)
  end

  # ── Matching ─────────────────────────────────────────────────

  defp match_pattern(
         input,
         pattern,
         months_data,
         eras_data,
         lenient,
         reference_year,
         calendar_module,
         cldr_calendar
       ) do
    tokens = tokenize_pattern(pattern)
    regex_string = compile_regex(tokens, months_data, eras_data, lenient)

    regex =
      case Regex.compile(regex_string, "u") do
        {:ok, r} -> r
        {:error, _} -> nil
      end

    with %Regex{} <- regex,
         %{} = caps <- Regex.named_captures(regex, input),
         {:ok, year_in_calendar} <- extract_year(caps, reference_year, cldr_calendar),
         {:ok, month} <- extract_month(caps),
         {:ok, day} <- extract_day(caps),
         {:ok, era_index} <- extract_era(caps),
         {:ok, calendar_year} <-
           resolve_calendar_year(year_in_calendar, era_index, cldr_calendar) do
      build_date(calendar_year, month, day, calendar_module)
    else
      _ -> :error
    end
  end

  # The 2-digit-year pivot is a Gregorian convention. For era-
  # aware calendars (Japanese imperial, ROC, etc.) the year
  # value is meant literally (`平成12年` = Heisei year 12,
  # not "the year '12 ≈ 2012"), so pivoting would corrupt the
  # input.
  defp extract_year(%{"year" => raw}, reference_year, cldr_calendar) when raw != "" do
    case Integer.parse(raw) do
      {n, ""} ->
        if cldr_calendar == :gregorian and String.length(raw) == 2 do
          {:ok, pivot_year(n, reference_year)}
        else
          {:ok, n}
        end

      _ ->
        :error
    end
  end

  defp extract_year(_, _, _), do: :error

  defp pivot_year(two_digit, reference_year) do
    century_base = div(reference_year - 80, 100) * 100
    candidate = century_base + two_digit
    if candidate < reference_year - 80, do: candidate + 100, else: candidate
  end

  defp extract_month(%{"month" => raw}) when raw != "" do
    case Integer.parse(raw) do
      {n, ""} when n in 1..13 -> {:ok, n}
      _ -> :error
    end
  end

  defp extract_month(caps) do
    case Enum.find(caps, fn
           {"__m" <> _, value} -> value != ""
           _ -> false
         end) do
      {"__m" <> rest, _value} ->
        case String.split(rest, "__", parts: 2) do
          [index_str, _] ->
            case Integer.parse(index_str) do
              {n, ""} when n in 1..13 -> {:ok, n}
              _ -> :error
            end

          _ ->
            :error
        end

      nil ->
        :error
    end
  end

  defp extract_day(%{"day" => raw}) when raw != "" do
    case Integer.parse(raw) do
      {n, ""} when n in 1..31 -> {:ok, n}
      _ -> :error
    end
  end

  defp extract_day(_), do: :error

  defp extract_era(caps) do
    case Enum.find(caps, fn
           {"__e" <> _, value} -> value != ""
           _ -> false
         end) do
      {"__e" <> rest, _value} ->
        case String.split(rest, "__", parts: 2) do
          [index_str, _] ->
            case Integer.parse(index_str) do
              {n, ""} -> {:ok, n}
              _ -> {:ok, nil}
            end

          _ ->
            {:ok, nil}
        end

      nil ->
        {:ok, nil}
    end
  end

  # For Japanese imperial dates, the parsed `year` is the
  # year-within-era, not the Gregorian year. Convert using
  # the era's start date from CLDR supplemental data.
  defp resolve_calendar_year(year, era_index, :japanese) when is_integer(era_index) do
    case japanese_era_start_year(era_index) do
      {:ok, start_year} -> {:ok, start_year + year - 1}
      :error -> {:error, :unknown_era}
    end
  end

  # For other era-aware calendars (Islamic, Hebrew, etc.), the
  # year in input IS the calendar's year — no era arithmetic
  # needed. The era marker is presentational.
  defp resolve_calendar_year(year, _era_index, _calendar), do: {:ok, year}

  defp japanese_era_start_year(era_index) do
    case Localize.SupplementalData.calendars()
         |> get_in([:japanese, :eras]) do
      eras when is_list(eras) ->
        case Enum.find(eras, fn [idx, _] -> idx == era_index end) do
          [_idx, %{start: [year, _m, _d]}] -> {:ok, year}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp build_date(year, month, day, Calendar.ISO) do
    case Date.new(year, month, day) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> :error
    end
  end

  defp build_date(year, month, day, calendar_module) do
    case Date.new(year, month, day, calendar_module) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> :error
    end
  end

  # ── Errors ───────────────────────────────────────────────────

  defp no_match_error(input, locale, calendar) do
    DateParseError.exception(
      input: input,
      locale: locale,
      calendar: calendar,
      message:
        "could not parse #{inspect(input)} as a date in locale #{inspect(locale)} " <>
          "(calendar #{inspect(calendar)}); ISO-8601 (YYYY-MM-DD) is always accepted as a fallback"
    )
  end
end
