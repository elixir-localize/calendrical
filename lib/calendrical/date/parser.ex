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
    cldr_calendar = normalise_calendar(Keyword.get(options, :calendar, :gregorian))
    reference_year = (Keyword.get(options, :reference_date) || Date.utc_today()).year
    return_module = resolve_return_calendar(options, cldr_calendar)
    input = String.trim(input)

    case try_iso(input, return_module) do
      {:ok, _} = ok ->
        ok

      :error ->
        try_locale_patterns(
          input,
          locale,
          cldr_calendar,
          reference_year,
          return_module
        )
    end
  end

  # Resolve the target calendar module for the returned Date.
  # The `:return_calendar` option accepts:
  #
  #   * `:native` (default) — return the Date in whatever
  #     calendar the `:calendar` option named. So
  #     `parse("2026-05-17", calendar: :hebrew)` returns
  #     `~D[5786-10-01 Calendrical.Hebrew]`. This is the
  #     natural behavior — the `:calendar` option says
  #     "interpret AND return in this calendar".
  #
  #   * `:iso` — force the result into `Calendar.ISO`
  #     (Gregorian). Use this when a downstream consumer
  #     (e.g. an Ecto `:date` cast) requires ISO.
  #
  #   * a calendar module like `Calendrical.Persian` —
  #     return the Date in that specific calendar regardless
  #     of `:calendar`.
  #
  defp resolve_return_calendar(options, cldr_calendar) do
    case Keyword.get(options, :return_calendar, :native) do
      :iso -> Calendar.ISO
      :native -> elem(resolve_calendar_module(cldr_calendar), 1)
      module when is_atom(module) -> module
    end
  end

  @doc """
  Parses a single-string date range. See
  `Calendrical.Date.parse_range/2` for the public contract.
  """
  @spec parse_range(String.t(), Keyword.t()) ::
          {:ok, Date.Range.t()} | {:error, Exception.t()}
  def parse_range(input, options \\ []) when is_binary(input) do
    options = normalise_calendar_option(options)
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
  defp compile_capture_regex(tokens, months_data, eras_data, lenient, prefix, ctx \\ %{}) do
    tokens
    |> build_regex_parts(months_data, eras_data, lenient, prefix, ctx)
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
  # the date in the requested calendar. The returned date
  # keeps the requested calendar — both interval endpoints
  # are materialised under the same calendar so the resulting
  # `Date.Range` is well-formed for any calendar, not just ISO.
  defp materialise(%{year: y, month: m, day: d}, inherit_from, cldr_calendar) do
    year = y || inherit_from.year
    month = m || inherit_from.month
    day = d || inherit_from.day

    cond do
      is_nil(year) or is_nil(month) or is_nil(day) ->
        :error

      true ->
        with {:ok, calendar_module} <- resolve_calendar_module(cldr_calendar),
             {:ok, date} <- build_date(year, month, day, calendar_module) do
          {:ok, date}
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
    options = normalise_calendar_option(options)
    allow_inverted = Keyword.get(options, :allow_inverted, false)

    with {:ok, from_date} <- parse_or_wrap(from_string, options, :from_parse_failed),
         {:ok, to_date} <- parse_or_wrap(to_string, options, :to_parse_failed),
         {:ok, range} <- build_range(from_date, to_date, allow_inverted) do
      {:ok, range}
    end
  end

  defp parse_or_wrap(string, options, reason_tag) do
    # `Date.Range` supports any calendar as long as both
    # endpoints share the same one. We let `parse/2` return
    # whatever `:calendar` the caller asked for and rely on
    # both endpoints being parsed under the same option.
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

  defp try_iso(input, return_module) do
    case Date.from_iso8601(input) do
      {:ok, date} -> {:ok, convert_to(date, return_module)}
      _ -> :error
    end
  end

  # ── Locale patterns ──────────────────────────────────────────

  defp try_locale_patterns(input, locale, cldr_calendar, reference_year, return_module) do
    with {:ok, calendar_module} <- resolve_calendar_module(cldr_calendar),
         {:ok, available} <- Format.available_formats(locale, cldr_calendar),
         {:ok, months_data} <- LCalendar.months(locale, cldr_calendar) do
      eras_data = maybe_load_eras(locale, cldr_calendar)
      quarters_data = maybe_load_quarters(locale, cldr_calendar)
      days_data = maybe_load_days(locale, cldr_calendar)
      lenient = load_lenient_date(locale)
      transliterated = transliterate_digits(input, locale)
      patterns = collect_patterns(available)

      ctx = %{
        quarters: quarters_data,
        days: days_data,
        locale: locale,
        cldr_calendar: cldr_calendar
      }

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
                 cldr_calendar,
                 ctx
               ) do
            {:ok, date} -> {:ok, convert_to(date, return_module)}
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

  # The `:calendar` option accepts either a CLDR calendar type
  # atom (`:gregorian`, `:hebrew`, …) or a calendar module
  # (`Calendar.ISO`, `Calendrical.Hebrew`, …). Modules are
  # coerced to their CLDR atom via the `cldr_calendar_type/0`
  # callback; `Calendar.ISO` is the stdlib alias for
  # proleptic-Gregorian and maps to `:gregorian`.
  @doc false
  def normalise_calendar_option(options) do
    case Keyword.fetch(options, :calendar) do
      :error -> options
      {:ok, value} -> Keyword.put(options, :calendar, normalise_calendar(value))
    end
  end

  @doc false
  def normalise_calendar(Calendar.ISO), do: :gregorian

  def normalise_calendar(value) when is_atom(value) do
    if Code.ensure_loaded?(value) and function_exported?(value, :cldr_calendar_type, 0) do
      value.cldr_calendar_type()
    else
      value
    end
  end

  def normalise_calendar(other), do: other

  # Convert `date` into `target_module`, gracefully degrading
  # on conversion failure (returns the original date so the
  # parse still succeeds — better than turning a successful
  # parse into an error over a calendar arithmetic edge case).
  defp convert_to(%Date{calendar: target} = date, target), do: date

  defp convert_to(%Date{} = date, target_module) do
    case Date.convert(date, target_module) do
      {:ok, converted} -> converted
      _ -> date
    end
  end

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

  defp maybe_load_quarters(locale, calendar) do
    case LCalendar.quarters(locale, calendar) do
      {:ok, data} -> data
      _ -> %{}
    end
  end

  defp maybe_load_days(locale, calendar) do
    case LCalendar.days(locale, calendar) do
      {:ok, data} -> data
      _ -> %{}
    end
  end

  # Iterate every parseable CLDR pattern in `availableFormats`.
  # CLDR's `dateStyle` standards (`:short`/`:medium`/`:long`/
  # `:full`) are just references INTO `availableFormats` —
  # `:medium` for en is `:yMMMd`, and `:yMMMd` is itself a
  # key in `availableFormats`. So iterating
  # `availableFormats` covers the standard four AND the
  # broader skeleton set in one pass.
  #
  # Skeletons that lack the fields needed to build a Date
  # (year-only patterns, weekday-only patterns, etc.) won't
  # successfully construct one and fall through naturally.
  defp collect_patterns(available) do
    for {skeleton, pattern_data} <- available,
        pattern <- resolve_pattern_variants(pattern_data),
        do: {skeleton, pattern}
  end

  defp resolve_pattern_variants(nil), do: []
  defp resolve_pattern_variants(pattern) when is_binary(pattern), do: [pattern]

  defp resolve_pattern_variants(%{variant: variant, standard: standard})
       when is_binary(variant) and is_binary(standard),
       do: [variant, standard]

  defp resolve_pattern_variants(%{format: pattern}) when is_binary(pattern),
    do: [pattern]

  # Plural-variant maps (CLDR `availableFormats` ships some
  # week-bearing skeletons as `%{other: ..., one: ..., few:
  # ..., many: ..., zero: ..., two: ...}`). Dedupe binaries
  # across all variants.
  defp resolve_pattern_variants(%{} = map) do
    map
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

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

  defp cldr_letter?(char) when char in ~w(y Y M d E G L c Q q w W D e F), do: true
  defp cldr_letter?(_), do: false

  defp compile_regex(tokens, months_data, eras_data, lenient, ctx) do
    parts = build_regex_parts(tokens, months_data, eras_data, lenient, "", ctx)
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
  defp build_regex_parts(tokens, months_data, eras_data, lenient, prefix, ctx) do
    tokens
    |> Enum.reduce({[], nil}, fn token, {acc, prev_kind} ->
      {kind, regex} =
        case field_regex(token, months_data, eras_data, lenient, ctx) do
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

  defp field_regex({:lit, text}, _months, _eras, lenient, _ctx) do
    {:plain, expand_literal(text, lenient)}
  end

  defp field_regex({:y, count}, _months, _eras, _lenient, _ctx) do
    regex =
      case count do
        2 -> "(?P<year>\\d{2})"
        _ -> "(?P<year>\\d{1,4})"
      end

    {:capture, :year, regex}
  end

  # `Y` is the *week-based* year — used jointly with `w`
  # (week of year). Distinct named capture so the field
  # extractor can route it through the week-numbering
  # builder rather than the calendar-year builder.
  defp field_regex({:Y, count}, _months, _eras, _lenient, _ctx) do
    regex =
      case count do
        2 -> "(?P<week_based_year>\\d{2})"
        _ -> "(?P<week_based_year>\\d{1,4})"
      end

    {:capture, :week_based_year, regex}
  end

  defp field_regex({:M, count}, _months, _eras, _lenient, _ctx) when count <= 2 do
    {:capture, :month, "(?P<month>\\d{1,2})"}
  end

  defp field_regex({:M, count}, months, _eras, _lenient, _ctx) when count in 3..5 do
    {:capture, :month, month_name_regex(months, @month_name_widths[count])}
  end

  defp field_regex({:L, count}, months, eras, lenient, ctx),
    do: field_regex({:M, count}, months, eras, lenient, ctx)

  defp field_regex({:d, _count}, _months, _eras, _lenient, _ctx) do
    {:capture, :day, "(?P<day>\\d{1,2})"}
  end

  # `D` — day of year. 1..366 across the standard range.
  defp field_regex({:D, _count}, _months, _eras, _lenient, _ctx) do
    {:capture, :day_of_year, "(?P<day_of_year>\\d{1,3})"}
  end

  # `w` — week of year. 1..53.
  defp field_regex({:w, _count}, _months, _eras, _lenient, _ctx) do
    {:capture, :week_of_year, "(?P<week_of_year>\\d{1,2})"}
  end

  # `W` — week of month. 1..6.
  defp field_regex({:W, _count}, _months, _eras, _lenient, _ctx) do
    {:capture, :week_of_month, "(?P<week_of_month>\\d)"}
  end

  # `F` — day-of-week-in-month, e.g. "2nd Tuesday". The
  # numeric value alone (without an accompanying `E`) doesn't
  # uniquely identify a date; capture and surface to the
  # builder which combines it with month + weekday.
  defp field_regex({:F, _count}, _months, _eras, _lenient, _ctx) do
    {:capture, :day_of_week_in_month, "(?P<day_of_week_in_month>\\d)"}
  end

  # `e` — local day of week, format context. Width 1..2 is
  # numeric (in the locale's `firstDayOfWeek`-relative
  # numbering, so 1 = the locale's first day, not always
  # Monday). Width 3..6 matches the locale's day names.
  defp field_regex({:e, count}, _months, _eras, _lenient, _ctx) when count <= 2 do
    {:capture, :day_of_week_numeric, "(?P<day_of_week_numeric>\\d{1,2})"}
  end

  defp field_regex({:e, count}, _months, _eras, _lenient, ctx) when count in 3..6 do
    days_data = Map.get(ctx, :days)
    day_name_field(days_data, day_name_width(count), :format)
  end

  # `c` — standalone day of week. Same widths as `e`. `cc`
  # is not used in CLDR (singular `c` is rare too); fall
  # back to numeric on widths 1..2.
  defp field_regex({:c, count}, _months, _eras, _lenient, _ctx) when count <= 2 do
    {:capture, :day_of_week_numeric, "(?P<day_of_week_numeric>\\d{1,2})"}
  end

  defp field_regex({:c, count}, _months, _eras, _lenient, ctx) when count in 3..6 do
    days_data = Map.get(ctx, :days)
    day_name_field(days_data, day_name_width(count), :stand_alone)
  end

  # `E` — day of week (format context). Width 1..3 ⇒
  # abbreviated, 4 ⇒ wide, 5 ⇒ narrow, 6 ⇒ short. Captured
  # so the builder can validate the weekday matches the
  # constructed date.
  defp field_regex({:E, count}, _months, _eras, _lenient, ctx) do
    days_data = Map.get(ctx, :days)
    day_name_field(days_data, day_name_width(count), :format)
  end

  # `Q` / `q` — quarter (format / standalone). Widths 1..2
  # numeric, 3..4 names (e.g. "Q1" / "1st quarter"), 5 narrow.
  defp field_regex({letter, count}, _months, _eras, _lenient, _ctx)
       when letter in [:Q, :q] and count <= 2 do
    {:capture, :quarter, "(?P<quarter>\\d)"}
  end

  defp field_regex({letter, count}, _months, _eras, _lenient, ctx)
       when letter in [:Q, :q] and count in 3..5 do
    quarters_data = Map.get(ctx, :quarters)
    context = if letter == :Q, do: :format, else: :stand_alone
    quarter_name_field(quarters_data, quarter_name_width(count), context)
  end

  # Era marker. Try to capture against the locale's era names
  # so we can resolve era → year offset for Japanese imperial.
  # If no era names are available, fall back to tolerate-and-skip.
  defp field_regex({:G, count}, _months, eras, _lenient, _ctx) do
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

    # `(?i:...)` per CLDR TR35 §6.5 — month-name matching is
    # case-insensitive, so French "Mai" matches lowercase "mai"
    # in CLDR data, English "MAY" matches "May", etc.
    "(?i:" <> Enum.join(branches, "|") <> ")"
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

      {:branches, "(?i:" <> Enum.join(branches, "|") <> ")"}
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

  # CLDR width map for `E`/`e`/`c` letters.
  defp day_name_width(1), do: :abbreviated
  defp day_name_width(2), do: :abbreviated
  defp day_name_width(3), do: :abbreviated
  defp day_name_width(4), do: :wide
  defp day_name_width(5), do: :narrow
  defp day_name_width(6), do: :short
  defp day_name_width(_), do: :abbreviated

  # CLDR width map for `Q`/`q` letters.
  defp quarter_name_width(3), do: :abbreviated
  defp quarter_name_width(4), do: :wide
  defp quarter_name_width(5), do: :narrow
  defp quarter_name_width(_), do: :abbreviated

  # Build a regex branch for day-of-week names. Capture the
  # ISO weekday index (1 = Monday … 7 = Sunday) so the
  # builder can validate or derive a date from it.
  defp day_name_field(days_data, width, context) when is_map(days_data) do
    inner =
      get_in(days_data, [context, width]) ||
        get_in(days_data, [:format, width]) ||
        %{}

    branches =
      inner
      |> Enum.filter(fn
        {index, name} when is_integer(index) and is_binary(name) -> true
        _ -> false
      end)
      |> Enum.sort_by(fn {_index, name} -> -byte_size(name) end)
      |> Enum.map(fn {index, name} ->
        "(?P<__d#{index}__>#{Regex.escape(name)})"
      end)

    case branches do
      [] -> {:plain, "[\\p{L}\\.]+"}
      _ -> {:capture, :day_of_week, "(?i:" <> Enum.join(branches, "|") <> ")"}
    end
  end

  defp day_name_field(_data, _width, _context),
    do: {:plain, "[\\p{L}\\.]+"}

  # Build a regex branch for quarter names. Capture the
  # quarter index 1..4 so the builder can derive the
  # quarter's first month.
  defp quarter_name_field(quarters_data, width, context) when is_map(quarters_data) do
    inner =
      get_in(quarters_data, [context, width]) ||
        get_in(quarters_data, [:format, width]) ||
        %{}

    branches =
      inner
      |> Enum.filter(fn
        {index, name} when is_integer(index) and is_binary(name) -> true
        _ -> false
      end)
      |> Enum.sort_by(fn {_index, name} -> -byte_size(name) end)
      |> Enum.map(fn {index, name} ->
        "(?P<__q#{index}__>#{Regex.escape(name)})"
      end)

    case branches do
      [] -> {:plain, "[\\p{L}\\d\\.\\s]+?"}
      _ -> {:capture, :quarter, "(?i:" <> Enum.join(branches, "|") <> ")"}
    end
  end

  defp quarter_name_field(_data, _width, _context),
    do: {:plain, "[\\p{L}\\d\\.\\s]+?"}

  # ── Matching ─────────────────────────────────────────────────

  defp match_pattern(
         input,
         pattern,
         months_data,
         eras_data,
         lenient,
         reference_year,
         calendar_module,
         cldr_calendar,
         ctx
       ) do
    tokens = tokenize_pattern(pattern)
    regex_string = compile_regex(tokens, months_data, eras_data, lenient, ctx)

    regex =
      case Regex.compile(regex_string, "u") do
        {:ok, r} -> r
        {:error, _} -> nil
      end

    with %Regex{} <- regex,
         %{} = caps <- Regex.named_captures(regex, input),
         {:ok, era_index} <- extract_era(caps),
         {:ok, fields} <-
           extract_fields(caps, reference_year, cldr_calendar, era_index, calendar_module) do
      build_date_smart(fields, calendar_module)
    else
      _ -> :error
    end
  end

  # Pull every field the parser knows about into a single
  # struct so `build_date_smart` can pick a reconstruction
  # strategy. Most patterns supply only a subset; the
  # strategy table below resolves which combination yields a
  # full Date.
  defp extract_fields(caps, reference_year, cldr_calendar, era_index, calendar_module) do
    with {:ok, year_in_calendar} <-
           extract_year_field(caps, reference_year, cldr_calendar),
         {:ok, calendar_year} <-
           resolve_calendar_year(year_in_calendar, era_index, cldr_calendar) do
      {:ok,
       %{
         year: calendar_year,
         month: extract_optional_month(caps),
         day: extract_optional_day(caps),
         quarter: extract_optional_quarter(caps),
         week_of_year: extract_optional_int(caps, "week_of_year"),
         week_of_month: extract_optional_int(caps, "week_of_month"),
         week_based_year: extract_optional_int(caps, "week_based_year"),
         day_of_year: extract_optional_int(caps, "day_of_year"),
         day_of_week: extract_optional_day_of_week(caps),
         day_of_week_in_month: extract_optional_int(caps, "day_of_week_in_month"),
         weekday_name_index: extract_optional_weekday_name(caps),
         calendar_module: calendar_module,
         cldr_calendar: cldr_calendar
       }}
    end
  end

  # The 2-digit-year pivot is a Gregorian convention. For era-
  # aware calendars (Japanese imperial, ROC, etc.) the year
  # value is meant literally (`平成12年` = Heisei year 12,
  # not "the year '12 ≈ 2012"), so pivoting would corrupt the
  # input.
  # Year field is required by `extract_fields`. Falls back to
  # the reference year when no `y`/`Y` was captured (so
  # patterns like `MMM d` parse against the current year).
  defp extract_year_field(caps, reference_year, cldr_calendar) do
    case Map.get(caps, "year") || Map.get(caps, "week_based_year") do
      raw when is_binary(raw) and raw != "" ->
        case Integer.parse(raw) do
          {n, ""} ->
            year =
              if cldr_calendar == :gregorian and String.length(raw) == 2 do
                pivot_year(n, reference_year)
              else
                n
              end

            {:ok, year}

          _ ->
            :error
        end

      _ ->
        {:ok, reference_year}
    end
  end

  defp pivot_year(two_digit, reference_year) do
    century_base = div(reference_year - 80, 100) * 100
    candidate = century_base + two_digit
    if candidate < reference_year - 80, do: candidate + 100, else: candidate
  end

  defp extract_optional_month(%{"month" => raw}) when raw != "" do
    case Integer.parse(raw) do
      {n, ""} when n in 1..13 -> n
      _ -> nil
    end
  end

  defp extract_optional_month(caps) do
    case Enum.find(caps, fn
           {"__m" <> _, value} -> value != ""
           _ -> false
         end) do
      {"__m" <> rest, _value} ->
        case String.split(rest, "__", parts: 2) do
          [index_str, _] ->
            case Integer.parse(index_str) do
              {n, ""} when n in 1..13 -> n
              _ -> nil
            end

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

  defp extract_optional_day(%{"day" => raw}) when raw != "" do
    case Integer.parse(raw) do
      {n, ""} when n in 1..31 -> n
      _ -> nil
    end
  end

  defp extract_optional_day(_), do: nil

  # Quarter capture comes in two flavors: numeric capture
  # under `quarter`, or one of the named branches
  # `__q1__` / `__q2__` / `__q3__` / `__q4__`. Return
  # 1..4 or `nil`.
  defp extract_optional_quarter(caps) do
    case Map.get(caps, "quarter") do
      raw when is_binary(raw) and raw != "" ->
        case Integer.parse(raw) do
          {n, ""} when n in 1..4 -> n
          _ -> nil
        end

      _ ->
        case Enum.find(caps, fn
               {"__q" <> _, value} -> value != ""
               _ -> false
             end) do
          {"__q" <> rest, _value} ->
            case String.split(rest, "__", parts: 2) do
              [index_str, _] ->
                case Integer.parse(index_str) do
                  {n, ""} when n in 1..4 -> n
                  _ -> nil
                end

              _ ->
                nil
            end

          nil ->
            nil
        end
    end
  end

  defp extract_optional_int(caps, key) do
    case Map.get(caps, key) do
      raw when is_binary(raw) and raw != "" ->
        case Integer.parse(raw) do
          {n, ""} -> n
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # Day-of-week from numeric or name capture. Returns ISO
  # weekday 1..7 (Mon..Sun) or `nil`.
  defp extract_optional_day_of_week(caps) do
    cond do
      raw = Map.get(caps, "day_of_week_numeric") ->
        case raw do
          "" ->
            nil

          binary when is_binary(binary) ->
            case Integer.parse(binary) do
              {n, ""} when n in 1..7 -> n
              _ -> nil
            end

          _ ->
            nil
        end

      true ->
        case Enum.find(caps, fn
               {"__d" <> _, value} -> value != ""
               _ -> false
             end) do
          {"__d" <> rest, _value} ->
            case String.split(rest, "__", parts: 2) do
              [index_str, _] ->
                case Integer.parse(index_str) do
                  {n, ""} when n in 1..7 -> n
                  _ -> nil
                end

              _ ->
                nil
            end

          _ ->
            nil
        end
    end
  end

  # When an `E`/`c` weekday-name capture appears WITH a full
  # year/month/day, the parser should validate the supplied
  # weekday matches the computed date. Return the captured
  # weekday index (1..7) for the builder to check.
  defp extract_optional_weekday_name(caps) do
    case Enum.find(caps, fn
           {"__d" <> _, value} -> value != ""
           _ -> false
         end) do
      {"__d" <> rest, _value} ->
        case String.split(rest, "__", parts: 2) do
          [index_str, _] ->
            case Integer.parse(index_str) do
              {n, ""} when n in 1..7 -> n
              _ -> nil
            end

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

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

  # Pick a reconstruction strategy based on which fields the
  # pattern supplied. Strategies are ordered most-specific
  # first so partial-field patterns (e.g. `yQQQ` with no
  # month or day) don't get clobbered by a strategy that
  # demands fields they don't have.
  defp build_date_smart(fields, calendar_module) do
    cond do
      # Year + month + day given → standard path. Validate
      # weekday if also supplied.
      fields.year && fields.month && fields.day ->
        with {:ok, date} <- build_date(fields.year, fields.month, fields.day, calendar_module) do
          validate_weekday(date, fields)
        end

      # Year + day-of-year → date by adding (D-1) days to
      # Jan 1 of that year.
      fields.year && fields.day_of_year ->
        with {:ok, jan1} <- build_date(fields.year, 1, 1, calendar_module),
             %Date{} = date <- Date.add(jan1, fields.day_of_year - 1) do
          {:ok, date}
        else
          _ -> :error
        end

      # Week-based year + week of year + day of week → the
      # exact date.
      fields.week_based_year && fields.week_of_year && fields.day_of_week ->
        date_from_iso_week(
          fields.week_based_year,
          fields.week_of_year,
          fields.day_of_week,
          calendar_module
        )

      # Year + week of year + day of week — treat year as
      # week-based year. Common shape: `Y w E`.
      fields.year && fields.week_of_year && fields.day_of_week ->
        date_from_iso_week(
          fields.year,
          fields.week_of_year,
          fields.day_of_week,
          calendar_module
        )

      # Year + week of year only → first day of that week.
      fields.year && fields.week_of_year ->
        date_from_iso_week(fields.year, fields.week_of_year, 1, calendar_module)

      fields.week_based_year && fields.week_of_year ->
        date_from_iso_week(
          fields.week_based_year,
          fields.week_of_year,
          1,
          calendar_module
        )

      # Year + month + day-of-week-in-month → e.g. 2nd
      # Tuesday of June.
      fields.year && fields.month && fields.day_of_week && fields.day_of_week_in_month ->
        date_from_nth_weekday(
          fields.year,
          fields.month,
          fields.day_of_week,
          fields.day_of_week_in_month,
          calendar_module
        )

      # Year + quarter (no month) → first day of quarter.
      # Reasonable default for `yQQQ` skeletons.
      fields.year && fields.quarter ->
        month = (fields.quarter - 1) * 3 + 1
        build_date(fields.year, month, 1, calendar_module)

      true ->
        :error
    end
  end

  # Verify the `E`/`c` weekday name (if any was captured)
  # matches the date's actual weekday. Mismatch → :error so
  # the parser backtracks to try a different pattern.
  defp validate_weekday(date, %{day_of_week: nil, weekday_name_index: nil}), do: {:ok, date}

  defp validate_weekday(date, %{day_of_week: nil, weekday_name_index: idx})
       when is_integer(idx) do
    if Date.day_of_week(date) == idx, do: {:ok, date}, else: :error
  end

  defp validate_weekday(date, %{day_of_week: dow}) when is_integer(dow) do
    if Date.day_of_week(date) == dow, do: {:ok, date}, else: :error
  end

  # Build a date from ISO 8601 week numbering (week 1 is the
  # week containing Jan 4). Compute in `Calendar.ISO` then
  # convert to the target calendar so we don't need
  # per-calendar week algorithms.
  defp date_from_iso_week(year, week, day_of_week, calendar_module)
       when week in 1..53 and day_of_week in 1..7 do
    with {:ok, jan4} <- Date.new(year, 1, 4),
         jan4_dow = Date.day_of_week(jan4),
         week1_monday = Date.add(jan4, -(jan4_dow - 1)),
         target = Date.add(week1_monday, (week - 1) * 7 + (day_of_week - 1)) do
      if calendar_module == Calendar.ISO do
        {:ok, target}
      else
        case Date.convert(target, calendar_module) do
          {:ok, converted} -> {:ok, converted}
          _ -> :error
        end
      end
    else
      _ -> :error
    end
  end

  defp date_from_iso_week(_, _, _, _), do: :error

  # Compute the Nth occurrence of `weekday` in `month` of
  # `year`. N is 1..5; if N exceeds the month's count of
  # that weekday, return :error.
  defp date_from_nth_weekday(year, month, weekday, n, calendar_module)
       when weekday in 1..7 and n in 1..5 do
    with {:ok, first_of_month} <- build_date(year, month, 1, calendar_module),
         first_dow = Date.day_of_week(first_of_month),
         offset_to_first_occurrence = rem(weekday - first_dow + 7, 7),
         day_number = offset_to_first_occurrence + 1 + (n - 1) * 7,
         {:ok, candidate} <- build_date(year, month, day_number, calendar_module) do
      {:ok, candidate}
    else
      _ -> :error
    end
  end

  defp date_from_nth_weekday(_, _, _, _, _), do: :error

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
