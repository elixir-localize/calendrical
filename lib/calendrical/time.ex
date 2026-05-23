defmodule Calendrical.Time do
  @moduledoc """
  Time parsing helpers built on Localize's CLDR data.

  See `Calendrical.Time.Parser` for the parsing engine.

  When the caller doesn't know in advance whether the input is a
  date, time, datetime, or range, use `Calendrical.parse/2` — it
  dispatches to the appropriate sub-parser.

  """

  @doc """
  Parses a locale-formatted time string.

  Tries, in order: bare ISO-8601 (`HH:MM[:SS[.frac]]`), then
  the locale's CLDR short/medium/long/full time patterns.
  Locale patterns encode the locale's hour cycle (12-hour for
  `en`, `ar`; 24-hour for `de`, `fr`, `ja`) so the same input
  may parse to different times under different locales — by
  design.

  Implements the parts of TR35 §Parsing Dates Times and
  §Parsing Day Periods that apply to time-only input.

  ### Arguments

  * `input` is the raw user input string.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:as` — `:struct` (default) returns a `t:Time.t/0`.
    `:map` returns a bare field map containing only what the
    input actually supplied (`%{hour: 11}` for `"11 am"`,
    `%{hour: 11, minute: 30, time_zone: "PST"}` for
    `"11:30 PST"`). `:minute` and `:second` default to `0`
    only in `:struct` mode; in `:map` mode they are omitted
    unless captured. Microsecond is included only when the
    input carried fractional precision.

  ### Returns

  * `{:ok, Time.t()}` on success when `as: :struct` (the
    default).

  * `{:ok, map()}` on success when `as: :map`. The map
    always has `:hour`; `:minute`, `:second`, `:microsecond`,
    and `:time_zone` appear only when the input supplied
    them.

  * `{:error, Calendrical.TimeParseError.t()}` when no pattern
    matched.

  ### Examples

      iex> Calendrical.Time.parse("14:30:00", locale: :en)
      {:ok, ~T[14:30:00]}

      iex> Calendrical.Time.parse("2:30 PM", locale: :en)
      {:ok, ~T[14:30:00]}

      iex> Calendrical.Time.parse("14:30", locale: :de)
      {:ok, ~T[14:30:00]}

      iex> Calendrical.Time.parse("11 am", locale: :en, as: :map)
      {:ok, %{hour: 11}}

      iex> Calendrical.Time.parse("11:30", locale: :en, as: :map)
      {:ok, %{hour: 11, minute: 30}}

  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, Time.t() | map()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    Calendrical.Time.Parser.parse(input, options)
  end
end
