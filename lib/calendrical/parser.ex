defmodule Calendrical.Parser do
  @moduledoc """
  Unified locale-aware parser that dispatches user input to the
  appropriate domain parser (date, time, datetime, or date range).

  Public entry point: `Calendrical.parse/2`.

  ### Dispatch strategy

  The parser tries each sub-parser in the following order and
  returns the first success:

  1. **Interval** — only attempted when the input contains an
     interval-shaped separator (the locale's
     `intervalFormatFallback` separator, or one of `–`, `—`, `−`,
     `〜`, `~`, ` - `, ` / `, ` to `). Cheap fail-fast.

  2. **Date** — `Calendrical.Date.parse/2`. Whole-string
     anchored, so a date+time input won't accidentally match.

  3. **Time** — `Calendrical.Time.parse/2`. Whole-string
     anchored, so a date-only input won't match (no `:`).

  4. **DateTime** — `Calendrical.DateTime.parse/2`. The most
     expensive (it splits on every glue separator position and
     runs the date+time parsers on each half), so it runs last as
     a fallback for inputs that carry both a date and a time.

  The order encodes a tiebreaker preference: for ambiguous inputs
  (e.g. a bare 4-digit year that could be a date or a time) the
  date interpretation wins.

  """

  alias Localize.DateTime.Format
  alias Calendrical.ParseError

  @doc """
  Parses `input` as a date, time, datetime, or date range — whichever
  matches.

  See `Calendrical.parse/2` for the public contract.
  """
  @spec parse(String.t(), Keyword.t()) ::
          {:ok,
           Date.t()
           | Time.t()
           | NaiveDateTime.t()
           | DateTime.t()
           | Date.Range.t()}
          | {:error, Exception.t()}
  def parse(input, options \\ []) when is_binary(input) do
    options = Calendrical.Date.Parser.normalise_calendar_option(options)
    locale = Keyword.get(options, :locale) || Localize.get_locale()
    cldr_calendar = Keyword.get(options, :calendar, :gregorian)
    trimmed = String.trim(input)

    attempts = []

    with {:next, attempts} <-
           try_interval(trimmed, locale, cldr_calendar, options, attempts),
         {:next, attempts} <- try_date(trimmed, options, attempts),
         {:next, attempts} <- try_time(trimmed, options, attempts),
         {:next, attempts} <- try_datetime(trimmed, options, attempts) do
      {:error,
       ParseError.exception(
         input: input,
         locale: locale,
         attempts: Enum.reverse(attempts),
         message:
           "could not parse #{inspect(input)} as a date, time, datetime, " <>
             "or interval in locale #{inspect(locale)}"
       )}
    end
  end

  defp try_interval(input, locale, cldr_calendar, options, attempts) do
    if has_interval_separator?(input, locale, cldr_calendar) do
      case Calendrical.Date.parse_range(input, options) do
        {:ok, _} = ok -> ok
        {:error, err} -> {:next, [{:interval, err} | attempts]}
      end
    else
      {:next, attempts}
    end
  end

  defp try_date(input, options, attempts) do
    case Calendrical.Date.parse(input, options) do
      {:ok, _} = ok -> ok
      {:error, err} -> {:next, [{:date, err} | attempts]}
    end
  end

  defp try_time(input, options, attempts) do
    case Calendrical.Time.parse(input, options) do
      {:ok, _} = ok -> ok
      {:error, err} -> {:next, [{:time, err} | attempts]}
    end
  end

  defp try_datetime(input, options, attempts) do
    case Calendrical.DateTime.parse(input, options) do
      {:ok, _} = ok -> ok
      {:error, err} -> {:next, [{:datetime, err} | attempts]}
    end
  end

  # Cheap check: does the input contain an interval-shaped
  # separator? Mirrors the candidate list used by
  # `Calendrical.Date.Parser.split_on_interval_separator/3` so
  # that anything `parse_range/2` could match is also detected
  # here.
  defp has_interval_separator?(input, locale, cldr_calendar) do
    cldr_sep = lookup_interval_separator(locale, cldr_calendar)

    candidates =
      [cldr_sep | ["–", "—", "−", "〜", "~", " - ", " / ", " to "]]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.any?(candidates, fn sep ->
      case String.split(input, sep, parts: 2) do
        [left, right] -> String.trim(left) != "" and String.trim(right) != ""
        _ -> false
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
end
