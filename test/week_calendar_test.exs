defmodule Calendrical.Week.Test do
  use ExUnit.Case, async: true
  import Calendrical.Helper
  alias Calendrical.Test.Calendars

  # The last month of a calendar's pattern of weeks takes a long year's
  # extra week: four weeks become five, or five six. A month's days are
  # those of its `month/2`, which `days_in_month/2` counts (below).
  test "that the last month of a long year is 35 or 42 days" do
    assert Enum.count(Calendrical.NRF.month(2012, 12)) == 35
    assert Enum.count(Calendrical.ISOWeek.month(2015, 12)) == 35

    assert Enum.count(Calendrical.NRF.month(2013, 12)) == 28
    assert Enum.count(Calendrical.ISOWeek.month(2016, 12)) == 28

    assert Enum.count(Calendars.Sunday.month(2012, 12)) == 42
    assert Enum.count(Calendars.Sunday.month(2013, 12)) == 35
  end

  # A date's month field is its month, and it is that field Elixir's
  # `Date.days_in_month/1` and `Date.end_of_month/1` put to
  # `days_in_month/2`: a month has the days of its weeks and ends on the
  # last day of a week. 2026 has 53 ISO weeks and 2025 has 52.
  test "that a month has the days of its weeks, so Elixir's Date functions name its ends" do
    for calendar <- [Calendrical.ISOWeek, Calendrical.NRF, Calendars.Sunday],
        month <- 1..12 do
      days = calendar.days_in_month(2026, month)
      date = Date.new!(2026, month, 3, calendar)

      assert days == Enum.count(calendar.month(2026, month)),
             "#{inspect(calendar)} month #{month}"

      assert rem(days, 7) == 0
      assert Date.days_in_month(date) == days
      assert Calendrical.days_in_month(date) == days
      assert Date.beginning_of_month(date) == Date.new!(2026, month, 1, calendar)
      assert Date.end_of_month(date) == Date.new!(2026, month, days, calendar)
      assert Date.end_of_week(Date.end_of_month(date)) == Date.end_of_month(date)
    end

    assert Calendrical.ISOWeek.days_in_month(2026, 12) == 35
    assert Calendrical.ISOWeek.days_in_month(2025, 12) == 28

    assert {:error, %Calendrical.InvalidMonthError{year: 2026, month: 13}} =
             Calendrical.ISOWeek.days_in_month(2026, 13)

    assert {:error, %Calendrical.InvalidMonthError{year: 2026, month: 0}} =
             Calendrical.ISOWeek.days_in_month(2026, 0)

    assert {:error, %Calendrical.MissingFieldsError{}} =
             Calendrical.ISOWeek.days_in_month(nil, 6)
  end

  # A date of a calendar of weeks is a year, a month of its pattern and a
  # day of that month: the third day of week 25 is the 17th of the sixth
  # month. The fields its dates held until 1.4, a week and a day of it, are
  # no date now.
  test "that a year has the twelve months of its pattern" do
    date = week_date(2026, 25, 3, Calendrical.ISOWeek)

    assert {date.month, date.day} == {6, 17}
    assert Date.months_in_year(date) == 12
    assert Calendrical.ISOWeek.months_in_year() == 12
    assert Calendrical.ISOWeek.weeks_in_year(2026) == 53
    assert Calendrical.month_of_year(date) == 6
    assert Calendrical.week_of_year(date) == {2026, 25}

    assert Date.new(2026, 25, 3, Calendrical.ISOWeek) == {:error, :invalid_date}
    assert Calendrical.ISOWeek.month_numbers(2026) == [1..12]
    assert Calendrical.ISOWeek.day_numbers(2026, 6) == [1..28]
    assert Calendrical.ISOWeek.day_numbers(2026, 12) == [1..35]
  end

  # Day of week is always the ordinal day. And therefore for
  # week based calendars is just `day`.

  test "day of week for ISOWeek calendar is correct" do
    assert Calendrical.day_of_week(date(2019, 01, 01, Calendrical.ISOWeek)) == 1
  end

  test "day of week for NRF calendar is correct" do
    assert Calendrical.day_of_week(date(2019, 01, 01, Calendrical.NRF)) == 1
  end

  test "day of week for Sunday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Sunday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Saturday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Saturday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Friday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Friday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Thursday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Thursday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Wednesday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Wednesday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Tuesday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Tuesday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "day of week for Monday calendar is correct" do
    {:ok, date} = Date.new(2019, 1, 1, Calendars.Monday)
    assert Calendrical.day_of_week(date) == 1
  end

  test "tuesday week calendar" do
    today = week_date(2019, 13, 4, Calendars.Tuesday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == week_date(2018, 13, 4, Calendars.Tuesday)
  end

  test "wednesday week calendar" do
    today = week_date(2019, 13, 4, Calendars.Wednesday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == week_date(2018, 13, 4, Calendars.Wednesday)
  end

  test "thursday week calendar" do
    today = week_date(2019, 13, 4, Calendars.Thursday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == week_date(2018, 13, 4, Calendars.Thursday)
  end

  test "friday week calendar" do
    today = week_date(2019, 13, 4, Calendars.Friday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == week_date(2018, 13, 4, Calendars.Friday)
  end

  test "saturday week calendar" do
    today = week_date(2019, 13, 4, Calendars.Saturday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == week_date(2018, 13, 4, Calendars.Saturday)
  end

  test "sunday week calendar" do
    today = week_date(2018, 53, 3, Calendars.Sunday)
    current_period = Calendrical.Interval.month(today)
    first_day_of_period = current_period.first
    last_day_of_period = current_period.last
    assert first_day_of_period == week_date(2018, 48, 1, Calendars.Sunday)
    assert last_day_of_period == week_date(2018, 53, 7, Calendars.Sunday)
    assert {first_day_of_period.month, first_day_of_period.day} == {12, 1}
    assert {last_day_of_period.month, last_day_of_period.day} == {12, 42}
  end

  test "that previous month and next month actually are for a week calendar" do
    {:ok, today} = Date.new(2019, 4, 4)
    {:ok, today} = Date.convert(today, Calendars.Sunday)
    this_period = Calendrical.Interval.month(today)

    previous = Calendrical.previous(this_period, :month, clamp: true)
    assert previous.first == week_date(2018, 44, 1, Calendars.Sunday)
    assert previous.last == week_date(2018, 47, 7, Calendars.Sunday)

    next = Calendrical.next(this_period, :month, clamp: true)
    assert next.first == week_date(2019, 1, 1, Calendars.Sunday)
    assert next.last == week_date(2019, 4, 7, Calendars.Sunday)
  end

  test "previous month for a week calendar transitioning to prior quarter" do
    {:ok, today} = Date.convert(~D[2019-04-11], Calendars.Monday)
    prior_period_day = Calendrical.previous(today, :month, clamp: true)
    prior_period = Calendrical.Interval.month(prior_period_day)

    last_day_of_prior_period = prior_period.last
    {:ok, gregorian_prior_last} = Date.convert(last_day_of_prior_period, Calendrical.Gregorian)

    assert gregorian_prior_last == %Date{
             calendar: Calendrical.Gregorian,
             day: 7,
             month: 4,
             year: 2019
           }
  end

  # Without a year a month has the days of its weeks, and the last month
  # one week more in a long year.
  test "days in a month without its year" do
    {:ok, calendar} = Calendrical.new(__MODULE__.FourFourFive, :week, pattern: [4, 4, 5])

    for {month, days} <- [{1, 28}, {2, 28}, {3, 35}, {10, 28}, {11, 28}] do
      assert calendar.days_in_month(month) == days
    end

    assert calendar.days_in_month(12) == {:ambiguous, [35, 42]}
    assert {:error, %Calendrical.NotDefinedError{}} = calendar.days_in_month(13)
    assert {:error, %Calendrical.NotDefinedError{}} = calendar.days_in_month(0)
    assert Calendrical.ISOWeek.days_in_month(6) == 28
    assert Calendrical.ISOWeek.days_in_month(12) == {:ambiguous, [28, 35]}
  end
end
