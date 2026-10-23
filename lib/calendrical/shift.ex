defmodule Calendrical.Shift do
  @moduledoc """
  Date arithmetic for a calendar whose months are counted by their
  position in the year: the implementation of `c:Calendrical.shift/6`
  and `c:Calendrical.diff/3` that `use Calendrical.Calendar` supplies,
  computed from the calendar's kernel.

  The contract every calendar's `shift/6` honours, whatever its maker:

  * Days and weeks are counted on the day line, through
    `c:Calendrical.date_to_iso_days/3`.

  * Months are counted by position: the next month is the next position
    in the year, or the first of the year after. A quarter is three
    months.

  * Years keep the month as the calendar's culture names it, its
    traditional number (`Calendrical.Month.traditional_month/3`), so
    Nisan stays Nisan whatever its position, and a leap month the
    resulting year lacks becomes the month it repeats.

  * A count that reaches or crosses a year 0 the calendar does not have
    (`info().year_zero?`) goes one year further the way it was going.

  * With `clamp: true`, the default, a day the resulting month lacks
    becomes the month's last day. With `clamp: false` the fields are
    returned as counted, and may not be a date of the calendar.

  """

  alias Calendrical.Month

  @typedoc "A calendar module."
  @type calendar :: module()

  @typedoc "A unit of the shift."
  @type unit :: :years | :quarters | :months | :weeks | :days

  @days_in_week 7
  @months_in_quarter 3

  @doc """
  Returns the date a number of units on from a date of the calendar.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  * `unit` is one of `:years`, `:quarters`, `:months`, `:weeks` or
    `:days`.

  * `count` is the number of units, which may be negative.

  * `options` is a keyword list of options.

  ### Options

  * `:clamp` is whether a day the resulting month lacks becomes its last
    day. The default is `true`.

  ### Returns

  * `{year, month, day}` of the calendar.

  ### Examples

      iex> Calendrical.Shift.shift(Calendrical.Gregorian, 2026, 1, 31, :months, 1, [])
      {2026, 2, 28}

      iex> Calendrical.Shift.shift(Calendrical.Gregorian, 2026, 1, 31, :months, 1, clamp: false)
      {2026, 2, 31}

      # Adar I of the leap year 5784 becomes Adar in 5785, which has 29 days
      iex> Calendrical.Shift.shift(Calendrical.Hebrew, 5784, 6, 30, :years, 1, [])
      {5785, 6, 29}

      # 15 Nisan, the 8th month of the leap year 5784 and the 7th of 5785
      iex> Calendrical.Shift.shift(Calendrical.Hebrew, 5784, 8, 15, :years, 1, [])
      {5785, 7, 15}

      # The Julian calendar has no year 0
      iex> Calendrical.Shift.shift(Calendrical.Julian, -1, 6, 15, :years, 1, [])
      {1, 6, 15}

  """
  @spec shift(calendar, Calendar.year(), Calendar.month(), Calendar.day(), unit, integer, keyword) ::
          {Calendar.year(), Calendar.month(), Calendar.day()}
  def shift(calendar, year, month, day, :years, years, options) do
    target_year = year_on(calendar, year, years)
    traditional_month = Month.traditional_month(calendar, year, month)

    target_month =
      month_named(calendar, target_year, traditional_month, {year, month})

    {target_year, target_month, clamp_day(calendar, target_year, target_month, day, options)}
  end

  def shift(calendar, year, month, day, :quarters, quarters, options) do
    shift(calendar, year, month, day, :months, quarters * @months_in_quarter, options)
  end

  def shift(calendar, year, month, day, :months, months, options) do
    {target_year, target_month} = months_on(calendar, year, month, months)
    {target_year, target_month, clamp_day(calendar, target_year, target_month, day, options)}
  end

  def shift(calendar, year, month, day, :weeks, weeks, options) do
    shift(calendar, year, month, day, :days, weeks * @days_in_week, options)
  end

  def shift(calendar, year, month, day, :days, days, _options) do
    calendar.date_from_iso_days(calendar.date_to_iso_days(year, month, day) + days)
  end

  @doc """
  Returns the whole number of units from one date of the calendar to
  another, as `shift/7` adds them.

  The count is the largest number of units that `shift/7` can add to the
  earlier date without passing the later one, and is negative when `to`
  is before `from`.

  ### Arguments

  * `calendar` is a calendar module.

  * `from` and `to` are dates of the calendar as `{year, month, day}`.

  * `unit` is one of `:years`, `:quarters`, `:months`, `:weeks` or
    `:days`.

  ### Returns

  * An integer.

  ### Examples

      iex> Calendrical.Shift.diff(Calendrical.Gregorian, {2026, 1, 31}, {2026, 2, 28}, :months)
      1

      iex> Calendrical.Shift.diff(Calendrical.Hebrew, {5784, 6, 30}, {5785, 6, 29}, :months)
      13

  """
  @spec diff(
          calendar,
          {Calendar.year(), Calendar.month(), Calendar.day()},
          {Calendar.year(), Calendar.month(), Calendar.day()},
          unit
        ) :: integer
  def diff(calendar, from, to, unit) do
    Calendrical.Base.Common.diff(calendar, from, to, unit)
  end

  # The year a number of years on, past a year 0 the calendar does not have.
  defp year_on(calendar, year, years) do
    target = year + years

    cond do
      calendar.info().year_zero? -> target
      year < 0 and target >= 0 -> target + 1
      year > 0 and target <= 0 -> target - 1
      true -> target
    end
  end

  # The position in a year of a traditional month, or of the month a leap
  # month repeats where the year has no leap month; the month's own
  # position where the calendar names its months by position alone.
  defp month_named(calendar, year, {named, :leap}, {from_year, from_month}) do
    case Month.month_from_traditional(calendar, year, {named, :leap}) do
      position when is_integer(position) -> position
      {:error, _no_leap_month} -> repeated_month(calendar, year, from_year, from_month)
    end
  end

  defp month_named(calendar, year, named, {_from_year, from_month}) when is_integer(named) do
    case Month.month_from_traditional(calendar, year, named) do
      position when is_integer(position) -> position
      {:error, _no_such_month} -> from_month
    end
  end

  defp month_named(_calendar, _year, _no_month, {_from_year, from_month}), do: from_month

  # The month a leap month repeats, in a year without it: the month of the
  # same CLDR name, as a Chinese leap second month is named for the second
  # month, or, where the leap month has a name of its own, the month of the
  # next name, as Adar I gives way to Adar.
  defp repeated_month(calendar, year, from_year, from_month) do
    names =
      for run <- calendar.month_numbers(year), position <- run, into: %{} do
        {Month.cldr_month(calendar, year, position), position}
      end

    case Month.cldr_month(calendar, from_year, from_month) do
      {named, :leap} ->
        Map.get(names, named, from_month)

      named when is_integer(named) ->
        Map.get(names, named) || Map.get(names, named + 1, from_month)

      _no_name ->
        from_month
    end
  end

  # The year and position a number of months on, walking the years, each
  # with its own count of months.
  defp months_on(_calendar, year, month, 0), do: {year, month}

  defp months_on(calendar, year, month, months) when months > 0 do
    months_in_year = calendar.months_in_year(year)

    if month + months <= months_in_year do
      {year, month + months}
    else
      months_on(calendar, next_year(calendar, year), 1, months - (months_in_year - month + 1))
    end
  end

  defp months_on(calendar, year, month, months) do
    if month + months >= 1 do
      {year, month + months}
    else
      previous_year = previous_year(calendar, year)
      months_on(calendar, previous_year, calendar.months_in_year(previous_year), months + month)
    end
  end

  defp next_year(calendar, year) do
    if year == -1 and not calendar.info().year_zero?, do: 1, else: year + 1
  end

  defp previous_year(calendar, year) do
    if year == 1 and not calendar.info().year_zero?, do: -1, else: year - 1
  end

  defp clamp_day(calendar, year, month, day, options) do
    if Keyword.get(options, :clamp, true) do
      case calendar.days_in_month(year, month) do
        days when is_integer(days) and days > 0 -> min(day, days)
        _no_such_month -> day
      end
    else
      day
    end
  end
end
