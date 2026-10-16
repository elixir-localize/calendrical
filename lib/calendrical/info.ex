defmodule Calendrical.Info do
  @moduledoc """
  The static facts about a calendar, as data.

  Every calendar answers `info/0` with one of these structs, built once
  when the calendar is compiled. The facts are what a calendar is rather
  than what it computes: the CLDR calendars that name its months and its
  eras, its epoch, whether it has a year 0, what its year is built of,
  the fewest and most months a year has, the rule its own weeks follow,
  the cycles its years run in, the place an astronomical calendar is
  reckoned at, the lengths its months can have, the calendar its dates
  are parsed in, and, for a composite calendar, the calendars it is made
  of. Calendrical's derived functions read these facts and compute every
  other answer from them and the calendar's kernel callbacks, so a fact
  that changes an answer is a field here, not a function of the
  calendar.

  """

  @typedoc """
  The rule a calendar's own weeks follow: the day they begin on, numbered
  1 for Monday to 7 for Sunday or `:first_day_of_year` where weeks are
  counted from the first day of the year whatever its weekday, and the
  fewest days of a year or a month that its week 1 holds.
  """
  @type week_rule :: %{
          first_day: Calendar.day_of_week() | :first_day_of_year,
          min_days_in_first_week: 1..7
        }

  @typedoc """
  The lengths a month can have, by month: a count of days where the
  month has as many in every year, or the range of its lengths.
  """
  @type month_lengths :: %{optional(Calendar.month()) => Calendar.day() | Range.t()}

  @typedoc """
  The place an astronomical calendar is reckoned at, as a function of the
  ISO day number: the latitude and longitude in degrees, the altitude in
  metres and the offset from UTC in days, as `Astro` takes them.
  """
  @type location :: (integer() -> {number(), number(), number(), number()})

  @typedoc """
  A member of a composite calendar: the calendar and the ISO day number
  of the first day it is in effect on, which is `nil` for the base
  calendar in effect before every other.
  """
  @type member :: {integer() | nil, module()}

  @type t :: %__MODULE__{
          calendar: module(),
          cldr_calendar_type: atom(),
          era_calendar_type: atom(),
          epoch: integer() | nil,
          year_zero?: boolean(),
          structure: :months | :weeks,
          months_in_year: {pos_integer(), pos_integer()},
          weeks: week_rule(),
          years_in_cycle: pos_integer() | nil,
          year_cycle: pos_integer() | nil,
          location: location() | nil,
          month_lengths: month_lengths() | nil,
          parsing_calendar: module(),
          members: [member(), ...] | nil
        }

  defstruct calendar: nil,
            cldr_calendar_type: :gregorian,
            era_calendar_type: nil,
            epoch: nil,
            year_zero?: true,
            structure: :months,
            months_in_year: {12, 12},
            weeks: %{first_day: 1, min_days_in_first_week: 1},
            years_in_cycle: nil,
            year_cycle: nil,
            location: nil,
            month_lengths: nil,
            parsing_calendar: nil,
            members: nil

  @doc """
  Builds the facts about a calendar from the fields given, with the
  defaults a calendar leaves unsaid.

  ### Arguments

  * `calendar` is the calendar module the facts describe.

  * `fields` is a keyword list or map of the struct's fields. The
    defaults are the Gregorian calendar's names and eras, a year 0,
    a year of months, twelve months, weeks from Monday holding at least
    one day of the year, no cycles, no place, no stated month lengths,
    the calendar itself for parsing and no members.

  ### Returns

  * A `t:t/0`. `:era_calendar_type` defaults to `:cldr_calendar_type`
    where it is not given, and `:parsing_calendar` to `calendar`.

  ### Examples

      iex> info = Calendrical.Info.new(Calendrical.Hebrew, cldr_calendar_type: :hebrew, months_in_year: {12, 13})
      iex> {info.era_calendar_type, info.parsing_calendar, info.months_in_year}
      {:hebrew, Calendrical.Hebrew, {12, 13}}

  """
  @spec new(module(), keyword() | map()) :: t()
  def new(calendar, fields) when is_atom(calendar) do
    fields = Map.new(fields)

    %__MODULE__{calendar: calendar}
    |> struct!(fields)
    |> Map.update!(:era_calendar_type, &(&1 || Map.get(fields, :cldr_calendar_type, :gregorian)))
    |> Map.update!(:parsing_calendar, &(&1 || calendar))
  end

  @doc false
  # The facts a calendar answers through the callbacks every maker
  # generates today, gathered into a struct, with the fields a maker knows
  # on its own (`:epoch`, `:year_zero?`, `:weeks`, `:year_cycle`,
  # `:location`, `:members`) given alongside. While the callbacks are the
  # source of the facts, a calendar's overrides of them are reflected here;
  # once the facts live here, the callbacks read them instead.
  @spec gather(module(), keyword()) :: t()
  def gather(calendar, fields) when is_atom(calendar) and is_list(fields) do
    new(
      calendar,
      Keyword.merge(
        [
          cldr_calendar_type: calendar.cldr_calendar_type(),
          era_calendar_type: calendar.era_calendar_type(),
          structure: structure(calendar.calendar_base()),
          months_in_year: months_in_year(calendar),
          years_in_cycle: cycle(calendar.years_in_cycle()),
          parsing_calendar: calendar.parsing_calendar(),
          month_lengths: month_lengths(calendar)
        ],
        fields
      )
    )
  end

  defp structure(:week), do: :weeks
  defp structure(:month), do: :months

  defp cycle({:error, :undefined}), do: nil
  defp cycle(years) when is_integer(years), do: years

  defp months_in_year(calendar) do
    case calendar.months_in_year_bounds() do
      {:error, :undefined} -> {1, 13}
      {fewest, most} -> {fewest, most}
    end
  end

  @doc false
  # The week rule a maker's options state: the day weeks begin on, with
  # `:first` (weeks counted from the year's first day) as
  # `:first_day_of_year`, and the fewest days of the year in week 1.
  @spec week_rule(Calendar.day_of_week() | :first | :first_day_of_year, 1..7) :: week_rule()
  def week_rule(first_day, min_days_in_first_week) do
    first_day = if first_day == :first, do: :first_day_of_year, else: first_day
    %{first_day: first_day, min_days_in_first_week: min_days_in_first_week}
  end

  # The lengths a calendar states for its months without a year, as
  # `days_in_month/1` answers them: a count, or the range of an
  # ambiguous answer. A month the calendar cannot answer for is left out,
  # and a calendar that answers for none states no lengths.
  defp month_lengths(calendar) do
    {_fewest, most} = months_in_year(calendar)

    lengths =
      for month <- 1..most, length = month_length(calendar.days_in_month(month)), into: %{} do
        {month, length}
      end

    if map_size(lengths) == 0, do: nil, else: lengths
  end

  defp month_length(days) when is_integer(days), do: days
  defp month_length({:ambiguous, first..last//1}), do: first..last//1
  defp month_length({:ambiguous, [_ | _] = lengths}), do: Enum.min(lengths)..Enum.max(lengths)//1
  defp month_length({:error, _reason}), do: nil
end
