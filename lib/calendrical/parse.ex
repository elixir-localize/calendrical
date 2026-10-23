defmodule Calendrical.Parse do
  @moduledoc false

  # Every error here is an atom, not an exception: these functions answer the
  # `Calendar` parse callbacks, whose contract is `{:error, atom}`, and
  # `Date.from_iso8601/2` and the others read the atom.
  # credo:disable-for-this-file Calendrical.Credo.ErrorTuple

  @split_reg "[\\sT]"

  @doc false
  # `:return_calendar` was removed in 2.0: the date is returned in the
  # `:calendar` it is parsed in. Localize ignores an option it does not know,
  # so a 1.x caller passing it would silently get a date in another calendar;
  # it is refused instead.
  def refuse_removed_options(options) do
    if Keyword.keyword?(options) and Keyword.has_key?(options, :return_calendar),
      do: {:error, Calendrical.RemovedOptionError.exception(option: :return_calendar)},
      else: :ok
  end

  def parse_date(<<"-", year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, calendar) do
    return_date({"-", year}, month, day, calendar)
  end

  def parse_date(<<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, calendar) do
    return_date({"", year}, month, day, calendar)
  end

  # An explicit `+` before a four-digit year, as `Calendar.ISO` reads it.
  def parse_date(<<"+", year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, calendar) do
    return_date({"", year}, month, day, calendar)
  end

  # A calendar of weeks reads a date written as a week date ("2026-W25-2")
  # as the date its week-date callback gives it, as well as one written as
  # a year, a month and a day. It wrote its dates as week dates before 2.0.
  # Text in no date's shape is `:invalid_format`, as `Calendar.ISO` answers.
  def parse_date(string, calendar) do
    if calendar.info().structure == :weeks,
      do: week_notation(string, calendar),
      else: {:error, :invalid_format}
  end

  @doc false
  def parse_week_date(string, calendar), do: parse_date(string, calendar)

  defp week_notation(<<"-", year::bytes-4, "-W", week::bytes-2, "-", day::bytes-1>>, calendar) do
    return_week_date({"-", year}, week, day, calendar)
  end

  defp week_notation(<<year::bytes-4, "-W", week::bytes-2, "-", day::bytes-1>>, calendar) do
    return_week_date({"", year}, week, day, calendar)
  end

  defp week_notation(_string, _calendar), do: {:error, :invalid_format}

  defp return_week_date({sign, year}, week, day, calendar) do
    if digits?(year) and digits?(week) and digits?(day) do
      year = String.to_integer(sign <> year)

      case calendar.date_from_week_date(year, String.to_integer(week), String.to_integer(day)) do
        %Date{year: year, month: month, day: day} -> {:ok, {year, month, day}}
        {:error, _reason} -> {:error, :invalid_date}
      end
    else
      {:error, :invalid_format}
    end
  end

  # The fields are digits or the text is no date, and the date is checked
  # with its sign, as a year before 1 is a year of its own.
  defp return_date({sign, year}, month, day, calendar) do
    if digits?(year) and digits?(month) and digits?(day) do
      year = String.to_integer(sign <> year)
      month = String.to_integer(month)
      day = String.to_integer(day)

      if calendar.valid_date?(year, month, day) do
        {:ok, {year, month, day}}
      else
        {:error, :invalid_date}
      end
    else
      {:error, :invalid_format}
    end
  end

  defp digits?(<<digit, rest::binary>>) when digit in ?0..?9, do: rest == "" or digits?(rest)
  defp digits?(_text), do: false

  [match_time, guard_time, read_time] =
    quote do
      [
        <<h1, h2, ?:, i1, i2, ?:, s1, s2>>,
        h1 >= ?0 and h1 <= ?9 and h2 >= ?0 and h2 <= ?9 and i1 >= ?0 and i1 <= ?9 and i2 >= ?0 and
          i2 <= ?9 and s1 >= ?0 and s1 <= ?9 and s2 >= ?0 and s2 <= ?9,
        {
          (h1 - ?0) * 10 + (h2 - ?0),
          (i1 - ?0) * 10 + (i2 - ?0),
          (s1 - ?0) * 10 + (s2 - ?0)
        }
      ]
    end

  defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO
  defdelegate add_day_fraction_to_iso_days(fraction, offset, microseconds), to: Calendar.ISO
  defdelegate time_from_day_fraction(fraction), to: Calendar.ISO
  defdelegate date_to_iso_days(year, month, day), to: Calendar.ISO

  @doc false
  def parse_naive_datetime(string, calendar) do
    case String.split(string, ~r/#{@split_reg}/) do
      [date, time] ->
        with {:ok, {year, month, day}} <- calendar.parse_date(date),
             {:ok, {hour, minute, second, microsecond}} <- calendar.parse_time(time) do
          {:ok, {year, month, day, hour, minute, second, microsecond}}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc false
  def parse_utc_datetime(string, calendar) do
    case String.split(string, ~r/#{@split_reg}/) do
      [date, time_and_offset] ->
        with {:ok, time, microsecond, offset} <- time_and_offset(time_and_offset),
             {:ok, date} <- calendar.parse_date(date) do
          utc_datetime(calendar, date, time, microsecond, offset)
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  # The time of day, its fraction of a second and its offset from UTC, all
  # written, or the text is no time and offset.
  defp time_and_offset(<<unquote(match_time), rest::binary>>) when unquote(guard_time) do
    with {:ok, microsecond, rest} <- microsecond(rest),
         {:ok, offset} <- offset(rest) do
      {:ok, unquote(read_time), microsecond, offset}
    end
  end

  defp time_and_offset(_text), do: {:error, :invalid_format}

  defp microsecond(text) do
    case parse_microsecond(text) do
      {microsecond, rest} -> {:ok, microsecond, rest}
      :error -> {:error, :invalid_format}
    end
  end

  defp offset(text) do
    case parse_offset(text) do
      {offset, ""} -> {:ok, offset}
      _not_an_offset -> {:error, :invalid_format}
    end
  end

  # A date and time at an offset, as the date and time at UTC.
  defp utc_datetime(calendar, {year, month, day}, {hour, minute, second}, microsecond, offset) do
    cond do
      not calendar.valid_time?(hour, minute, second, microsecond) ->
        {:error, :invalid_time}

      offset == 0 ->
        {:ok, {year, month, day, hour, minute, second, microsecond}, offset}

      is_nil(offset) ->
        {:error, :missing_offset}

      true ->
        day_fraction = time_to_day_fraction(hour, minute, second, {0, 0})

        {{year, month, day}, {hour, minute, second, _}} =
          case add_day_fraction_to_iso_days({0, day_fraction}, -offset, 86_400) do
            {0, day_fraction} ->
              {{year, month, day}, time_from_day_fraction(day_fraction)}

            {extra_days, day_fraction} ->
              base_days = calendar.date_to_iso_days(year, month, day)

              {calendar.date_from_iso_days(base_days + extra_days),
               time_from_day_fraction(day_fraction)}
          end

        {:ok, {year, month, day, hour, minute, second, microsecond}, offset}
    end
  end

  defp parse_microsecond("." <> rest) do
    case parse_microsecond(rest, 0, "") do
      {"", 0, _} ->
        :error

      {microsecond, precision, rest} when precision in 1..6 ->
        pad = String.duplicate("0", 6 - byte_size(microsecond))
        {{String.to_integer(microsecond <> pad), precision}, rest}

      {microsecond, _precision, rest} ->
        {{String.to_integer(binary_part(microsecond, 0, 6)), 6}, rest}
    end
  end

  defp parse_microsecond("," <> rest) do
    parse_microsecond("." <> rest)
  end

  defp parse_microsecond(rest) do
    {{0, 0}, rest}
  end

  defp parse_microsecond(<<head, tail::binary>>, precision, acc) when head in ?0..?9,
    do: parse_microsecond(tail, precision + 1, <<acc::binary, head>>)

  defp parse_microsecond(rest, precision, acc), do: {acc, precision, rest}

  defp parse_offset(""), do: {nil, ""}
  defp parse_offset("Z"), do: {0, ""}
  defp parse_offset("-00:00"), do: :error

  defp parse_offset(<<?+, hour::2-bytes, ?:, min::2-bytes, rest::binary>>),
    do: parse_offset(1, hour, min, rest)

  defp parse_offset(<<?-, hour::2-bytes, ?:, min::2-bytes, rest::binary>>),
    do: parse_offset(-1, hour, min, rest)

  defp parse_offset(<<?+, hour::2-bytes, min::2-bytes, rest::binary>>),
    do: parse_offset(1, hour, min, rest)

  defp parse_offset(<<?-, hour::2-bytes, min::2-bytes, rest::binary>>),
    do: parse_offset(-1, hour, min, rest)

  defp parse_offset(<<?+, hour::2-bytes, rest::binary>>), do: parse_offset(1, hour, "00", rest)
  defp parse_offset(<<?-, hour::2-bytes, rest::binary>>), do: parse_offset(-1, hour, "00", rest)
  defp parse_offset(_), do: :error

  defp parse_offset(sign, hour, min, rest) do
    case {Integer.parse(hour), Integer.parse(min)} do
      {{hour, ""}, {min, ""}} when hour < 24 and min < 60 -> {(hour * 60 + min) * 60 * sign, rest}
      _not_an_offset -> :error
    end
  end
end
