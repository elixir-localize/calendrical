defmodule Calendrical.Month do
  @moduledoc """
  The months of any calendar, computed once for every calendar from its
  kernel: how a month is named and numbered, which months a year has and
  which days a month has, and the lengths a month can have.

  A date's month is its position in the year. A calendar names that
  position in two ways. Its traditional number is the number the culture
  gives the month, `n`, or `{n, :leap}` for an intercalary month that
  follows month `n`: in a Chinese year whose leap month follows month 2,
  position 3 is `{2, :leap}` and position 4 is `3`, and in a Hebrew leap
  year position 6, Adar I, is `{5, :leap}`. It follows from one fact the
  calendar states, the position of its leap month
  (`c:Calendrical.leap_month/1`). Its CLDR month is the index of its name
  in the calendar's CLDR data, which is the month a date is written with
  (`c:Calendrical.written_date/3`) in every CLDR calendar but the Hebrew,
  where CLDR gives Adar I a number of its own, so that from Adar on a
  month of an ordinary year is named one more than its place.

  Every function here takes the calendar as its first argument and
  answers for every calendar Calendrical builds. The calendar modules
  carry a delegation to each.

  """

  alias Calendrical.Base.Common

  @typedoc "A calendar module."
  @type calendar :: module()

  @typedoc "A month as a culture names it: its number, or `{number, :leap}` for a leap month."
  @type traditional_month :: Calendar.month() | {Calendar.month(), :leap}

  @typedoc "The lengths a month can have, by month: a count of days, a range of them, or a list of them (`t:Calendrical.Info.month_lengths/0`)."
  @type lengths :: Calendrical.Info.month_lengths()

  # CLDR numbers the Hebrew months 1 (Tishri) to 13 (Elul) with 6 for Adar I,
  # whether or not the year has it, so from Adar on a month of an ordinary
  # year is numbered one more than its position, and month 7 of a leap year
  # takes the leap form of its name, "Adar II".
  @hebrew_adar_i 6
  @hebrew_adar 7

  # The years sampled for the lengths of a calendar's months where it
  # states no lengths and its years run in no cycle: thirty years from the
  # year that holds 1 January 2000.
  @sample_years 30
  @sample_from Calendar.ISO.date_to_iso_days(2000, 1, 1)

  @doc """
  Returns the CLDR month of a month of a year: the index of its name in
  the calendar's CLDR data, with `{month, :leap}` where the name has a
  leap form.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A CLDR month number, or `{month, :leap}`, or

  * `{:error, exception}` for a month the year does not have.

  ### Examples

      # Nisan, the seventh month of an ordinary Hebrew year, is CLDR's month 8
      iex> Calendrical.Month.cldr_month(Calendrical.Hebrew, 5786, 7)
      8

      # The leap month after the second month of a Chinese year
      iex> Calendrical.Month.cldr_month(Calendrical.Chinese, 4660, 3)
      {2, :leap}

      # The first month of a fiscal year that begins in October is named October
      iex> {:ok, us} = Calendrical.FiscalYear.calendar_for(:US)
      iex> Calendrical.Month.cldr_month(us, 2026, 1)
      10

  """
  @spec cldr_month(calendar, Calendar.year(), Calendar.month()) ::
          traditional_month() | {:error, Exception.t()}
  def cldr_month(calendar, year, month) do
    if month_of_year?(calendar, year, month),
      do: cldr_month!(calendar, year, month),
      else: {:error, no_such_month(calendar, year, month)}
  end

  defp cldr_month!(calendar, year, month) do
    if calendar.info().cldr_calendar_type == :hebrew do
      hebrew_cldr_month(calendar, year, month)
    else
      {_year, written_month, _day} = calendar.written_date(year, month, 1)
      written_month
    end
  end

  defp hebrew_cldr_month(calendar, year, month) do
    leap_year? = calendar.months_in_year(year) > calendar.info().months_in_year |> elem(0)

    cond do
      month < @hebrew_adar_i -> month
      leap_year? and month == @hebrew_adar -> {@hebrew_adar, :leap}
      leap_year? -> month
      true -> month + 1
    end
  end

  @doc """
  Returns the CLDR month a month of the year names without a year: the
  name the month carries in the year that holds 1 January 2000, which is
  every year's in a calendar whose months are named alike in every year.
  A Hebrew month is its own number, since which name a place carries
  there depends on the year.

  ### Arguments

  * `calendar` is a calendar module.

  * `month` is a month of the calendar.

  ### Returns

  * A CLDR month number, or the month itself where the calendar has no
    such month in the reference year.

  ### Examples

      iex> {:ok, us} = Calendrical.FiscalYear.calendar_for(:US)
      iex> Calendrical.Month.cldr_month(us, 1)
      10

      iex> Calendrical.Month.cldr_month(Calendrical.Gregorian, 7)
      7

  """
  @spec cldr_month(calendar, Calendar.month()) :: traditional_month()
  def cldr_month(calendar, month) when is_integer(month) do
    if calendar.info().cldr_calendar_type == :hebrew do
      month
    else
      {year, _month, _day} = calendar.date_from_iso_days(@sample_from)

      case cldr_month(calendar, year, month) do
        {:error, _no_such_month} -> month
        cldr_month -> cldr_month
      end
    end
  end

  def cldr_month(_calendar, month), do: month

  @doc """
  Returns the month a CLDR month is written with in a year: the inverse
  of `cldr_month/3` for the figures a date is written with.

  A month's name and its figure are one number in every calendar but the
  Hebrew, where CLDR numbers Nisan 8 in every year and a date writes it
  by its place, 7 in an ordinary year.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `cldr_month` is a CLDR month number, or `{month, :leap}`.

  ### Returns

  * The month as `c:Calendrical.written_date/3` writes it, or

  * `{:error, %Calendrical.InvalidMonthError{}}` where the year has no
    month of that name.

  ### Examples

      iex> Calendrical.Month.written_month_from_cldr_month(Calendrical.Hebrew, 5786, 8)
      7

      iex> Calendrical.Month.written_month_from_cldr_month(Calendrical.Hebrew, 5787, 8)
      8

      iex> Calendrical.Month.written_month_from_cldr_month(Calendrical.Chinese, 4660, {2, :leap})
      {2, :leap}

      iex> Calendrical.Month.written_month_from_cldr_month(Calendrical.Hebrew, 5786, 6)
      {:error, %Calendrical.InvalidMonthError{calendar: Calendrical.Hebrew, year: 5786, month: 6}}

  """
  @spec written_month_from_cldr_month(calendar, Calendar.year(), traditional_month()) ::
          traditional_month() | {:error, Exception.t()}
  def written_month_from_cldr_month(calendar, year, cldr_month) do
    # A number names the leap month of that number where the year has no
    # other: 7 in a Hebrew leap year is Adar II, CLDR's `{7, :leap}`.
    case position_of_cldr_month(calendar, year, cldr_month) do
      nil ->
        {:error, no_such_month(calendar, year, cldr_month)}

      position ->
        {_year, written_month, _day} = calendar.written_date(year, position, 1)
        written_month
    end
  end

  @doc false
  # The position in a year of the month a CLDR month names, or nil.
  def position_of_cldr_month(calendar, year, cldr_month) do
    names =
      for position <- positions(calendar, year), into: %{} do
        {cldr_month!(calendar, year, position), position}
      end

    Map.get(names, cldr_month) || Map.get(names, {cldr_month, :leap})
  end

  @doc """
  Returns a month of a year as the calendar's culture names it: its
  traditional number, or `{month, :leap}` for a leap month.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A `t:traditional_month/0`, or

  * `{:error, exception}` for a month the year does not have.

  ### Examples

      # Adar I, the sixth month of the Hebrew leap year 5787, follows Shevat, month 5
      iex> Calendrical.Month.traditional_month(Calendrical.Hebrew, 5787, 6)
      {5, :leap}

      iex> Calendrical.Month.traditional_month(Calendrical.Hebrew, 5787, 7)
      6

  """
  @spec traditional_month(calendar, Calendar.year(), Calendar.month()) ::
          traditional_month() | {:error, Exception.t()}
  def traditional_month(calendar, year, month) when is_integer(year) and is_integer(month) do
    if month_of_year?(calendar, year, month),
      do: traditional(month, calendar.leap_month(year)),
      else: {:error, no_such_month(calendar, year, month)}
  end

  def traditional_month(calendar, year, month), do: {:error, no_such_month(calendar, year, month)}

  # The traditional number of a position: the position itself before the
  # leap month, the leap month named for the month it follows, and one less
  # than the position after it.
  defp traditional(position, leap_month) when is_integer(leap_month) and position == leap_month,
    do: {position - 1, :leap}

  defp traditional(position, leap_month) when is_integer(leap_month) and position > leap_month,
    do: position - 1

  defp traditional(position, _leap_month), do: position

  @doc """
  Returns the position in a year of a month the calendar's culture
  names: the inverse of `traditional_month/3`.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `traditional_month` is a `t:traditional_month/0`.

  ### Returns

  * The month's position in the year, or

  * `{:error, exception}` where the year has no such month.

  ### Examples

      iex> Calendrical.Month.month_from_traditional(Calendrical.Hebrew, 5787, {5, :leap})
      6

      iex> Calendrical.Month.month_from_traditional(Calendrical.Hebrew, 5786, 6)
      6

  """
  @spec month_from_traditional(calendar, Calendar.year(), traditional_month()) ::
          Calendar.month() | {:error, Exception.t()}
  def month_from_traditional(calendar, year, traditional_month) when is_integer(year) do
    case Enum.find_index(traditional_months(calendar, year), &(&1 === traditional_month)) do
      nil -> {:error, no_such_month(calendar, year, traditional_month)}
      index -> index + 1
    end
  end

  def month_from_traditional(calendar, year, traditional_month),
    do: {:error, no_such_month(calendar, year, traditional_month)}

  @doc """
  Returns a year's months in order, as the calendar's culture names them.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A list of `t:traditional_month/0`, the nth naming the year's nth
    month, and `[]` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Month.traditional_months(Calendrical.Hebrew, 5787)
      [1, 2, 3, 4, 5, {5, :leap}, 6, 7, 8, 9, 10, 11, 12]

  """
  @spec traditional_months(calendar, Calendar.year()) :: [traditional_month()]
  def traditional_months(calendar, year) when is_integer(year) do
    leap_month = calendar.leap_month(year)
    Enum.map(positions(calendar, year), &traditional(&1, leap_month))
  end

  def traditional_months(_calendar, _year), do: []

  @doc """
  Returns the position of a year's leap month, or `nil` where the year
  has none.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * The leap month's position in the year, or `nil`.

  ### Examples

      iex> Calendrical.Month.leap_month(Calendrical.Hebrew, 5787)
      6

      iex> Calendrical.Month.leap_month(Calendrical.Hebrew, 5786)
      nil

      iex> Calendrical.Month.leap_month(Calendrical.Gregorian, 2026)
      nil

  """
  @spec leap_month(calendar, Calendar.year()) :: Calendar.month() | nil
  def leap_month(calendar, year) when is_integer(year), do: calendar.leap_month(year)
  def leap_month(_calendar, _year), do: nil

  @doc """
  Returns the traditional number of the month a year's leap month
  follows, or `nil` where the year has none.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A month number, or `nil`.

  ### Examples

      iex> Calendrical.Month.traditional_leap_month(Calendrical.Hebrew, 5787)
      5

      iex> Calendrical.Month.traditional_leap_month(Calendrical.Chinese, 4660)
      2

  """
  @spec traditional_leap_month(calendar, Calendar.year()) :: Calendar.month() | nil
  def traditional_leap_month(calendar, year) do
    case leap_month(calendar, year) do
      nil -> nil
      position -> position - 1
    end
  end

  @doc """
  Returns the months a year has, as runs of their numbers in order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * A list of ranges: one from 1 in every year of every calendar but a
    composite, whose year a change of calendar falls in has the months
    that are left, and `[]` for a year the calendar does not have.

  ### Examples

      iex> Calendrical.Month.month_numbers(Calendrical.Hebrew, 5787)
      [1..13]

      # England's 1751 began on 25 March and ended on 31 December
      iex> Calendrical.Month.month_numbers(Calendrical.Reform.England, 1751)
      [3..12]

  """
  @spec month_numbers(calendar, Calendar.year()) :: [Range.t()]
  def month_numbers(calendar, year) when is_integer(year) do
    if Common.composite?(calendar) do
      {_fewest, most} = calendar.info().months_in_year
      runs(Enum.filter(1..most//1, &month_with_days?(calendar, year, &1)))
    else
      case calendar.valid_date?(year, 1, 1) and calendar.months_in_year(year) do
        months when is_integer(months) and months > 0 -> [1..months//1]
        _no_such_year -> []
      end
    end
  end

  def month_numbers(_calendar, _year), do: []

  # Whether a month of a composite calendar's year has a day of its own.
  defp month_with_days?(calendar, year, month) do
    Enum.any?(1..31//1, &calendar.valid_date?(year, month, &1))
  end

  @doc """
  Returns the days a month of a year has, as runs of their numbers in
  order.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` and `month` are a month of the calendar.

  ### Returns

  * A list of ranges: one from 1 in every month of every calendar but a
    composite, whose month a change of calendar falls in has the days
    that are left, and `[]` for a month the year does not have.

  ### Examples

      iex> Calendrical.Month.day_numbers(Calendrical.Gregorian, 2026, 2)
      [1..28]

      # England dropped 3 to 13 September 1752
      iex> Calendrical.Month.day_numbers(Calendrical.Reform.England, 1752, 9)
      [1..2, 14..30]

  """
  @spec day_numbers(calendar, Calendar.year(), Calendar.month()) :: [Range.t()]
  def day_numbers(calendar, year, month) when is_integer(year) and is_integer(month) do
    if Common.composite?(calendar) do
      runs(Enum.filter(1..31//1, &calendar.valid_date?(year, month, &1)))
    else
      case calendar.valid_date?(year, month, 1) and calendar.days_in_month(year, month) do
        days when is_integer(days) and days > 0 -> [1..days//1]
        _no_such_month -> []
      end
    end
  end

  def day_numbers(_calendar, _year, _month), do: []

  # Consecutive integers as ranges.
  defp runs([]), do: []

  defp runs(numbers) do
    numbers
    |> Enum.chunk_while(nil, &run_chunk/2, &run_after/1)
    |> Enum.map(fn {first, last} -> first..last//1 end)
  end

  defp run_chunk(number, nil), do: {:cont, {number, number}}
  defp run_chunk(number, {first, last}) when number == last + 1, do: {:cont, {first, number}}
  defp run_chunk(number, run), do: {:cont, run, {number, number}}
  defp run_after(nil), do: {:cont, []}
  defp run_after(run), do: {:cont, run, []}

  @doc """
  Returns the fewest and the most months a year of the calendar has.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * `{fewest, most}`.

  ### Examples

      iex> Calendrical.Month.months_in_year_bounds(Calendrical.Hebrew)
      {12, 13}

      iex> Calendrical.Month.months_in_year_bounds(Calendrical.Reform.England)
      {10, 13}

  """
  @spec months_in_year_bounds(calendar) :: {Calendar.month(), Calendar.month()}
  def months_in_year_bounds(calendar) do
    if Common.composite?(calendar) do
      counts = Enum.map(transition_years(calendar), &length(positions(calendar, &1)))

      {fewest, most} = calendar.info().months_in_year
      {Enum.min([fewest | counts]), Enum.max([most | counts])}
    else
      calendar.info().months_in_year
    end
  end

  @doc """
  Returns the fewest and the most days a month of the calendar has in
  any year.

  ### Arguments

  * `calendar` is a calendar module.

  * `month` is a month of the calendar.

  ### Returns

  * `{fewest, most}`, or

  * `{:error, exception}` for a month the calendar has in no year.

  ### Examples

      iex> Calendrical.Month.days_in_month_bounds(Calendrical.Gregorian, 2)
      {28, 29}

      iex> Calendrical.Month.days_in_month_bounds(Calendrical.Reform.England, 9)
      {19, 30}

  """
  @spec days_in_month_bounds(calendar, Calendar.month()) ::
          {Calendar.day(), Calendar.day()} | {:error, Exception.t()}
  def days_in_month_bounds(calendar, month) when is_integer(month) and month >= 1 do
    case Map.get(lengths(calendar), month) do
      nil -> {:error, no_such_month(calendar, nil, month)}
      days when is_integer(days) -> {days, days}
      first..last//1 -> {first, last}
      lengths when is_list(lengths) -> {List.first(lengths), List.last(lengths)}
    end
  end

  def days_in_month_bounds(calendar, month), do: {:error, no_such_month(calendar, nil, month)}

  @doc """
  Returns the number of days a month of the calendar has without a year:
  a count where the month has as many in every year, and
  `{:ambiguous, range}` where its length depends on the year.

  ### Arguments

  * `calendar` is a calendar module.

  * `month` is a month of the calendar.

  ### Returns

  * A count, `{:ambiguous, range}`, or

  * `{:error, %Calendrical.NotDefinedError{}}` for a month the calendar
    has in no year.

  ### Examples

      iex> Calendrical.Month.days_in_month(Calendrical.Gregorian, 1)
      31

      iex> Calendrical.Month.days_in_month(Calendrical.Gregorian, 2)
      {:ambiguous, 28..29}

  """
  @spec days_in_month(calendar, Calendar.month()) ::
          Calendar.day()
          | {:ambiguous, Range.t() | [Calendar.day(), ...]}
          | {:error, Exception.t()}
  def days_in_month(calendar, month) when is_integer(month) do
    case Map.get(lengths(calendar), month) do
      nil -> days_not_defined(calendar, month)
      days when is_integer(days) -> days
      range -> {:ambiguous, range}
    end
  end

  def days_in_month(calendar, month), do: days_not_defined(calendar, month)

  defp days_not_defined(calendar, month) do
    {:error,
     Calendrical.NotDefinedError.exception(
       calendar: calendar,
       question: :days_in_month,
       value: month
     )}
  end

  @doc """
  Returns the lengths the months of the calendar can have, by month: the
  lengths its `c:Calendrical.info/0` states, or those found by sampling
  its years, once, over one cycle of its years where it has one and
  otherwise over thirty years from the year that holds 1 January 2000.

  ### Arguments

  * `calendar` is a calendar module.

  ### Returns

  * A `t:lengths/0`.

  ### Examples

      iex> Calendrical.Month.lengths(Calendrical.Hebrew) |> Map.take([1, 2, 4])
      %{1 => 30, 2 => 29..30, 4 => 29}

  """
  @spec lengths(calendar) :: lengths()
  def lengths(calendar) do
    case calendar.info().month_lengths do
      %{} = declared -> declared
      nil -> sampled_lengths(calendar)
    end
  end

  defp sampled_lengths(calendar) do
    key = {__MODULE__, :lengths, calendar}

    case :persistent_term.get(key, :none) do
      :none ->
        lengths = sample_lengths(calendar)
        :persistent_term.put(key, lengths)
        lengths

      lengths ->
        lengths
    end
  end

  defp sample_lengths(calendar) do
    years = sample_years(calendar)
    {_fewest, most} = calendar.info().months_in_year

    members =
      if Common.composite?(calendar),
        do: Enum.map(calendar.info().members, &elem(&1, 1)),
        else: []

    for month <- 1..most//1, into: %{} do
      lengths =
        years
        |> Enum.map(&calendar.days_in_month(&1, month))
        |> Enum.concat(Enum.flat_map(members, &member_lengths(&1, month)))
        |> Enum.filter(&(is_integer(&1) and &1 > 0))
        |> Enum.uniq()

      {month, length_of(lengths)}
    end
    |> Map.reject(fn {_month, lengths} -> is_nil(lengths) end)
  end

  defp member_lengths(member, month) do
    case Map.get(lengths(member), month) do
      nil -> []
      days when is_integer(days) -> [days]
      first..last//1 -> [first, last]
      lengths when is_list(lengths) -> lengths
    end
  end

  # One length, a range where every length between the fewest and the most
  # occurs, and otherwise the list of the lengths that do.
  defp length_of([]), do: nil
  defp length_of([days]), do: days

  defp length_of(lengths) do
    sorted = Enum.sort(lengths)
    range = List.first(sorted)..List.last(sorted)//1
    if Enum.to_list(range) == sorted, do: range, else: sorted
  end

  # The years sampled: one cycle from year 1 where the years run in one, the
  # years a composite's changes fall in beside its members' answers, and
  # otherwise thirty years from the reference.
  defp sample_years(calendar) do
    cond do
      Common.composite?(calendar) ->
        transition_years(calendar)

      is_integer(calendar.info().years_in_cycle) ->
        Enum.to_list(1..calendar.info().years_in_cycle//1)

      true ->
        {year, _month, _day} = calendar.date_from_iso_days(@sample_from)
        Enum.to_list(year..(year + @sample_years - 1)//1)
    end
  end

  # The years a composite calendar's changes of calendar fall in, as it
  # labels them: the year of the first day of each member after the base,
  # and of the day before it.
  defp transition_years(calendar) do
    calendar.info().members
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(fn first ->
      {year_from, _month, _day} = calendar.date_from_iso_days(first)
      {year_before, _month, _day} = calendar.date_from_iso_days(first - 1)
      [year_from, year_before]
    end)
    |> Enum.uniq()
  end

  @doc """
  Returns the days of a named month of a year, in the order of time.

  A calendar that counts its months from the year's first day can split
  the month that names them: `Calendrical.Julian.March25` begins its year
  on 25 March, so its March is two counted months.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  * `named_month` is the CLDR month that names the month.

  ### Returns

  * A list of `t:Date.Range.t/0`, one for each counted month that carries
    the name, earliest first, and `[]` where none does.

  ### Examples

      iex> Calendrical.Month.named_month(Calendrical.Julian.March25, 1750, 3) |> length()
      2

      iex> Calendrical.Month.named_month(Calendrical.Gregorian, 2026, 2)
      [Date.range(~D[2026-02-01 Calendrical.Gregorian], ~D[2026-02-28 Calendrical.Gregorian])]

  """
  @spec named_month(calendar, Calendar.year(), Calendar.month()) :: [Date.Range.t()]
  def named_month(calendar, year, named_month) when is_integer(year) do
    for position <- positions(calendar, year),
        named(cldr_month!(calendar, year, position)) == named_month,
        %Date.Range{} = days <- [calendar.month(year, position)],
        do: days
  end

  def named_month(_calendar, _year, _named_month), do: []

  # The number a CLDR month is named by, whether or not it is a leap month.
  defp named({month, :leap}), do: month
  defp named(month), do: month

  @doc false
  # Whether a day names a day of the month for a question that needs no
  # day: a day the month has, or its 1st where the month has days but
  # begins after it, as England's March 1751 begins on the 25th, since a
  # date without a day is asked about as the 1st.
  def day_in_month?(calendar, year, month, day) when is_integer(day) and day >= 1 do
    calendar.valid_date?(year, month, day) or
      (day == 1 and day_numbers(calendar, year, month) != [])
  end

  def day_in_month?(_calendar, _year, _month, _day), do: false

  # The positions a year has, in order.
  defp positions(calendar, year) do
    calendar |> month_numbers(year) |> Enum.flat_map(&Enum.to_list/1)
  end

  defp month_of_year?(calendar, year, month) when is_integer(year) and is_integer(month) do
    Enum.any?(month_numbers(calendar, year), &(month in &1))
  end

  defp month_of_year?(_calendar, _year, _month), do: false

  defp no_such_month(calendar, year, month) do
    Calendrical.InvalidMonthError.exception(calendar: calendar, year: year, month: month)
  end
end
