defmodule Calendrical.Week.Test do
  use ExUnit.Case, async: true
  import Calendrical.Helper
  alias Calendrical.Test.Calendars

  # The last month of a calendar's pattern of weeks takes a long year's
  # extra week: four weeks become five, or five six. A month's days are
  # those of its `month/2`; `days_in_month/2` counts a week's (below).
  test "that the last month of a long year is 35 or 42 days" do
    assert Enum.count(Calendrical.NRF.month(2012, 12)) == 35
    assert Enum.count(Calendrical.ISOWeek.month(2015, 12)) == 35

    assert Enum.count(Calendrical.NRF.month(2013, 12)) == 28
    assert Enum.count(Calendrical.ISOWeek.month(2016, 12)) == 28

    assert Enum.count(Calendars.Sunday.month(2012, 12)) == 42
    assert Enum.count(Calendars.Sunday.month(2013, 12)) == 35
  end

  # A week date's month field is its week, and it is that field Elixir's
  # `Date.days_in_month/1` and `Date.end_of_month/1` put to
  # `days_in_month/2`: a week has seven days and ends on its seventh. 2026
  # has 53 ISO weeks and 2025 has 52.
  test "that a week has seven days, so Elixir's Date functions name its ends" do
    for calendar <- [Calendrical.ISOWeek, Calendrical.NRF, Calendars.Sunday],
        week <- [1, 2, 3, 12, 13, 25, 52] do
      date = Date.new!(2026, week, 3, calendar)

      assert calendar.days_in_month(2026, week) == 7, "#{inspect(calendar)} week #{week}"
      assert Date.days_in_month(date) == 7
      assert Calendrical.days_in_month(date) == 7
      assert Date.beginning_of_month(date) == Date.new!(2026, week, 1, calendar)
      assert Date.end_of_month(date) == Date.new!(2026, week, 7, calendar)
      assert Date.end_of_month(date) == Date.end_of_week(date)
    end

    assert Calendrical.ISOWeek.days_in_month(2026, 53) == 7
    assert Calendrical.ISOWeek.days_in_month(2025, 53) == {:error, :invalid_date}
    assert Calendrical.ISOWeek.days_in_month(2026, 54) == {:error, :invalid_date}
    assert Calendrical.ISOWeek.days_in_month(2026, 0) == {:error, :invalid_date}

    assert {:error, %Calendrical.MissingFieldsError{}} =
             Calendrical.ISOWeek.days_in_month(nil, 25)
  end

  # The twelve months of the pattern are still the calendar's months: the
  # weeks of a year are its `weeks_in_year/1`.
  test "that a year has the twelve months of its pattern" do
    date = Date.new!(2026, 25, 3, Calendrical.ISOWeek)

    assert Date.months_in_year(date) == 12
    assert Calendrical.ISOWeek.months_in_year() == 12
    assert Calendrical.ISOWeek.weeks_in_year(2026) == {53, 7}
    assert Calendrical.ISOWeek.month_of_year(2026, 25, 3) == 6
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
    {:ok, today} = Date.new(2019, 13, 4, Calendars.Tuesday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == %Date{calendar: Calendars.Tuesday, day: 4, month: 13, year: 2018}
  end

  test "wednesday week calendar" do
    {:ok, today} = Date.new(2019, 13, 4, Calendars.Wednesday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == %Date{calendar: Calendars.Wednesday, day: 4, month: 13, year: 2018}
  end

  test "thursday week calendar" do
    {:ok, today} = Date.new(2019, 13, 4, Calendars.Thursday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == %Date{calendar: Calendars.Thursday, day: 4, month: 13, year: 2018}
  end

  test "friday week calendar" do
    {:ok, today} = Date.new(2019, 13, 4, Calendars.Friday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == %Date{calendar: Calendars.Friday, day: 4, month: 13, year: 2018}
  end

  test "saturday week calendar" do
    {:ok, today} = Date.new(2019, 13, 4, Calendars.Saturday)
    last_year_day = Calendrical.previous(today, :year)
    assert last_year_day == %Date{calendar: Calendars.Saturday, day: 4, month: 13, year: 2018}
  end

  test "sunday week calendar" do
    {:ok, today} = Date.new(2018, 53, 3, Calendars.Sunday)
    current_period = Calendrical.Interval.month(today)
    first_day_of_period = current_period.first
    last_day_of_period = current_period.last
    assert first_day_of_period == %Date{calendar: Calendars.Sunday, day: 1, month: 48, year: 2018}
    assert last_day_of_period == %Date{calendar: Calendars.Sunday, day: 7, month: 53, year: 2018}
  end

  test "that previous month and next month actually are for a week calendar" do
    {:ok, today} = Date.new(2019, 4, 4)
    {:ok, today} = Date.convert(today, Calendars.Sunday)
    this_period = Calendrical.Interval.month(today)

    previous = Calendrical.previous(this_period, :month, coerce: true)
    assert previous.first == %Date{calendar: Calendars.Sunday, day: 1, month: 44, year: 2018}
    assert previous.last == %Date{calendar: Calendars.Sunday, day: 7, month: 47, year: 2018}

    next = Calendrical.next(this_period, :month, coerce: true)
    assert next.first == %Date{calendar: Calendars.Sunday, day: 1, month: 1, year: 2019}
    assert next.last == %Date{calendar: Calendars.Sunday, day: 7, month: 4, year: 2019}
  end

  test "previous month for a week calendar transitioning to prior quarter" do
    {:ok, today} = Date.convert(~D[2019-04-11], Calendars.Monday)
    prior_period_day = Calendrical.previous(today, :month, coerce: true)
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

  # Whatever the year, a week it can have has seven days.
  test "days in a week without its year" do
    config = %Calendrical.Config{weeks_in_month: [4, 4, 5]}

    for week <- [1, 2, 3, 12, 13, 52, 53] do
      assert Calendrical.Base.Week.days_in_month(week, config) == 7
    end

    assert Calendrical.Base.Week.days_in_month(54, config) == {:error, :invalid_date}
    assert Calendrical.Base.Week.days_in_month(0, config) == {:error, :invalid_date}
    assert Calendrical.ISOWeek.days_in_month(25) == 7
  end
end
