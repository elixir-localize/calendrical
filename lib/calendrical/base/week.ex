defmodule Calendrical.Base.Week do
  @moduledoc false

  alias Calendar.ISO
  alias Calendrical.Config
  alias Localize.Utils.Math

  import Calendrical,
    only: [missing_date_error: 4, missing_day_error: 2, missing_year_error: 2]

  import Calendrical.Base.Common, only: [is_date: 3]

  @days_in_week 7
  @weeks_in_quarter 13
  @months_in_quarter 3
  @months_in_year 12
  @weeks_in_long_year 53
  @weeks_in_normal_year 52
  @quarters_in_year 4

  # Whether to clamp valid date with plus/3 for
  # years and months (days, weeks dont ever require
  # clamping).
  @default_clamp Calendrical.default_clamp()

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      @options options
      @before_compile Calendrical.Compiler.Week
      @before_compile Calendrical.Compiler.DateCheck
    end
  end

  # A date of a calendar of weeks is a year, a month of its pattern of weeks
  # (4-4-5 and its kin) and a day of that month, as a date of any calendar
  # is a year, a month and a day. The arithmetic of this module counts in
  # weeks, as the calendar is built: a date comes to it as its year, its
  # week and its day of the week (`week_date/4`), and a date it answers
  # with goes back as a month and a day (`month_date/4`). Until 1.4 the
  # week and the day of the week were the fields of the date themselves.

  @doc false
  # The year, the week and the day of the week of a year, a month and a day
  # of the month. What is no date of whole numbers is given back as it is,
  # for the function that takes it to refuse.
  def week_date(year, month, day, config)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    week = first_week_of_month(month, config) + Integer.floor_div(day - 1, days_in_week())
    {year, week, Integer.mod(day - 1, days_in_week()) + 1}
  end

  def week_date(year, month, day, _config) do
    {year, month, day}
  end

  @doc false
  # The year, the month and the day of the month of a year, a week and a day
  # of the week: the inverse of `week_date/4`.
  def month_date(year, week, day, config)
      when is_integer(year) and is_integer(week) and is_integer(day) do
    month = month_of_year(year, week, day, config)
    {year, month, (week - first_week_of_month(month, config)) * days_in_week() + day}
  end

  def month_date(year, week, day, _config) do
    {year, week, day}
  end

  @doc false
  # The week of the year a month begins with: the weeks of the quarters
  # before it and of the months before it in its own quarter.
  def first_week_of_month(month, %Config{weeks_in_month: weeks_in_month}) do
    quarters_before = Integer.floor_div(month - 1, @months_in_quarter)
    months_before = Integer.mod(month - 1, @months_in_quarter)

    weeks_before =
      weeks_in_month
      |> Enum.take(months_before)
      |> Enum.sum()

    quarters_before * @weeks_in_quarter + weeks_before + 1
  end

  @doc false
  # The date of a day of a week of a year, and the year, the week and the
  # day of the week of a date: a calendar of weeks' week dates are counted
  # in its own weeks, the day from the day its weeks begin on.
  def date_from_week_date(year, week, day, config) do
    if valid_week_date?(year, week, day, config) do
      {year, month, day} = month_date(year, week, day, config)
      %Date{year: year, month: month, day: day, calendar: config.calendar}
    else
      {:error, :invalid_date}
    end
  end

  @doc false
  def week_date_from_date(year, month, day, config) do
    if valid_date?(year, month, day, config) do
      week_date(year, month, day, config)
    else
      {:error, :invalid_date}
    end
  end

  def valid_date?(year, month, day, config)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    month in 1..@months_in_year and day in 1..days_in_month(year, month, config)
  end

  def valid_date?(_year, _month, _day, _config), do: false

  @doc false
  # Whether a year, a week and a day of the week name a day of the calendar.
  def valid_week_date?(year, week, day, config)
      when is_integer(year) and is_integer(week) and is_integer(day) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)
    week in 1..weeks_in_year and day in 1..days_in_week()
  end

  def valid_week_date?(_year, _week, _day, _config), do: false

  # Year of era assumes that the era transitions are always aligned
  # to the calendar year. But for 445 type calendar and country fiscal
  # calendars this is not necessarily true. So we have to decide whether
  # the beginning or ending Gregorian year is the year we consider.

  defdelegate year_of_era(year, config), to: Calendrical.Base.Common

  # Quarters are 13 weeks but if there
  # are 53 weeks in a year then 4th
  # quarter is longer
  def quarter_of_year(_year, @weeks_in_long_year, _day, _config) do
    4
  end

  def quarter_of_year(_year, week, _day, _config) do
    div(week - 1, @weeks_in_quarter) + 1
  end

  def month_of_year(_year, @weeks_in_long_year, _day, _config) do
    12
  end

  def month_of_year(year, week, day, %Config{weeks_in_month: weeks_in_month} = config) do
    quarter = quarter_of_year(year, week, day, config)
    months_in_prior_quarters = (quarter - 1) * @months_in_quarter

    week_in_quarter = Math.amod(week, @weeks_in_quarter)
    [m1, m2, _m3] = weeks_in_month

    month_in_quarter =
      cond do
        week_in_quarter <= m1 -> 1
        week_in_quarter <= m1 + m2 -> 2
        true -> 3
      end

    months_in_prior_quarters + month_in_quarter
  end

  # A year that begins in another month than the first numbers its months
  # from there, so its first month is the Gregorian month it begins in.
  def cardinal_month(month, %Config{month_of_year: 1}), do: month

  def cardinal_month(month, %Config{month_of_year: month_of_year}),
    do: Math.amod(month + month_of_year - 1, @months_in_year)

  # The day of the week of an ISO day number from a day weeks begin on:
  # day 0 of the ISO days is a Saturday, so the offset carries it to 6.
  defp iso_days_to_day_of_week(iso_days, starting_on, config),
    do: Integer.mod(iso_days + day_of_week_offset(starting_on, config), 7) + 1

  defp day_of_week_offset(:default, config), do: 6 - config.day_of_week
  defp day_of_week_offset(:monday, _config), do: 5
  defp day_of_week_offset(:tuesday, _config), do: 4
  defp day_of_week_offset(:wednesday, _config), do: 3
  defp day_of_week_offset(:thursday, _config), do: 2
  defp day_of_week_offset(:friday, _config), do: 1
  defp day_of_week_offset(:saturday, _config), do: 0
  defp day_of_week_offset(:sunday, _config), do: 6

  defp day_of_week_offset(starting_on, _config),
    do: raise(ArgumentError, "starting_on #{inspect(starting_on)} is not supported")

  # The month of the year a Gregorian month names: the inverse of
  # `cardinal_month/2`.
  def month_from_cardinal_month(named_month, %Config{month_of_year: month_of_year})
      when is_integer(named_month) and named_month in 1..@months_in_year do
    Math.amod(named_month - month_of_year + 1, @months_in_year)
  end

  def month_from_cardinal_month(named_month, _config), do: named_month

  def week_of_year(year, week, _day, _config) when is_integer(year) and is_integer(week) do
    {year, week}
  end

  def week_of_year(year, week, day, _config) do
    {:error, missing_date_error("week_of_year", year, week, day)}
  end

  def iso_week_of_year(year, week, day, config) when is_date(year, week, day) do
    if valid_week_date?(year, week, day, config) do
      {year, month, day} =
        year
        |> date_to_iso_days(week, day, config)
        |> Calendrical.Gregorian.date_from_iso_days()

      Calendrical.Gregorian.iso_week_of_year(year, month, day)
    else
      {:error, :invalid_date}
    end
  end

  def iso_week_of_year(year, week, day, _config) do
    {:error, missing_date_error("iso_week_of_year", year, week, day)}
  end

  def week_of_month(year, week, day, config) when is_date(year, week, day) do
    month = month_of_year(year, week, day, config)
    {month, week - first_week_of_month(month, config) + 1}
  end

  def week_of_month(year, week, day, _config) do
    {:error, missing_date_error("week_of_month", year, week, day)}
  end

  # The era is the calendar year's, as `year_of_era/3` gives it: era 1
  # counts from the first day of calendar year 1 and era 0 back from the
  # last day of calendar year 0, as `Calendar.ISO` counts its days.
  def day_of_era(year, week, day, config) when is_date(year, week, day) do
    iso_days = date_to_iso_days(year, week, day, config)

    if year >= 1,
      do: {iso_days - first_gregorian_day_of_year(1, config) + 1, 1},
      else: {last_gregorian_day_of_year(0, config) - iso_days + 1, 0}
  end

  def day_of_era(year, week, day, _config) do
    {:error, missing_date_error("day_of_era", year, week, day)}
  end

  def day_of_year(year, week, day, _config) when is_date(year, week, day) do
    trunc(week_to_days(week) + day)
  end

  def day_of_year(year, week, day, _config) do
    {:error, missing_date_error("day_of_year", year, week, day)}
  end

  def day_of_week(_year, _week, day, :default, _config) when is_integer(day) do
    day
  end

  def day_of_week(year, week, day, starting_on, config) when is_date(year, week, day) do
    iso_days = date_to_iso_days(year, week, day, config)
    iso_days_to_day_of_week(iso_days, starting_on, config)
  end

  def day_of_week(_year, _week, day, _starting_on, _config) do
    {:error, missing_day_error("day_of_week", day)}
  end

  def months_in_year(year, _config) when is_integer(year) do
    Calendar.ISO.months_in_year(year)
  end

  def months_in_year(year, _config) do
    {:error, missing_year_error("months_in_year", year)}
  end

  # Year-less: week-based calendars carry the fixed 12-month year
  # structure, so the count is year-invariant.
  def months_in_year(config) when is_map(config) do
    @months_in_year
  end

  def weeks_in_year(year, config) when is_integer(year) do
    if long_year?(year, config), do: weeks_in_long_year(), else: weeks_in_normal_year()
  end

  def weeks_in_year(year, _config) do
    {:error, missing_year_error("weeks_in_year", year)}
  end

  def weeks_in_long_year do
    {@weeks_in_long_year, @days_in_week}
  end

  def weeks_in_normal_year do
    {@weeks_in_normal_year, @days_in_week}
  end

  def weeks_in_quarter(year, quarter, config) do
    if quarter == @quarters_in_year && long_year?(year, config) do
      @weeks_in_quarter + 1
    else
      @weeks_in_quarter
    end
  end

  def days_in_year(year, config) when is_integer(year) do
    if long_year?(year, config) do
      @weeks_in_long_year * @days_in_week
    else
      @weeks_in_normal_year * @days_in_week
    end
  end

  def days_in_year(year, _config) do
    {:error, missing_year_error("days_in_year", year)}
  end

  # The days of a month of a year: those of the weeks its pattern gives it.
  def days_in_month(year, month, config)
      when is_integer(year) and is_integer(month) and month in 1..@months_in_year do
    days_in_pattern_month(year, month, config)
  end

  def days_in_month(year, _month, _config) when is_integer(year) do
    {:error, :invalid_date}
  end

  def days_in_month(year, _month, _config) do
    {:error, missing_year_error("days_in_month", year)}
  end

  # Without a year a month has the days of its weeks, and the last month one
  # week more in a long year.
  def days_in_month(@months_in_year, %Config{weeks_in_month: [_, _, weeks_in_last_month]}) do
    days = weeks_in_last_month * days_in_week()
    {:ambiguous, [days, days + days_in_week()]}
  end

  def days_in_month(month, config) when month in 1..@months_in_year do
    days_in_pattern_month(nil, month, config)
  end

  def days_in_month(month, _config) when is_integer(month) do
    {:error, :undefined}
  end

  def days_in_month(month, _config) do
    {:error, missing_year_error("days_in_month", month)}
  end

  # The days of a month of the calendar's pattern of weeks, `month` being
  # its place in the year, 1 to 12: four or five weeks as the pattern gives
  # them, and one more in the last month of a long year. Month arithmetic
  # counts with it.
  def days_in_pattern_month(year, @months_in_year, config) do
    %Config{weeks_in_month: [_, _, weeks_in_last_month]} = config
    weeks = if long_year?(year, config), do: weeks_in_last_month + 1, else: weeks_in_last_month
    trunc(weeks * days_in_week())
  end

  def days_in_pattern_month(_year, month, config) do
    %Config{weeks_in_month: weeks_in_month} = config
    month_in_quarter = Math.amod(rem(month, @months_in_quarter), @months_in_quarter)
    (Enum.at(weeks_in_month, month_in_quarter - 1) * days_in_week()) |> trunc()
  end

  defdelegate days_in_week(), to: Calendrical.Base.Common
  defdelegate days_in_week(year, week), to: Calendrical.Base.Common

  def year(year, config) do
    with {weeks_in_year, _} <- weeks_in_year(year, config) do
      weeks(year, 1, weeks_in_year, config)
    end
  end

  # The dates from the first day of a week of a year to the last day of
  # another, or `{:error, :invalid_date}` where the year does not have them.
  defp weeks(year, first_week, last_week, config) do
    with {:ok, first_day} <- date_of_week_date(year, first_week, 1, config),
         {:ok, last_day} <- date_of_week_date(year, last_week, days_in_week(), config) do
      Date.range(first_day, last_day)
    end
  end

  defp date_of_week_date(year, week, day, config) do
    if valid_week_date?(year, week, day, config) do
      {year, month, day} = month_date(year, week, day, config)
      Date.new(year, month, day, config.calendar)
    else
      {:error, :invalid_date}
    end
  end

  def quarter(year, quarter, config) do
    if quarter in 1..@quarters_in_year do
      starting_week = (quarter - 1) * @weeks_in_quarter + 1
      ending_week = starting_week + weeks_in_quarter(year, quarter, config) - 1

      weeks(year, starting_week, ending_week, config)
    else
      {:error, :invalid_date}
    end
  end

  def month(year, month, %{weeks_in_month: weeks_in_month} = config) do
    if month in 1..months_in_year(year, month) do
      months_prior_in_quarter = rem(month - 1, @months_in_quarter)
      prior_quarters = ceil(month / (months_in_year(year, config) / @quarters_in_year)) - 1
      quarter_weeks_prior = prior_quarters * @weeks_in_quarter

      weeks_prior_in_quarter =
        weeks_in_month
        |> Enum.take(months_prior_in_quarter)
        |> Enum.sum()

      weeks_in_month =
        Enum.at(weeks_in_month, months_prior_in_quarter) +
          maybe_extra_week_for_long_year(year, month, config)

      first_week = quarter_weeks_prior + weeks_prior_in_quarter + 1
      last_week = first_week + weeks_in_month - 1

      weeks(year, first_week, last_week, config)
    else
      {:error, :invalid_date}
    end
  end

  def week(year, week, config) do
    {weeks_in_year, _days_in_last_week} = weeks_in_year(year, config)

    if week in 1..weeks_in_year do
      weeks(year, week, week, config)
    else
      {:error, :invalid_date}
    end
  end

  # A year on, a day keeps its week and its day of the week, and a day of a
  # fifty-third week is brought into the last week of a year that has
  # fifty-two.
  def shift(year, week, day, config, :years, years, options) do
    new_year = year + years

    if Keyword.get(options, :clamp, @default_clamp) do
      {weeks_in_year, _days_in_last_week} = weeks_in_year(new_year, config)
      {new_year, min(week, weeks_in_year), day}
    else
      {new_year, week, day}
    end
  end

  def shift(year, week, day, config, :quarters, quarters, options) do
    shift(year, week, day, config, :months, quarters * @months_in_quarter, options)
  end

  def shift(year, week, day, _config, :months, 0, _options) do
    {year, week, day}
  end

  # When adding a month the process is
  # 1. Capture the day of the month
  # 2. Get the first day of that month
  # 3. Add the number of days in that month leaving us
  #    with the first day of the next month
  # 4. Add back the day of the month, potentially
  #    clamping the last day of the month
  def shift(year, week, day, config, :months, 1 = n, options) do
    day_of_month = day_of_month(year, week, day, config)
    {year, week, day} = first_day_of_month(year, week, day, config)

    month_of_year = month_of_year(year, week, day, config)
    month_in_quarter = month_in_quarter(week, config)

    weeks_to_add =
      slice_weeks(month_in_quarter - 1, n, config) +
        maybe_extra_week_for_long_year(year, month_of_year, config)

    {weeks_in_year, _} = weeks_in_year(year, config)
    {year_increment, week} = Localize.Utils.Math.div_mod(week + weeks_to_add, weeks_in_year)
    add_days(year + year_increment, week, day, day_of_month - 1, config, options)
  end

  # WHen subtracting a month the process is
  # 1. Work out the day of the month of the provided date
  # 2. Get the last day of the month
  # 3. Subtract the number of days in the month, leaving us with
  #    the last day of the previous month
  # 4. Get the first day of the previous month
  # 5. Add back the day of the month capture earlier - potentially clamping
  #    the last day of the month
  def shift(year, week, day, config, :months, -1 = n, options) do
    day_of_month = day_of_month(year, week, day, config)
    {year, week, day} = last_day_of_month(year, week, day, config)
    month_of_year = month_of_year(year, week, day, config)
    month_in_quarter = month_in_quarter(week, config)

    weeks_to_sub =
      slice_weeks(month_in_quarter - 1, abs(n), config) +
        maybe_extra_week_for_long_year(year, month_of_year, config)

    week = week - weeks_to_sub
    {weeks_in_year, _} = weeks_in_year(year - 1, config)

    {year, week} =
      if week < 1 do
        {year - 1, weeks_in_year - week}
      else
        {year, week}
      end

    {year, week, day} = first_day_of_month(year, week, day, config)
    add_days(year, week, day, day_of_month - 1, config, options)
  end

  # Accounting for long years is complex, so several months are walked one
  # at a time, from the first day of each month to the first day of the
  # next, and the day of the month is placed once, in the month reached. A
  # shorter month on the way does not take the day with it: the last day of
  # a five-week month is the last day of a five-week month three months on.
  def shift(year, week, day, config, :months, months, options) when abs(months) > 1 do
    increment = if months > 0, do: 1, else: -1
    day_of_month = day_of_month(year, week, day, config)
    first_day = first_day_of_month(year, week, day, config)

    {year, week, day} =
      Enum.reduce(1..abs(months), first_day, fn _i, {year, week, day} ->
        shift(year, week, day, config, :months, increment, clamp: @default_clamp)
      end)

    add_days(year, week, day, day_of_month - 1, config, options)
  end

  def shift(year, month, day, config, :weeks, weeks, _options) do
    year
    |> date_to_iso_days(month, day, config)
    |> Kernel.+(Calendrical.weeks_to_days(weeks))
    |> date_from_iso_days(config)
  end

  def shift(year, month, day, config, :days, days, _options) do
    year
    |> date_to_iso_days(month, day, config)
    |> Kernel.+(days)
    |> date_from_iso_days(config)
  end

  def add(naive_datetime, :year, step) do
    shifted = Date.shift(naive_datetime, year: step)
    %{naive_datetime | year: shifted.year, month: shifted.month, day: shifted.day}
  end

  def day_of_month(year, week, day, config) do
    first_day = first_day_of_month(year, week, day, config)
    date_diff({year, week, day}, first_day, config) + 1
  end

  def date_diff({y2, w2, d2}, {y1, w1, d1}, config) do
    date_to_iso_days(y2, w2, d2, config) - date_to_iso_days(y1, w1, d1, config)
  end

  def add_days(year, week, day, days, config, options \\ [])

  def add_days(year, week, day, 0, _config, _options) do
    {year, week, day}
  end

  def add_days(year, week, day, days, config, options) do
    days_to_add =
      if Keyword.get(options, :clamp, @default_clamp) do
        month = month_of_year(year, week, day, config)
        min(days_in_pattern_month(year, month, config) - 1, days)
      else
        days
      end

    iso_days = date_to_iso_days(year, week, day, config) + days_to_add
    date_from_iso_days(iso_days, config)
  end

  def slice_weeks(from, n, %{weeks_in_month: weeks_in_month}) do
    {_, weeks} = Enum.split(weeks_in_month, from)

    weeks
    |> Enum.take(n)
    |> Enum.sum()
  end

  def first_day_of_month(year, week, day, config) do
    quarters = quarter_of_year(year, week, day, config) - 1
    month_in_quarter = month_in_quarter(week, config) - 1
    week = quarters * @weeks_in_quarter + weeks_from_months(month_in_quarter, config) + 1
    {year, week, 1}
  end

  def last_day_of_month(year, week, day, config) do
    {year, week, day} = first_day_of_month(year, week, day, config)
    month_of_year = month_of_year(year, week, day, config)
    days_in_month = days_in_pattern_month(year, month_of_year, config)
    add_days(year, week, day, days_in_month - 1, config)
  end

  def month_in_quarter(week, _config) when week == @weeks_in_long_year do
    @months_in_quarter
  end

  def month_in_quarter(week, config) do
    week_in_quarter = Localize.Utils.Math.amod(week, @weeks_in_quarter)
    month_from_weeks(week_in_quarter, config)
  end

  # Sums the weeks of the first `months` months of a quarter.
  # `months` is always in 0..2: every caller passes
  # `month_from_weeks(...) - 1` (or `month_in_quarter(...) - 1`),
  # and those functions return a month index in 1..3.
  def weeks_from_months(0, _config) do
    0
  end

  def weeks_from_months(months, %{weeks_in_month: weeks_in_month}) when months > 0 do
    weeks_in_month
    |> Enum.take(months)
    |> Enum.sum()
  end

  # For weeks <= 13
  def month_from_weeks(weeks, %Config{weeks_in_month: [m1, m2, m3]})
      when weeks <= @weeks_in_quarter do
    cond do
      weeks <= m1 -> 1
      weeks <= m1 + m2 -> 2
      weeks <= m1 + m2 + m3 -> 3
    end
  end

  def sign(number) when number < 0, do: -1
  def sign(_number), do: +1

  def first_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)

    %{
      month_of_year: first_month,
      day_of_week: first_day,
      min_days_in_first_week: min_days
    } = config

    iso_days = ISO.date_to_iso_days(year, first_month, min_days)
    day_of_week = Calendrical.iso_days_to_day_of_week(iso_days)

    # The iso_days calculation is the last possible first day of the first week
    # All starting days are less than or equal to this day
    if first_day > day_of_week do
      iso_days + (first_day - days_in_week() - day_of_week)
    else
      iso_days - (day_of_week - first_day)
    end
  end

  def first_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    last_gregorian_day_of_year(year - 1, config) + 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    first_gregorian_day_of_year(year + 1, config) - 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)

    %{
      month_of_year: last_month,
      day_of_week: last_day,
      min_days_in_first_week: min_days
    } = config

    days_in_last_month = ISO.days_in_month(year, last_month)
    iso_days = ISO.date_to_iso_days(year, last_month, days_in_last_month - min_days)
    day_of_week = Calendrical.iso_days_to_day_of_week(iso_days)

    if last_day <= day_of_week do
      iso_days - (day_of_week - last_day) + days_in_week()
    else
      iso_days - (day_of_week - last_day)
    end
  end

  def long_year?(year, %Config{} = config) do
    first_day = first_gregorian_day_of_year(year, config)
    last_day = last_gregorian_day_of_year(year, config)
    days_in_year = last_day - first_day + 1
    div(days_in_year, days_in_week()) == @weeks_in_long_year
  end

  def date_to_iso_days(year, week, day, config) do
    {days, _day_fraction} = naive_datetime_to_iso_days(year, week, day, 0, 0, 0, {0, 6}, config)
    days
  end

  def date_from_iso_days(iso_day_number, config) do
    {year, week, day, _, _, _, _} = naive_datetime_from_iso_days({iso_day_number, {0, 6}}, config)
    {year, week, day}
  end

  # A date is written as its year, its month and its day, as `Calendar.ISO`
  # writes one: "2026-06-16". Until 1.4 it was written as the week date it
  # then held, "2026-W25-2", which `Calendrical.Parse.parse_week_date/2`
  # still reads.
  defdelegate date_to_string(year, month, day), to: Calendar.ISO

  def naive_datetime_from_iso_days({days, day_fraction}, config) do
    {year, _month, _day} = Calendar.ISO.date_from_iso_days(days)
    first_day = first_gregorian_day_of_year(year, config)

    {year, first_day} =
      cond do
        first_day > days ->
          {year - 1, first_gregorian_day_of_year(year - 1, config)}

        days - first_day + 1 > config.calendar.days_in_year(year) ->
          {year + 1, first_gregorian_day_of_year(year + 1, config)}

        true ->
          {year, first_day}
      end

    day_of_year = days - first_day + 1
    week = trunc(Float.ceil(day_of_year / days_in_week()))
    day = day_of_year - (week - 1) * days_in_week()

    {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
    {year, week, day, hour, minute, second, microsecond}
  end

  def naive_datetime_to_iso_days(year, week, day, hour, minute, second, microsecond, config) do
    days = first_gregorian_day_of_year(year, config) + week_to_days(week) + day - 1
    day_fraction = Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)
    {days, day_fraction}
  end

  def datetime_to_string(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond,
        time_zone,
        zone_abbr,
        utc_offset,
        std_offset
      ) do
    date_to_string(year, month, day) <>
      " " <>
      Calendar.ISO.time_to_string(hour, minute, second, microsecond) <>
      Calendrical.offset_to_string(utc_offset, std_offset, time_zone) <>
      Calendrical.zone_to_string(utc_offset, std_offset, zone_abbr, time_zone)
  end

  def naive_datetime_to_string(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond
      ) do
    date_to_string(year, month, day) <>
      " " <>
      Calendar.ISO.time_to_string(hour, minute, second, microsecond)
  end

  defp week_to_days(week) do
    (week - 1) * days_in_week()
  end

  defp maybe_extra_week_for_long_year(year, @months_in_year, config) do
    if long_year?(year, config), do: 1, else: 0
  end

  defp maybe_extra_week_for_long_year(_year, _month, _config) do
    0
  end
end
