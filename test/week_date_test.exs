defmodule Calendrical.WeekDateTest do
  @moduledoc """
  Week dates by ISO 8601's rule over a calendar's own year, which every
  calendar answers (`date_from_week_date/3`, `week_date_from_date/3`,
  `weeks_in_week_year/1`).

  `iso_week_of_year/3` gives the week of the Gregorian year a day is in,
  whichever calendar names the day, and nothing gave the date of a week
  date, the week date of a date in a calendar's own year, or how many such
  weeks a year has.

  The measure for the Gregorian calendar is Erlang's
  `:calendar.iso_week_number/1` and Elixir's `Date.day_of_week/1`. For
  another calendar it is the rule itself, worked by hand for the Hebrew
  year 5786: 1 Tishri 5786 is Tuesday 23 September 2025, so the year's
  fourth day is Friday the 26th, and its week 1 begins on Monday the 22nd,
  29 Elul 5785; its week 10 begins nine weeks on, Monday 24 November 2025,
  4 Kislev 5786.

  """

  use ExUnit.Case, async: true

  @days Date.range(~D[2019-12-25], ~D[2028-01-07])

  describe "in the Gregorian calendar" do
    test "a date's week date is ISO 8601's" do
      for date <- @days do
        {iso_year, iso_week} = :calendar.iso_week_number(Date.to_erl(date))

        assert Calendrical.Gregorian.week_date_from_date(date.year, date.month, date.day) ==
                 {iso_year, iso_week, Date.day_of_week(date)}
      end
    end

    test "a week date's date is the day it names" do
      for date <- @days do
        {iso_year, iso_week} = :calendar.iso_week_number(Date.to_erl(date))

        assert Calendrical.Gregorian.date_from_week_date(
                 iso_year,
                 iso_week,
                 Date.day_of_week(date)
               ) ==
                 Date.convert!(date, Calendrical.Gregorian)
      end
    end

    test "a year has the weeks 28 December is in the last of" do
      for year <- 1990..2050 do
        {^year, last_week} = :calendar.iso_week_number({year, 12, 28})
        assert Calendrical.Gregorian.weeks_in_week_year(year) == last_week
      end
    end
  end

  describe "in another calendar of months" do
    test "week 1 begins on the Monday on or before the year's fourth day" do
      assert Calendrical.Hebrew.date_from_week_date(5786, 1, 1) ==
               ~D[5785-12-29 Calendrical.Hebrew]

      assert Date.convert!(~D[5785-12-29 Calendrical.Hebrew], Calendar.ISO) == ~D[2025-09-22]

      assert Calendrical.Hebrew.date_from_week_date(5786, 10, 1) ==
               ~D[5786-03-04 Calendrical.Hebrew]

      assert Date.convert!(~D[5786-03-04 Calendrical.Hebrew], Calendar.ISO) == ~D[2025-11-24]

      assert Calendrical.Hebrew.week_date_from_date(5786, 3, 4) == {5786, 10, 1}
      assert Calendrical.Hebrew.week_date_from_date(5785, 12, 29) == {5786, 1, 1}
    end

    test "is no week of the Gregorian year, which iso_week_of_year/3 gives" do
      assert Calendrical.Hebrew.iso_week_of_year(5786, 3, 4) == {2025, 48}
    end

    test "every date has one week date, which names it" do
      for {calendar, from, to} <- [
            {Calendrical.Hebrew, ~D[2025-09-01], ~D[2027-10-31]},
            {Calendrical.Persian, ~D[2025-03-01], ~D[2026-04-30]},
            {Calendrical.Coptic, ~D[2025-09-01], ~D[2026-10-31]},
            {Calendrical.Julian.March25, ~D[1750-03-01], ~D[1751-04-30]},
            {Calendrical.Reform.England, ~D[1751-01-01], ~D[1753-01-31]}
          ],
          iso <- Date.range(from, to) do
        date = Date.convert!(iso, calendar)
        {week_year, week, day} = calendar.week_date_from_date(date.year, date.month, date.day)

        assert day == Date.day_of_week(iso), "#{inspect(date)}"
        assert week in 1..calendar.weeks_in_week_year(week_year), "#{inspect(date)}"
        assert calendar.date_from_week_date(week_year, week, day) == date, "#{inspect(date)}"
      end
    end

    test "week 1 holds the year's fourth day, and the week before it does not" do
      for {calendar, years} <- [
            {Calendrical.Hebrew, 5780..5800},
            {Calendrical.Coptic, 1740..1750},
            {Calendrical.Islamic.Civil, 1445..1455}
          ],
          year <- years do
        fourth = calendar.date_from_day_of_year(year, 4)

        assert {^year, 1, _day} =
                 calendar.week_date_from_date(fourth.year, fourth.month, fourth.day)

        monday = calendar.date_from_week_date(year, 1, 1)
        before = Date.add(monday, -1)

        assert {before_year, last_week, 7} =
                 calendar.week_date_from_date(before.year, before.month, before.day)

        assert before_year == year - 1
        assert last_week == calendar.weeks_in_week_year(year - 1)
      end
    end
  end

  describe "in a calendar of weeks" do
    test "a week date is the calendar's own date" do
      assert Calendrical.ISOWeek.date_from_week_date(2026, 10, 1) ==
               Date.new!(2026, 10, 1, Calendrical.ISOWeek)

      assert Calendrical.ISOWeek.week_date_from_date(2026, 10, 1) == {2026, 10, 1}
      assert Calendrical.NRF.week_date_from_date(2026, 10, 3) == {2026, 10, 3}
    end

    test "ISO 8601's calendar of weeks has the weeks the Gregorian year has" do
      for year <- 1990..2050 do
        assert Calendrical.ISOWeek.weeks_in_week_year(year) ==
                 Calendrical.Gregorian.weeks_in_week_year(year)
      end
    end
  end

  describe "what is no week date or no date" do
    test "is an error, and never raises" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Hebrew, Calendrical.ISOWeek] do
        assert calendar.date_from_week_date(2026, 99, 1) == {:error, :invalid_date}
        assert calendar.date_from_week_date(2026, 0, 1) == {:error, :invalid_date}
        assert calendar.date_from_week_date(2026, 1, 8) == {:error, :invalid_date}
        assert calendar.date_from_week_date(nil, 1, 1) == {:error, :invalid_date}
        assert calendar.week_date_from_date(2026, 99, 1) == {:error, :invalid_date}
        assert calendar.week_date_from_date(nil, 1, 1) == {:error, :invalid_date}
        assert calendar.weeks_in_week_year(nil) == {:error, :invalid_date}
      end
    end
  end
end
