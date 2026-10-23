defmodule Calendrical.WeekDateTest do
  @moduledoc """
  Week dates in a calendar's own weeks, which every calendar answers
  (`date_from_week_date/3`, `week_date_from_date/3`,
  `weeks_in_week_year/1`): the weeks `week_of_year/3` and `week/2` count,
  each day numbered from the day the calendar's weeks begin on. A year, a
  month, a week, a day and a day of the week are all the calendar's own, as
  RFC 7529 reads a rule's weeks (decided 2026-10-16). ISO 8601's week dates
  are those of `Calendar.ISO` and of `Calendrical.ISOWeek`.

  The measure for the Gregorian calendar is Elixir's `Date`: its weeks begin
  on Monday, and its week 1 is the week that holds 1 January, so it begins
  on the Monday on or before it. For another calendar it is the calendar's
  weeks worked by hand for the Hebrew year 5786, whose weeks begin on
  Sunday: 1 Tishri 5786 is Tuesday 23 September 2025, so week 1 is the five
  days from it to the Saturday, and week 10 begins on Sunday 3 Kislev, 23
  November 2025. Elsewhere it is the day each calendar's weeks begin on.

  """

  use ExUnit.Case, async: true

  @days Date.range(~D[2019-12-25], ~D[2028-01-07])

  # The first day of a Gregorian week-year: the Monday on or before 1 January.
  defp week_year_start(year) do
    Date.beginning_of_week(Date.new!(year, 1, 1))
  end

  # The Gregorian week-year, week and day of the week of a date, by `Date`.
  defp gregorian_week_date(date) do
    week_year = week_year_of(date, week_year_start(date.year + 1))

    {week_year, div(Date.diff(date, week_year_start(week_year)), 7) + 1, Date.day_of_week(date)}
  end

  defp week_year_of(date, next_start) do
    if Date.compare(date, next_start) == :lt do
      date.year
    else
      date.year + 1
    end
  end

  describe "in the Gregorian calendar" do
    test "a date's week date is in weeks from the Monday on or before 1 January" do
      for date <- @days do
        assert Calendrical.Gregorian.week_date_from_date(date.year, date.month, date.day) ==
                 gregorian_week_date(date)
      end

      # 31 December 2026 and 1 January 2027 are of week 1 of 2027, where
      # ISO 8601 has them in week 53 of 2026.
      assert Calendrical.Gregorian.week_date_from_date(2026, 12, 31) == {2027, 1, 4}
      assert :calendar.iso_week_number({2026, 12, 31}) == {2026, 53}
    end

    test "a week date's date is the day it names" do
      for date <- @days do
        {week_year, week, day} = gregorian_week_date(date)

        assert Calendrical.Gregorian.date_from_week_date(week_year, week, day) ==
                 Date.convert!(date, Calendrical.Gregorian)
      end
    end

    test "a year has the weeks from its first Monday week to the next's" do
      for year <- 1990..2050 do
        weeks = div(Date.diff(week_year_start(year + 1), week_year_start(year)), 7)
        assert Calendrical.Gregorian.weeks_in_week_year(year) == weeks
      end
    end
  end

  describe "in another calendar of months" do
    test "week 1 holds the year's first day, and a week begins on the calendar's day" do
      assert Date.convert!(~D[5786-01-01 Calendrical.Hebrew], Calendar.ISO) == ~D[2025-09-23]
      assert Calendrical.Hebrew.week_date_from_date(5786, 1, 1) == {5786, 1, 3}

      assert Calendrical.Hebrew.date_from_week_date(5786, 1, 3) ==
               ~D[5786-01-01 Calendrical.Hebrew]

      # Week 1 begins on the Sunday before 1 Tishri, 28 Elul 5785
      assert Calendrical.Hebrew.date_from_week_date(5786, 1, 1) ==
               ~D[5785-12-28 Calendrical.Hebrew]

      assert Date.convert!(~D[5786-03-03 Calendrical.Hebrew], Calendar.ISO) == ~D[2025-11-23]

      assert Calendrical.Hebrew.date_from_week_date(5786, 10, 1) ==
               ~D[5786-03-03 Calendrical.Hebrew]

      assert Calendrical.Hebrew.week_date_from_date(5786, 3, 3) == {5786, 10, 1}

      # Monday 22 September 2025 is 29 Elul 5785, the second day of the last
      # week of 5785.
      # 29 Elul 5785, a Monday, is in week 1 of 5786, which began the day before
      assert Calendrical.Hebrew.week_date_from_date(5785, 12, 29) == {5786, 1, 2}
    end

    test "is no week of the Gregorian year, which iso_week_of_year/3 gives" do
      assert Calendrical.Hebrew.iso_week_of_year(5786, 3, 4) == {2025, 48}
    end

    # The day each calendar's weeks begin on, as ISO 8601 numbers it.
    test "every date has one week date, which names it, its day counted from the week's first" do
      for {calendar, first_weekday, from, to} <- [
            {Calendrical.Hebrew, 7, ~D[2025-09-01], ~D[2027-10-31]},
            {Calendrical.Persian, 6, ~D[2025-03-01], ~D[2026-04-30]},
            {Calendrical.Coptic, 7, ~D[2025-09-01], ~D[2026-10-31]},
            {Calendrical.Julian.March25, 1, ~D[1750-03-01], ~D[1751-04-30]},
            {Calendrical.Reform.England, 1, ~D[1751-01-01], ~D[1753-01-31]}
          ],
          iso <- Date.range(from, to) do
        date = Date.convert!(iso, calendar)
        {week_year, week, day} = calendar.week_date_from_date(date.year, date.month, date.day)

        assert day == Integer.mod(Date.day_of_week(iso) - first_weekday, 7) + 1,
               "#{inspect(date)}"

        assert {week_year, week} == calendar.week_of_year(date.year, date.month, date.day),
               "#{inspect(date)}"

        assert week in 1..calendar.weeks_in_week_year(week_year), "#{inspect(date)}"
        assert calendar.date_from_week_date(week_year, week, day) == date, "#{inspect(date)}"
      end
    end

    test "week 1 holds the year's first day, and the day before week 1 is of the last week before" do
      for {calendar, years} <- [
            {Calendrical.Hebrew, 5780..5800},
            {Calendrical.Coptic, 1740..1750},
            {Calendrical.Islamic.Civil, 1445..1455}
          ],
          year <- years do
        first = calendar.date_from_day_of_year(year, 1)

        assert {^year, 1, _day} =
                 calendar.week_date_from_date(first.year, first.month, first.day)

        before = Date.add(calendar.date_from_week_date(year, 1, 1), -1)

        assert {before_year, last_week, _day} =
                 calendar.week_date_from_date(before.year, before.month, before.day)

        assert before_year == year - 1
        assert last_week == calendar.weeks_in_week_year(year - 1)
      end
    end
  end

  describe "in a calendar of weeks" do
    # A week date is counted in the calendar's own weeks, and names a date
    # of a month of its pattern: week 10 begins the third month.
    test "a week date is counted in the calendar's own weeks" do
      assert Calendrical.ISOWeek.date_from_week_date(2026, 10, 1) ==
               Date.new!(2026, 3, 1, Calendrical.ISOWeek)

      assert Calendrical.ISOWeek.week_date_from_date(2026, 3, 1) == {2026, 10, 1}
      assert Calendrical.NRF.week_date_from_date(2026, 3, 3) == {2026, 10, 3}

      assert {:error, %Calendrical.InvalidDateError{}} =
               Calendrical.ISOWeek.date_from_week_date(2026, 54, 1)

      assert {:error, %Calendrical.InvalidDateError{}} =
               Calendrical.NRF.week_date_from_date(2026, 3, 36)
    end

    # 28 December is always in its year's last ISO 8601 week.
    test "ISO 8601's calendar of weeks has ISO 8601's weeks" do
      for year <- 1990..2050 do
        {^year, last_week} = :calendar.iso_week_number({year, 12, 28})
        assert Calendrical.ISOWeek.weeks_in_week_year(year) == last_week
      end
    end
  end

  describe "what is no week date or no date" do
    test "is an error, and never raises" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Hebrew, Calendrical.ISOWeek] do
        assert {:error, %Calendrical.InvalidDateError{}} =
                 calendar.date_from_week_date(2026, 99, 1)

        assert {:error, %Calendrical.InvalidDateError{}} =
                 calendar.date_from_week_date(2026, 0, 1)

        assert {:error, %Calendrical.InvalidDateError{}} =
                 calendar.date_from_week_date(2026, 1, 8)

        assert {:error, %Calendrical.InvalidDateError{}} = calendar.date_from_week_date(nil, 1, 1)

        assert {:error, %Calendrical.InvalidDateError{}} =
                 calendar.week_date_from_date(2026, 99, 1)

        assert {:error, %Calendrical.InvalidDateError{}} = calendar.week_date_from_date(nil, 1, 1)
        assert {:error, %Calendrical.InvalidDateError{}} = calendar.weeks_in_week_year(nil)
      end
    end
  end
end
