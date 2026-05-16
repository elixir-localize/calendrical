defmodule Calendrical.Date do
  @moduledoc """
  Date parsing and helpers built on Calendrical's calendar
  implementations and Localize's CLDR data.

  See `Calendrical.Date.Parser` for the parsing engine details.

  """

  @doc """
  Parses a locale-formatted date string.

  Tries, in order: bare ISO-8601 (`YYYY-MM-DD`), then the
  locale's CLDR short/medium/long/full patterns for the
  requested calendar. The patterns encode the locale's
  preferred field order and any era markers — so the same
  input may parse to different dates under different locales
  by design.

  Returns a `t:Date.t/0`. By default (with `return_calendar:
  :iso`), the result is in `Calendar.ISO` (Gregorian); pass
  `return_calendar: :native` to receive the date in its input
  calendar (e.g. a `Calendrical.Islamic.Civil` date).

  ### Arguments

  * `input` is the raw user input string.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:calendar` — the CLDR calendar key (e.g. `:gregorian`,
    `:buddhist`, `:islamic_civil`, `:japanese`, `:persian`,
    `:hebrew`). Defaults to `:gregorian`.

  * `:reference_date` — the "today" anchor for two-digit-year
    pivoting. Defaults to `Date.utc_today/0`.

  * `:return_calendar` — `:iso` (default) converts the result
    to Gregorian. `:native` keeps it in the input calendar.

  ### Returns

  * `{:ok, Date.t()}` on success.

  * `{:error, Calendrical.DateParseError.t()}` when no
    pattern matched.

  ### Examples

      iex> Calendrical.Date.parse("2026-05-16", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("5/16/26", locale: :en)
      {:ok, ~D[2026-05-16]}

      iex> Calendrical.Date.parse("16.05.2026", locale: :de)
      {:ok, ~D[2026-05-16]}

  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    Calendrical.Date.Parser.parse(input, options)
  end

  @doc """
  Parses a locale-formatted date range.

  Accepts either a single string (e.g. `"May 5 – May 10, 2026"`)
  in which case the parser splits on the locale's CLDR
  `intervalFormatFallback` separator, **or** a 2-tuple
  `{from_string, to_string}` for two-input UIs that already
  have the endpoints split.

  Each endpoint is parsed independently via `parse/2`. The
  result is a `t:Date.Range.t/0` (Gregorian).

  ### Arguments

  * `input` is either a binary or a `{from_binary, to_binary}`
    tuple.

  * `options` is a keyword list of options.

  ### Options

  Same as `parse/2`: `:locale`, `:calendar`, `:reference_date`.
  Plus:

  * `:allow_inverted` — when `true`, an end-before-start
    range is returned as-is (Elixir's
    `Date.range/3` builds a descending range). When `false`
    (the default), an inverted range is rejected with a
    `Calendrical.DateRangeParseError`.

  ### Returns

  * `{:ok, Date.Range.t()}` on success.

  * `{:error, Calendrical.DateParseError.t() |
    Calendrical.DateRangeParseError.t()}` on failure.

  ### Examples

      iex> {:ok, range} = Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"})
      iex> {range.first, range.last}
      {~D[2026-05-05], ~D[2026-05-10]}

      iex> {:ok, range} = Calendrical.Date.parse_range("May 5, 2026 – May 10, 2026", locale: :en)
      iex> {range.first, range.last}
      {~D[2026-05-05], ~D[2026-05-10]}

  """
  @spec parse_range(String.t() | {String.t(), String.t()}, Keyword.t()) ::
          {:ok, Date.Range.t()} | {:error, Exception.t()}
  def parse_range(input, options \\ [])

  def parse_range({from_string, to_string}, options)
      when is_binary(from_string) and is_binary(to_string) do
    Calendrical.Date.Parser.parse_range_pair(from_string, to_string, options)
  end

  def parse_range(input, options) when is_binary(input) do
    Calendrical.Date.Parser.parse_range(input, options)
  end
end
