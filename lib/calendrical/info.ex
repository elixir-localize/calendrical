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
  month has as many in every year, the range of its lengths where every
  length between the fewest and the most occurs, and otherwise the list
  of the lengths that do.
  """
  @type month_lengths :: %{
          optional(Calendar.month()) => Calendar.day() | Range.t() | [Calendar.day(), ...]
        }

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
          family: module() | nil,
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
            family: Calendrical,
            members: nil

  @doc """
  Builds the facts about a calendar from the fields given, with the
  defaults a calendar leaves unsaid.

  `:family` names the module that answers `calendar_from_cldr_calendar_type/1`
  for the calendars of this calendar's family, `Calendrical` for every
  calendar Calendrical builds: Localize asks it for the calendar a locale's
  `-u-ca-` names, without asking the calendar module itself.

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

  @doc """
  Returns what a calendar's year is built of, `:month` or `:week`, as its
  `info/0` states.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * `:week` where the calendar's structure is `:weeks`, `:month` otherwise.

  ### Examples

      iex> Calendrical.Info.calendar_base(Calendrical.Gregorian)
      :month

      iex> Calendrical.Info.calendar_base(Calendrical.ISOWeek)
      :week

  """
  @spec calendar_base(module()) :: :month | :week
  def calendar_base(calendar) do
    if calendar.info().structure == :weeks, do: :week, else: :month
  end

  @doc """
  Returns the number of years after which a calendar's years repeat, as
  its `info/0` states.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * The number of years in the cycle, or `{:error, :undefined}` where the
    calendar states none.

  ### Examples

      iex> Calendrical.Info.years_in_cycle(Calendrical.Gregorian)
      400

      iex> Calendrical.Info.years_in_cycle(Calendrical.Chinese)
      {:error, :undefined}

  """
  @spec years_in_cycle(module()) :: pos_integer() | {:error, :undefined}
  def years_in_cycle(calendar) do
    calendar.info().years_in_cycle || {:error, :undefined}
  end

  @doc """
  Returns the place a calendar is reckoned at, as its `info/0` states, or
  the Chinese calendar's meridian, the traditional reference, where it
  names none.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * A `t:location/0` function.

  ### Examples

      iex> Calendrical.Info.location(Calendrical.Chinese) == (&Calendrical.Chinese.location/1)
      true

      iex> Calendrical.Info.location(Calendrical.Gregorian) == (&Calendrical.Chinese.location/1)
      true

  """
  @spec location(module()) :: location()
  def location(calendar) do
    calendar.info().location || (&Calendrical.Chinese.location/1)
  end

  @doc """
  Returns the number of months in a calendar's year without a year, as
  its `info/0` states.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * The count where every year has as many months,
    `{:ambiguous, fewest..most}` where a leap year has more, or
    `{:error, :undefined}` for a composite calendar, whose years change
    calendar and so are not alike enough to count without a year;
    `Calendrical.Month.months_in_year_bounds/1` gives its bounds.

  ### Examples

      iex> Calendrical.Info.months_in_year(Calendrical.Gregorian)
      12

      iex> Calendrical.Info.months_in_year(Calendrical.Hebrew)
      {:ambiguous, 12..13}

      iex> Calendrical.Info.months_in_year(Calendrical.Reform.England)
      {:error, :undefined}

  """
  @spec months_in_year(module()) ::
          pos_integer() | {:ambiguous, Range.t()} | {:error, :undefined}
  def months_in_year(calendar) do
    case calendar.info() do
      %{members: [_ | _]} -> {:error, :undefined}
      %{months_in_year: {months, months}} -> months
      %{months_in_year: {fewest, most}} -> {:ambiguous, fewest..most//1}
    end
  end

  @doc """
  Returns the CLDR calendar type whose data names a date's months and
  days: that of the member calendar in effect on the date in a composite
  calendar, by the order of the date's fields, and the calendar's own
  otherwise.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * A CLDR calendar type.

  ### Examples

      iex> Calendrical.Info.cldr_calendar_type(Calendrical.Gregorian, 2026, 1, 1)
      :gregorian

      iex> Calendrical.Info.cldr_calendar_type(Calendrical.Reform.Japan, 1870, 1, 1)
      :chinese

      iex> Calendrical.Info.cldr_calendar_type(Calendrical.Reform.Japan, 1900, 1, 1)
      :japanese

  """
  @spec cldr_calendar_type(module(), Calendar.year(), Calendar.month(), Calendar.day()) :: atom()
  def cldr_calendar_type(calendar, year, month, day) do
    case member_in_effect(calendar, year, month, day) do
      nil -> calendar.info().cldr_calendar_type
      member -> member.info().cldr_calendar_type
    end
  end

  @doc """
  Returns the calendars a date written for a calendar may be written in:
  the members of a composite calendar, in the order they take effect, and
  the calendar itself otherwise.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * A list of calendar modules.

  ### Examples

      iex> Calendrical.Info.parsing_calendars(Calendrical.Gregorian)
      [Calendrical.Gregorian]

      iex> Calendrical.Info.parsing_calendars(Calendrical.Reform.Japan)
      [Calendrical.LunarJapanese, Calendrical.Japanese]

  """
  @spec parsing_calendars(module()) :: [module(), ...]
  def parsing_calendars(calendar) do
    case calendar.info().members do
      nil -> [calendar]
      members -> members |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
    end
  end

  # The member of a composite calendar in effect on a date: the last whose
  # first day, as the composite labels it, is on or before the date in the
  # order of its fields, so a date the composite lacks is still read in the
  # member its year falls in; `nil` for a calendar with no members.
  defp member_in_effect(calendar, year, month, day)
       when is_integer(year) and is_integer(month) and is_integer(day) do
    case calendar.info().members do
      nil ->
        nil

      members ->
        members
        |> Enum.take_while(fn {first, _member} ->
          is_nil(first) or calendar.date_from_iso_days(first) <= {year, month, day}
        end)
        |> List.last()
        |> elem(1)
    end
  end

  defp member_in_effect(_calendar, _year, _month, _day), do: nil

  @doc """
  Returns the calendar whose facts govern a date: the member of a
  composite calendar in effect on it, by the order of the date's fields,
  and the calendar itself otherwise.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * A calendar module.

  ### Examples

      iex> Calendrical.Info.in_effect(Calendrical.Reform.England, 1700, 1, 1)
      Calendrical.Julian.March25

      iex> Calendrical.Info.in_effect(Calendrical.Hebrew, 5786, 1, 1)
      Calendrical.Hebrew

  """
  @spec in_effect(module(), Calendar.year(), Calendar.month(), Calendar.day()) :: module()
  def in_effect(calendar, year, month, day) do
    member_in_effect(calendar, year, month, day) || calendar
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
end
