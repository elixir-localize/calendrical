defmodule Calendrical.Week do
  @moduledoc """
  The weeks of any calendar, computed once for every calendar from its
  kernel.

  Every calendar's weeks follow one rule, TR35's: a week is seven days
  and begins on the day the calendar's `c:Calendrical.info/0` names
  (`info().weeks.first_day`, 1 for Monday to 7 for Sunday); week 1 of a
  year is the first week holding at least the fewest days of the year the
  same facts state (`info().weeks.min_days_in_first_week`); the days
  before week 1 are the last week of the year before, and the days of the
  old year inside week 1 are week 1 of the new. A month's weeks are
  numbered the same way over the month. A calendar whose weeks are
  counted from the year's first day whatever its weekday
  (`first_day: :first_day_of_year`) begins week 1 with the year, so its
  last week is short.

  Every function takes the calendar as its first argument and answers for
  every calendar Calendrical builds. The calendar modules carry a
  delegation to each for Localize, which reaches a calendar through its
  module alone.

  """

  alias Calendrical.Base.Common

  @typedoc "A calendar module."
  @type calendar :: module()

  @days_in_week 7
  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  @doc """
  Returns the week-year and the week of the year a date is in.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week}`, where the week-year is the year before or after
    where the date falls in that year's last or first week, or

  * `{:error, exception}` for a date the calendar does not have: a
    `Calendrical.MissingFieldsError` for a date missing a field, and a
    `Calendrical.InvalidDateError` otherwise.

  ### Examples

      iex> Calendrical.Week.week_of_year(Calendrical.Gregorian, 2025, 12, 31)
      {2026, 1}

      iex> Calendrical.Week.week_of_year(Calendrical.Hebrew, 5786, 7, 15)
      {5786, 28}

      # 29 Elul 5786 is in week 1 of 5787, which begins on the Sunday before 1 Tishri
      iex> Calendrical.Week.week_of_year(Calendrical.Hebrew, 5786, 12, 29)
      {5787, 1}

  """
  @spec week_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week()} | {:error, Exception.t()}
  def week_of_year(calendar, year, month, day) do
    with {:ok, iso_days} <- iso_days(calendar, "week_of_year", year, month, day),
         {:ok, {first, last}} <- year_bounds(calendar, year) do
      this_week_1 = first_week_of(calendar, first)

      cond do
        iso_days < this_week_1 ->
          {year - 1, weeks_in_year!(calendar, year - 1)}

        iso_days > last - @days_in_week and
            iso_days >= next_week_1(calendar, year, this_week_1, last) ->
          {year + 1, 1}

        true ->
          {year, div(iso_days - this_week_1, @days_in_week) + 1}
      end
    end
  end

  @doc """
  Returns the ISO 8601 week-year and week of the day a date names,
  whichever calendar names it: the week of the Gregorian year, from
  Monday, holding at least four days of it.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week}` of ISO 8601, or

  * `{:error, exception}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.iso_week_of_year(Calendrical.Hebrew, 5786, 7, 15)
      {2026, 14}

  """
  @spec iso_week_of_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week()} | {:error, Exception.t()}
  def iso_week_of_year(calendar, year, month, day) do
    with {:ok, iso_days} <- iso_days(calendar, "iso_week_of_year", year, month, day) do
      {year, month, day} = Calendrical.ISO.date_from_iso_days(iso_days)
      week_of_year(Calendrical.ISO, year, month, day)
    end
  end

  @doc """
  Returns the month and the week of the month a date is in.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{month, week}`, where the month is the one before or after where
    the date falls in that month's last or first week, or

  * `{:error, exception}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.week_of_month(Calendrical.Gregorian, 2026, 1, 15)
      {1, 3}

      # The week holding 1 February is February's week 1
      iex> Calendrical.Week.week_of_month(Calendrical.Gregorian, 2026, 1, 31)
      {2, 1}

  """
  @spec week_of_month(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.month(), Calendrical.week()} | {:error, Exception.t()}
  def week_of_month(calendar, year, month, day) do
    with {:ok, iso_days} <- iso_days(calendar, "week_of_month", year, month, day),
         {:ok, {first, last}} <- month_bounds(calendar, year, month) do
      this_week_1 = first_week_of(calendar, first)

      cond do
        iso_days < this_week_1 ->
          {previous_year, previous_month} = previous_month(calendar, year, month)
          {previous_month, weeks_in_month!(calendar, previous_year, previous_month)}

        iso_days > last - @days_in_week and
            iso_days >= next_month_week_1(calendar, year, month, this_week_1, last) ->
          {_next_year, next_month} = next_month(calendar, year, month)
          {next_month, 1}

        true ->
          {month, div(iso_days - this_week_1, @days_in_week) + 1}
      end
    end
  end

  @doc """
  Returns the number of weeks in a year of the calendar.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * The number of weeks, or

  * `{:error, exception}` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Week.weeks_in_year(Calendrical.Gregorian, 2026)
      52

      iex> Calendrical.Week.weeks_in_year(Calendrical.ISO, 2026)
      53

      iex> Calendrical.Week.weeks_in_year(Calendrical.Hebrew, 5787)
      55

  """
  @spec weeks_in_year(calendar, Calendar.year()) ::
          pos_integer() | {:error, Exception.t()}
  def weeks_in_year(calendar, year) when is_integer(year) do
    with {:ok, {first, last}} <- year_bounds(calendar, year) do
      this_week_1 = first_week_of(calendar, first)
      weeks_between(this_week_1, next_week_1(calendar, year, this_week_1, last))
    end
  end

  def weeks_in_year(_calendar, nil),
    do: {:error, Calendrical.missing_year_error("weeks_in_year", nil)}

  def weeks_in_year(calendar, year), do: invalid_date(calendar, year: year)

  @doc """
  Returns the days of a week of a year of the calendar.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `week` is a week of that year.

  ### Returns

  * A `t:Date.Range.t/0` of the week's seven days, which may begin in the
    year before or end in the year after, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a week the year does not have.

  ### Examples

      iex> Calendrical.Week.week(Calendrical.ISOWeek, 2026, 25)
      Date.range(~D[2026-06-15 Calendrical.ISOWeek], ~D[2026-06-21 Calendrical.ISOWeek])

      iex> Calendrical.Week.week(Calendrical.Gregorian, 2025, 1)
      Date.range(~D[2024-12-30 Calendrical.Gregorian], ~D[2025-01-05 Calendrical.Gregorian])

  """
  @spec week(calendar, Calendar.year(), Calendrical.week()) ::
          Date.Range.t() | {:error, Exception.t()}
  def week(calendar, year, week) when is_integer(year) and is_integer(week) and week >= 1 do
    with {:ok, {first, last}} <- year_bounds(calendar, year) do
      this_week_1 = first_week_of(calendar, first)
      next_week_1 = next_week_1(calendar, year, this_week_1, last)

      if week <= weeks_between(this_week_1, next_week_1) do
        first_day = this_week_1 + (week - 1) * @days_in_week
        range(calendar, first_day, min(first_day + @days_in_week - 1, next_week_1 - 1))
      end
    end
    |> invalid_unless_range(calendar, year, week)
  end

  def week(calendar, year, week) when is_integer(year) and is_integer(week),
    do: invalid_date(calendar, year: year, week: week)

  def week(_calendar, year, week) when is_nil(year) or is_nil(week),
    do:
      {:error,
       Calendrical.MissingFieldsError.exception(
         function: "week",
         fields: [year: year, week: week]
       )}

  def week(calendar, year, week), do: invalid_date(calendar, year: year, week: week)

  @doc """
  Returns the weeks of a month of a year of the calendar, in order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A list of `t:Date.Range.t/0`, one for each week `week_of_month/4`
    names for the month, the first of which may begin in the month before
    and the last run into the month after, or

  * `{:error, exception}` for a month the year does not have.

  ### Examples

      iex> Calendrical.Week.weeks_of_month(Calendrical.Gregorian, 2026, 2) |> length()
      4

      iex> Calendrical.Week.weeks_of_month(Calendrical.Gregorian, 2026, 2) |> hd()
      Date.range(~D[2026-01-26 Calendrical.Gregorian], ~D[2026-02-01 Calendrical.Gregorian])

  """
  @spec weeks_of_month(calendar, Calendar.year(), Calendar.month()) ::
          [Date.Range.t()] | {:error, Exception.t()}
  def weeks_of_month(calendar, year, month) do
    case month_bounds(calendar, year, month) do
      {:ok, {first, last}} ->
        this_week_1 = first_week_of(calendar, first)
        next_week_1 = next_month_week_1(calendar, year, month, this_week_1, last)

        for week <- 1..weeks_between(this_week_1, next_week_1)//1 do
          first_day = this_week_1 + (week - 1) * @days_in_week
          range(calendar, first_day, min(first_day + @days_in_week - 1, next_week_1 - 1))
        end
        |> Enum.reject(&is_nil/1)

      {:error, %Calendrical.InvalidDateError{}} ->
        {:error,
         Calendrical.InvalidMonthError.exception(calendar: calendar, year: year, month: month)}
    end
  end

  @doc """
  Returns the date of a day of a week of a week-year: the inverse of
  `week_date_from_date/4`.

  ### Arguments

  * `calendar` is a calendar module.

  * `week_year` and `week` are a week of the calendar.

  * `day` is the day of the week, numbered from the day the calendar's
    weeks begin on.

  ### Returns

  * A `t:Date.t/0` of the calendar, or

  * `{:error, %Calendrical.InvalidDateError{}}` where the week has no such day.

  ### Examples

      iex> Calendrical.Week.date_from_week_date(Calendrical.ISOWeek, 2026, 25, 2)
      ~D[2026-06-16 Calendrical.ISOWeek]

      # Week 1 of 5786 begins on the Sunday before 1 Tishri, 28 Elul 5785
      iex> Calendrical.Week.date_from_week_date(Calendrical.Hebrew, 5786, 1, 1)
      ~D[5785-12-28 Calendrical.Hebrew]

  """
  @spec date_from_week_date(calendar, Calendar.year(), Calendrical.week(), Calendar.day_of_week()) ::
          Date.t() | {:error, Exception.t()}
  def date_from_week_date(calendar, week_year, week, day)
      when is_integer(week_year) and is_integer(week) and is_integer(day) and
             day in 1..@days_in_week do
    case week(calendar, week_year, week) do
      %Date.Range{first_in_iso_days: first, last_in_iso_days: last}
      when first + day - 1 <= last ->
        date(calendar, first + day - 1)

      _no_such_day ->
        invalid_date(calendar, week_year: week_year, week: week, day_of_week: day)
    end
  end

  def date_from_week_date(calendar, week_year, week, day),
    do: invalid_date(calendar, week_year: week_year, week: week, day_of_week: day)

  @doc """
  Returns the week-year, the week and the day of the week of a date.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are the fields of a date of the calendar.

  ### Returns

  * `{week_year, week, day_of_week}`, the day numbered from the day the
    calendar's weeks begin on, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have.

  ### Examples

      iex> Calendrical.Week.week_date_from_date(Calendrical.ISOWeek, 2026, 6, 16)
      {2026, 25, 2}

  """
  @spec week_date_from_date(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendrical.week(), Calendar.day_of_week()}
          | {:error, Exception.t()}
  def week_date_from_date(calendar, year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    with {week_year, week} when is_integer(week) <- week_of_year(calendar, year, month, day) do
      {week_year, week, day_of_week(calendar, year, month, day)}
    end
  end

  def week_date_from_date(calendar, year, month, day),
    do: invalid_date(calendar, {year, month, day})

  @doc """
  Returns the number of weeks in a week-year, as `date_from_week_date/4`
  counts them: as many as the year has.

  ### Arguments

  * `calendar` is a calendar module.

  * `week_year` is a week-year of the calendar.

  ### Returns

  * The number of weeks, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Week.weeks_in_week_year(Calendrical.ISOWeek, 2026)
      53

  """
  @spec weeks_in_week_year(calendar, Calendar.year()) :: pos_integer() | {:error, Exception.t()}
  def weeks_in_week_year(calendar, week_year) when is_integer(week_year) do
    case weeks_in_year(calendar, week_year) do
      weeks when is_integer(weeks) -> weeks
      {:error, _reason} -> invalid_date(calendar, week_year: week_year)
    end
  end

  def weeks_in_week_year(calendar, week_year),
    do: invalid_date(calendar, week_year: week_year)

  # The first and last days of a year, in ISO days.
  defp year_bounds(calendar, year) do
    case Common.year_days(calendar, year) do
      {:ok, first, last} -> {:ok, {first, last}}
      {:error, _exception} = error -> error
    end
  end

  defp month_bounds(calendar, year, month) do
    case calendar.month(year, month) do
      %Date.Range{first_in_iso_days: first, last_in_iso_days: last} -> {:ok, {first, last}}
      _no_such_month -> invalid_date(calendar, year: year, month: month)
    end
  end

  # The first day of the week 1 after a year's: the next year's, or, where
  # the calendar has no next year, the week after the one holding the
  # year's last day.
  defp next_week_1(calendar, year, this_week_1, last) do
    case year_bounds(calendar, year + 1) do
      {:ok, {first, _last}} -> first_week_of(calendar, first)
      {:error, _no_such_year} -> week_after(this_week_1, last)
    end
  end

  defp next_month_week_1(calendar, year, month, this_week_1, last) do
    {next_year, next_month} = next_month(calendar, year, month)

    case month_bounds(calendar, next_year, next_month) do
      {:ok, {first, _last}} -> first_week_of(calendar, first)
      {:error, _no_such_month} -> week_after(this_week_1, last)
    end
  end

  # The first day of the week after the one holding a day, in weeks of
  # seven days counted from a week 1.
  defp week_after(week_1, iso_days) do
    week_1 + (div(iso_days - week_1, @days_in_week) + 1) * @days_in_week
  end

  defp weeks_in_year!(calendar, year) do
    case weeks_in_year(calendar, year) do
      weeks when is_integer(weeks) -> weeks
      {:error, _reason} -> 1
    end
  end

  defp weeks_in_month!(calendar, year, month) do
    case month_bounds(calendar, year, month) do
      {:ok, {first, last}} ->
        this_week_1 = first_week_of(calendar, first)
        weeks_between(this_week_1, next_month_week_1(calendar, year, month, this_week_1, last))

      {:error, _no_such_month} ->
        1
    end
  end

  # The weeks from one week 1 to the next: whole weeks, and the short last
  # week of a calendar whose weeks are counted from the period's first day.
  defp weeks_between(this_week_1, next_week_1) do
    div(next_week_1 - this_week_1 + @days_in_week - 1, @days_in_week)
  end

  defp next_month(calendar, year, month) do
    if month < calendar.months_in_year(year), do: {year, month + 1}, else: {year + 1, 1}
  end

  defp previous_month(calendar, year, month) do
    if month > 1, do: {year, month - 1}, else: {year - 1, calendar.months_in_year(year - 1)}
  end

  # The first day of the week 1 that holds, or follows, a period's first
  # day: the week holding it where at least `min_days` of that week are the
  # period's, and otherwise the week after. A calendar whose weeks are
  # counted from the period's first day begins week 1 with it.
  defp first_week_of(calendar, first) do
    case calendar.info().weeks do
      %{first_day: :first_day_of_year} ->
        first

      %{first_day: first_day, min_days_in_first_week: min_days} ->
        start = first - (day_of_week(first, first_day) - 1)
        if first - start <= @days_in_week - min_days, do: start, else: start + @days_in_week
    end
  end

  @doc """
  Returns the day of the week of a date, as `c:Calendar.day_of_week/4`
  answers it: the day's number from the day weeks begin on, with the first
  and the last day of the week.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  * `starting_on` is `:default` for the day the calendar's own weeks begin
    on (`info().weeks.first_day`, or the weekday of the year's first day
    where its weeks are counted from it), or the name of a weekday,
    `:monday` to `:sunday`.

  ### Returns

  * `{day_of_week, 1, 7}`, or `{:error, %Calendrical.InvalidDateError{}}` for a date the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for a missing field.

  ### Examples

      iex> Calendrical.Week.day_of_week(Calendrical.Gregorian, 2026, 1, 1, :default)
      {4, 1, 7}

      iex> Calendrical.Week.day_of_week(Calendrical.Gregorian, 2026, 1, 1, :sunday)
      {5, 1, 7}

  """
  @spec day_of_week(
          calendar,
          Calendar.year(),
          Calendar.month(),
          Calendar.day(),
          :default | atom()
        ) ::
          {Calendar.day_of_week(), 1, 7} | {:error, Exception.t()}
  def day_of_week(calendar, year, month, day, starting_on) do
    with {:ok, iso_days} <- iso_days(calendar, "day_of_week", year, month, day),
         first_day when is_integer(first_day) <- week_begins_on(calendar, year, starting_on) do
      {day_of_week(iso_days, first_day), 1, @days_in_week}
    end
  end

  # The day a calendar's weeks begin on, as a weekday number, for a year:
  # the weekday of the year's first day where weeks are counted from it.
  defp week_begins_on(calendar, year, :default) do
    case calendar.info().weeks.first_day do
      :first_day_of_year -> weekday_of_first_day(calendar, year)
      first_day -> first_day
    end
  end

  defp week_begins_on(_calendar, _year, starting_on) do
    case Enum.find_index(@weekdays, &(&1 == starting_on)) do
      nil -> raise ArgumentError, "starting_on #{inspect(starting_on)} is not supported"
      index -> index + 1
    end
  end

  defp weekday_of_first_day(calendar, year) do
    with %Date.Range{first: first} <- Calendrical.Period.year(calendar, year) do
      Integer.mod(Date.to_gregorian_days(first) + 5, @days_in_week) + 1
    end
  end

  @doc false
  # The day of the week of a day, 1 on the day weeks begin on, from the ISO
  # day of the week: day 0 of the ISO days is a Saturday.
  def day_of_week(iso_days, first_day) do
    Integer.mod(Integer.mod(iso_days + 5, @days_in_week) + 1 - first_day, @days_in_week) + 1
  end

  defp day_of_week(calendar, year, month, day) do
    {day_of_week, _first, _last} = calendar.day_of_week(year, month, day, :default)
    day_of_week
  end

  defp iso_days(calendar, _function, year, month, day)
       when is_integer(year) and is_integer(month) and is_integer(day) do
    if calendar.valid_date?(year, month, day),
      do: {:ok, calendar.date_to_iso_days(year, month, day)},
      else: invalid_date(calendar, {year, month, day})
  end

  # A date missing a field is a partial date, named in the error; a field
  # that is not a number at all is no date.
  defp iso_days(_calendar, function, year, month, day)
       when is_nil(year) or is_nil(month) or is_nil(day),
       do: {:error, Calendrical.missing_date_error(function, year, month, day)}

  defp iso_days(calendar, _function, year, month, day),
    do: invalid_date(calendar, {year, month, day})

  # The dates of the days from `first` to `last`, cut to the days that have
  # a date of their own in a composite calendar, or nil where none has.
  defp range(calendar, first, last) do
    days =
      if Common.composite?(calendar),
        do: Common.dated_days(calendar, first, last),
        else: {first, last}

    case days do
      {first, last} -> Date.range(date(calendar, first), date(calendar, last))
      nil -> nil
    end
  end

  defp invalid_unless_range(%Date.Range{} = range, _calendar, _year, _week), do: range
  defp invalid_unless_range({:error, _exception} = error, _calendar, _year, _week), do: error

  defp invalid_unless_range(_no_range, calendar, year, week),
    do: invalid_date(calendar, year: year, week: week)

  defp invalid_date(calendar, value) do
    {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: value)}
  end

  defp date(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    %Date{year: year, month: month, day: day, calendar: calendar}
  end
end
