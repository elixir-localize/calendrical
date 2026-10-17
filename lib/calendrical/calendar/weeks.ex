defmodule Calendrical.Calendar.Weeks do
  @moduledoc """
  Makes a calendar of whole weeks: a year of 52 or 53 weeks that begins
  or ends on a weekday near a day of the Gregorian year, cut into twelve
  months of four or five weeks by a pattern, as retail and other fiscal
  calendars count them and as the ISO week year does.

  A date of the calendar is a month of the pattern and a day of it, so a
  month of four weeks has days 1 to 28 and one of five weeks days 1 to
  35; a long year's last month holds the fifty-third week.

  ### Options

  * `:pattern` is the weeks in the three months of a quarter, one of
    `[4, 4, 5]`, `[4, 5, 4]` and `[5, 4, 4]`. The default is `[4, 5, 4]`.

  * `:year_begins` is the rule the year begins by:
    `{weekday, :on_or_before, {month, day}}`, the weekday on or before a
    day of a Gregorian month, the day being 1 to 7, so the year's first
    week holds that day, or `{weekday, :nearest, {month, 4}}`, the weekday
    nearest the fourth, which is the same rule. The ISO week year begins
    `{:monday, :on_or_before, {1, 4}}`. The default is `{:monday, :on_or_before, {1, 1}}`.

  * `:year_ends` is the rule the year ends by, instead of `:year_begins`:
    `{weekday, :on_or_after, {month, day}}`, the weekday on or after a day
    within the last seven days of a Gregorian month, so the year's last
    week holds that day, or `{weekday, :nearest, {month, last_day}}`, the
    weekday nearest the month's last day. The NRF 4-5-4 year ends
    `{:saturday, :nearest, {1, 31}}`.

  * `:year_number` is the Gregorian year the year takes its number from:
    `:beginning`, the one it begins in, `:ending`, the one it ends in, or
    `:majority`, the one most of it falls in, which is the default.

  * `:cldr_calendar_type` is the CLDR calendar whose data names the
    months and days, `:gregorian` by default.

  ### Examples

      defmodule Retail do
        use Calendrical.Calendar.Weeks,
          pattern: [4, 5, 4],
          year_ends: {:saturday, :nearest, {1, 31}}
      end

      defmodule WeekYear do
        use Calendrical.Calendar.Weeks, year_begins: {:monday, :on_or_before, {1, 4}}
      end

  """

  @known_options [:pattern, :year_begins, :year_ends, :year_number, :cldr_calendar_type]
  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
  @days_in_week 7
  @month_lengths %{
    1 => 31,
    2 => 28,
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31
  }

  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      @options Calendrical.Calendar.Weeks.engine_options!(options)
      @before_compile Calendrical.Compiler.Week
      @before_compile Calendrical.Compiler.DateCheck
    end
  end

  @doc false
  # The options the week engine takes, from the options a calendar of weeks
  # is made with: the rule the year begins or ends by becomes the weekday,
  # the month and the fewest days of the year its first or last week holds.
  def engine_options!(options) do
    refuse_unknown_options!(options)

    anchor =
      case {Keyword.fetch(options, :year_begins), Keyword.fetch(options, :year_ends)} do
        {{:ok, _begins}, {:ok, _ends}} ->
          raise ArgumentError, "a calendar of weeks takes :year_begins or :year_ends, not both"

        {:error, {:ok, ends}} ->
          year_ends!(ends)

        {begins, :error} ->
          year_begins!(begins_or_default(begins))
      end

    anchor ++
      [
        weeks_in_month: Keyword.get(options, :pattern, [4, 5, 4]),
        year: Keyword.get(options, :year_number, :majority),
        cldr_calendar_type: Keyword.get(options, :cldr_calendar_type, :gregorian)
      ]
  end

  defp begins_or_default({:ok, begins}), do: begins
  defp begins_or_default(:error), do: {:monday, :on_or_before, {1, 1}}

  defp year_begins!({weekday, :nearest, {month, 4}}),
    do: year_begins!({weekday, :on_or_before, {month, 4}})

  defp year_begins!({weekday, :on_or_before, {month, day}})
       when weekday in @weekdays and is_integer(month) and month in 1..12//1 and
              is_integer(day) and day in 1..@days_in_week//1 do
    [
      first_or_last: :first,
      begins_or_ends: :begins,
      day_of_week: weekday_number(weekday),
      month_of_year: month,
      min_days_in_first_week: day
    ]
  end

  defp year_begins!(other) do
    raise ArgumentError,
          ":year_begins must be {weekday, :on_or_before, {month, day}} with the day 1 to 7, " <>
            "or {weekday, :nearest, {month, 4}}, found #{inspect(other)}"
  end

  defp year_ends!({weekday, :nearest, {month, day}} = rule) when is_integer(month) do
    if Map.get(@month_lengths, month) == day,
      do: year_ends!({weekday, :on_or_after, {month, day - 3}}),
      else: raise(ArgumentError, year_ends_error(rule))
  end

  defp year_ends!({weekday, :on_or_after, {month, day}} = rule)
       when weekday in @weekdays and is_integer(month) and month in 1..12//1 and is_integer(day) do
    length = Map.fetch!(@month_lengths, month)

    if day >= length - @days_in_week + 1 and day <= length do
      [
        first_or_last: :last,
        begins_or_ends: :ends,
        day_of_week: weekday_number(weekday),
        month_of_year: month,
        min_days_in_first_week: length - day + 1
      ]
    else
      raise ArgumentError, year_ends_error(rule)
    end
  end

  defp year_ends!(other), do: raise(ArgumentError, year_ends_error(other))

  defp year_ends_error(rule) do
    ":year_ends must be {weekday, :on_or_after, {month, day}} with the day in the month's " <>
      "last seven, or {weekday, :nearest, {month, last_day}}, found #{inspect(rule)}"
  end

  defp weekday_number(weekday), do: Enum.find_index(@weekdays, &(&1 == weekday)) + 1

  defp refuse_unknown_options!(options) do
    case Keyword.keys(options) -- @known_options do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "unknown options #{inspect(unknown)} for use Calendrical.Calendar.Weeks; " <>
                "the options are #{inspect(@known_options)}"
    end
  end
end
