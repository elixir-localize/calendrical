defmodule Calendrical.DateTime do
  @moduledoc """
  DateTime parsing helpers built on Localize CLDR data and the
  existing `Calendrical.Date` / `Calendrical.Time` parsers.


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

  * `:calendar` — the calendar module the date portion is read in and returned in, such as `Calendar.ISO` (the default) or `Calendrical.Hebrew`. A CLDR calendar name such as `:hebrew` returns `Localize.UnknownCalendarError`.

  * `:as` — `:struct` (default) returns a `t:NaiveDateTime.t/0`
    or `t:DateTime.t/0`. `:map` returns a bare field map
    merging the date and time fields, with only what the input
    actually supplied (so `"May 5, 11:30 AM"` yields
    `%{month: 5, day: 5, hour: 11, minute: 30, calendar: …}`
    — no year, no second, no microsecond). A zone adds the
    four `t:DateTime.t/0` zone fields (`:time_zone`,
    `:utc_offset`, `:std_offset` and `:zone_abbr`) as the
    struct form resolves them: a fixed offset always, and a
    named zone when the input gives the full date its offset
    depends on; otherwise `:time_zone` holds the zone as
    written.

  ### Returns

  * `{:ok, NaiveDateTime.t()}` when no timezone information was
    present and `as: :struct` (the default).

  * `{:ok, DateTime.t()}` when the input carried a Z or
    `±HH:MM` offset that ISO-8601 could resolve and
    `as: :struct`.

  * `{:ok, map()}` when `as: :map`.

  * `{:error, Calendrical.DateTimeParseError.t() | …}` on
    failure. Sub-parse errors from `Calendrical.Date.parse/2`
    or `Calendrical.Time.parse/2` pass through.

  * `{:error, Localize.InvalidValueError.t()}` when `input` is not a string or an option is malformed.

  ### Examples

      iex> Calendrical.DateTime.parse("2026-05-16T14:30:00", locale: :en)
      {:ok, ~N[2026-05-16 14:30:00]}

      iex> Calendrical.DateTime.parse("May 16, 2026, 2:30 PM", locale: :en)
      {:ok, ~N[2026-05-16 14:30:00]}

      iex> Calendrical.DateTime.parse("16.05.2026, 14:30", locale: :de)
      {:ok, ~N[2026-05-16 14:30:00]}

      iex> Calendrical.DateTime.parse("May 5, 11:30 AM", locale: :en, as: :map)
      {:ok, %{calendar: Calendar.ISO, month: 5, day: 5, hour: 11, minute: 30}}

      iex> {:ok, map} = Calendrical.DateTime.parse("May 5, 11:30 AM GMT+5", locale: :en, as: :map)
      iex> Map.take(map, [:hour, :time_zone, :utc_offset])
      %{hour: 11, time_zone: "Etc/UTC", utc_offset: 18000}

  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok, NaiveDateTime.t() | DateTime.t() | map()} | {:error, Exception.t()}
  def parse(input, options \\ []) do
    with :ok <- Calendrical.ParseOptions.validate(input, options) do
      Calendrical.DateTime.Parser.parse(input, options)
    end
  end
end
