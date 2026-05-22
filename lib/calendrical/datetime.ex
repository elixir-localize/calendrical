defmodule Calendrical.DateTime do
  @moduledoc """
  DateTime parsing helpers built on Localize CLDR data and the
  existing `Calendrical.Date` / `Calendrical.Time` parsers.

  See `Calendrical.DateTime.Parser` for the parsing engine.

  When the caller doesn't know in advance whether the input is a
  date, time, datetime, or range, use `Calendrical.parse/2` — it
  dispatches to the appropriate sub-parser.

  """

  @doc """
  Parses a locale-formatted datetime string.

  Tries, in order: bare ISO-8601 (`YYYY-MM-DDTHH:MM:SS[Z|±HH:MM]`),
  then the locale's CLDR date-time glue pattern (`{1}, {0}` in
  `en`, `{1} {0}` in `ja`, etc.). The glue separator splits the
  input into date and time portions; each half is parsed by
  `Calendrical.Date.parse/2` and `Calendrical.Time.parse/2`.

  ### Arguments

  * `input` is the raw user input string.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:calendar` — the CLDR calendar key for the date portion.
    Defaults to `:gregorian`.

  ### Returns

  * `{:ok, NaiveDateTime.t()}` when no timezone information was
    present.

  * `{:ok, DateTime.t()}` when the input carried a Z or
    `±HH:MM` offset that ISO-8601 could resolve.

  * `{:error, Calendrical.DateTimeParseError.t() | …}` on
    failure. Sub-parse errors from `Calendrical.Date.parse/2`
    or `Calendrical.Time.parse/2` pass through.

  ### Examples

      iex> Calendrical.DateTime.parse("2026-05-16T14:30:00", locale: :en)
      {:ok, ~N[2026-05-16 14:30:00]}

      iex> Calendrical.DateTime.parse("May 16, 2026, 2:30 PM", locale: :en)
      {:ok, ~N[2026-05-16 14:30:00]}

      iex> Calendrical.DateTime.parse("16.05.2026, 14:30", locale: :de)
      {:ok, ~N[2026-05-16 14:30:00]}

  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, NaiveDateTime.t() | DateTime.t()} | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    Calendrical.DateTime.Parser.parse(input, options)
  end
end
