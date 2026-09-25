defmodule Calendrical.Date do
  @moduledoc """
  Locale-aware date parsing for Calendrical's calendars.

  Parsing is implemented by Localize: `parse/2` delegates to
  `Localize.Date.parse/2` and `parse_range/2` to
  `Localize.Interval.parse/2`. Dates are returned in the Calendrical
  calendar named by the `:calendar` option.

  When the caller doesn't know in advance whether the input is a
  date, time, datetime, or range, use `Calendrical.parse/2`.

  """

  @doc """
  Parses a locale-formatted date string. Delegates to `Localize.Date.parse/2`.

  Tries, in order: bare ISO-8601 (`YYYY-MM-DD`), then the
  locale's CLDR short/medium/long/full patterns for the
  requested calendar. The patterns encode the locale's
  preferred field order and any era markers — so the same
  input may parse to different dates under different locales
  by design.

  Returns a `t:Date.t/0` in the `:calendar` module, `Calendar.ISO` by default. Convert it with `Date.convert/2` when a consumer needs another calendar, such as `Calendar.ISO` for a `Date.Range` or an Ecto `:date` field.

  ### Arguments

  * `input` is the raw user input string.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:calendar` — the calendar module the input is read in and the date is returned in, such as `Calendar.ISO` (the default), `Calendrical.Gregorian` or `Calendrical.Hebrew`. A CLDR calendar name such as `:hebrew` is not a calendar and returns `Localize.UnknownCalendarError`.

  * `:reference_date` — the "today" anchor for two-digit-year
    pivoting. Defaults to `Date.utc_today/0`.

  * `:as` — `:struct` (default) returns a `t:Date.t/0`.
    `:map` returns a bare field map containing only what the
    input actually supplied (`%{month: 5, day: 5, calendar:
    Calendar.ISO}` for `"May 5"`) plus a `:calendar` key
    naming the resolved calendar module. Useful when a
    downstream library (e.g.
    [`Tempo`](https://github.com/elixir-localize/tempo))
    needs the unresolved partial rather than a defaulted
    `Date`. In `:map` mode the `:reference_date` fallback for
    missing-year inputs is suppressed.

  ### Returns

  * `{:ok, Date.t()}` on success when `as: :struct` (the
    default).

  * `{:ok, map()}` on success when `as: :map`. The map
    always has a `:calendar` key; the other keys
    (`:year`, `:month`, `:day`, `:quarter`,
    `:week_of_year`, `:week_based_year`, `:day_of_year`,
    `:day_of_week`, `:day_of_week_in_month`) are present
    only when the input supplied them.

  * `{:error, Localize.DateParseError.t()}` when no
    pattern matched.

  ### Examples

      iex> Calendrical.Date.parse("2026-05-16", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("May 5", locale: :en, as: :map)
      {:ok, %{calendar: Calendar.ISO, month: 5, day: 5}}

      iex> Calendrical.Date.parse("2026", locale: :en, as: :map)
      {:ok, %{calendar: Calendar.ISO, year: 2026}}

      iex> Calendrical.Date.parse("5/16/26", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("16.05.2026", locale: :de)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("2026-05-16", locale: :en, calendar: Calendrical.Hebrew)
      {:ok, ~D[5786-08-29 Calendrical.Hebrew]}

      iex> {:ok, date} = Calendrical.Date.parse("2026-05-16", locale: :en, calendar: Calendrical.Hebrew)
      iex> Date.convert(date, Calendar.ISO)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("Q2 2026", locale: :en)
      {:ok, ~D[2026-04-01]}

      iex> Calendrical.Date.parse("2nd quarter 2026", locale: :en)
      {:ok, ~D[2026-04-01]}

      iex> Calendrical.Date.parse("week 20 of 2026", locale: :en)
      {:ok, ~D[2026-05-10]}

      iex> Calendrical.Date.parse("Saturday, May 16, 2026", locale: :en)
      {:ok, ~D[2026-05-16]}

  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, Date.t() | map()} | {:error, Exception.t()}
  defdelegate parse(input, options \\ []), to: Localize.Date

  @doc """
  Parses a locale-formatted date range. Delegates to `Localize.Interval.parse/2`.

  Accepts either a single string (e.g. `"May 5 – May 10, 2026"`)
  in which case the parser splits on the locale's CLDR
  `intervalFormatFallback` separator, **or** a 2-tuple
  `{from_string, to_string}` for two-input UIs that already
  have the endpoints split.

  Each endpoint is parsed independently via `parse/2`. The
  result is always a `t:Date.Range.t/0`; the calendar of the
  range's endpoints follows the `:calendar` option (defaults
  to `:gregorian`, i.e. `Calendar.ISO`). `Date.Range` supports
  any calendar provided both endpoints share it — both
  endpoints are parsed under the same option, so the range is
  well-formed for Buddhist, Hebrew, Japanese, Persian, and
  every other Calendrical-supported calendar.

  ### Arguments

  * `input` is either a binary or a `{from_binary, to_binary}`
    tuple.

  * `options` is a keyword list of options.

  ### Options

  Same as `parse/2`: `:locale`, `:calendar`, `:reference_date`,
  `:as`. Plus:

  * `:allow_inverted` — when `true`, an end-before-start
    range is returned as-is (Elixir's
    `Date.range/3` builds a descending range). When `false`
    (the default), an inverted range is rejected with a
    `Localize.DateRangeParseError`. Only applies when
    `as: :struct` (the default); `as: :map` skips the
    comparison because partial maps may not have enough
    fields to compare.

  ### Returns

  * `{:ok, Date.Range.t()}` on success when `as: :struct`.
    The endpoints' calendar matches the `:calendar` option.

  * `{:ok, {from_map, to_map}}` on success when `as: :map`.
    Each endpoint is a field map; missing fields are
    inherited from the other endpoint per the CLDR interval
    convention (so `"May 5 – May 10, 2026"` yields two maps
    both carrying `:year`).

  * `{:error, Localize.DateParseError.t() |
    Localize.DateRangeParseError.t()}` on failure.

  ### Examples

      iex> {:ok, range} = Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"})
      iex> {range.first, range.last}
      {~D[2026-05-05], ~D[2026-05-10]}

      iex> Calendrical.Date.parse_range("May 5 – May 10, 2026", locale: :en, as: :map)
      {:ok,
       {%{calendar: Calendar.ISO, year: 2026, month: 5, day: 5},
        %{calendar: Calendar.ISO, year: 2026, month: 5, day: 10}}}

      iex> {:ok, range} = Calendrical.Date.parse_range("May 5, 2026 – May 10, 2026", locale: :en)
      iex> {range.first, range.last}
      {~D[2026-05-05], ~D[2026-05-10]}

      iex> {:ok, range} = Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"}, calendar: Calendrical.Buddhist)
      iex> {range.first, range.last}
      {~D[2569-05-05 Calendrical.Buddhist], ~D[2569-05-10 Calendrical.Buddhist]}

      iex> {:ok, range} = Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"}, calendar: Calendrical.Buddhist)
      iex> {range.first, range.last}
      {~D[2569-05-05 Calendrical.Buddhist], ~D[2569-05-10 Calendrical.Buddhist]}

  """
  @spec parse_range(String.t() | {String.t(), String.t()}, Keyword.t()) ::
          {:ok, Date.Range.t() | {map(), map()}} | {:error, Exception.t()}
  defdelegate parse_range(input, options \\ []), to: Localize.Interval, as: :parse
end
