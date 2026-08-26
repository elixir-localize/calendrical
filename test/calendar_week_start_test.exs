defmodule Calendrical.CalendarWeekStartTest do
  @moduledoc """
  Regression tests for culturally-correct week starts and the
  calendar-aligned week numbering on the Behaviour calendars.

  2026-07-25 is a Saturday and 2026-07-26 a Sunday in the proleptic
  Gregorian calendar; every assertion anchors on those two days.

  """

  use ExUnit.Case, async: true

  @saturday ~D[2026-07-25]
  @sunday ~D[2026-07-26]

  @sunday_first_calendars [
    Calendrical.Hebrew,
    Calendrical.Coptic,
    Calendrical.Ethiopic,
    Calendrical.Ethiopic.AmeteAlem,
    Calendrical.Islamic.Civil,
    Calendrical.Islamic.Tbla,
    Calendrical.Islamic.Observational,
    Calendrical.Islamic.Rgsa,
    Calendrical.Islamic.UmmAlQura
  ]

  describe "Sunday-first week numbering" do
    test "Sunday numbers 1 and Saturday numbers 7 on every Sunday-first calendar" do
      for calendar <- @sunday_first_calendars do
        {:ok, sat} = Date.convert(@saturday, calendar)
        {:ok, sun} = Date.convert(@sunday, calendar)

        assert calendar.day_of_week(sat.year, sat.month, sat.day, :default) == {7, 1, 7},
               "#{inspect(calendar)} should number Saturday as 7"

        assert calendar.day_of_week(sun.year, sun.month, sun.day, :default) == {1, 1, 7},
               "#{inspect(calendar)} should number Sunday as 1"
      end
    end

    test "a Hebrew week begins on Sunday" do
      {:ok, shabbat} = Date.convert(@saturday, Calendrical.Hebrew)
      week_start = shabbat |> Date.beginning_of_week() |> Date.convert!(Calendar.ISO)

      assert Date.day_of_week(week_start) == 7
      assert week_start == ~D[2026-07-19]
    end
  end

  describe "Persian Saturday-first week numbering" do
    test "Shanbeh (Saturday) numbers 1" do
      {:ok, sat} = Date.convert(@saturday, Calendrical.Persian)
      {:ok, sun} = Date.convert(@sunday, Calendrical.Persian)

      assert Calendrical.Persian.day_of_week(sat.year, sat.month, sat.day, :default) == {1, 1, 7}
      assert Calendrical.Persian.day_of_week(sun.year, sun.month, sun.day, :default) == {2, 1, 7}
    end

    test "a Persian week begins on Saturday" do
      {:ok, sun} = Date.convert(@sunday, Calendrical.Persian)
      week_start = sun |> Date.beginning_of_week() |> Date.convert!(Calendar.ISO)

      assert Date.day_of_week(week_start) == 6
      assert week_start == @saturday
    end
  end

  describe "explicit starting_on renumbering is unchanged" do
    test "Hebrew and Coptic renumber relative to an explicit weekday start" do
      {:ok, shabbat} = Date.convert(@saturday, Calendrical.Hebrew)
      {:ok, coptic} = Date.convert(@saturday, Calendrical.Coptic)

      assert Calendrical.Hebrew.day_of_week(shabbat.year, shabbat.month, shabbat.day, :monday) ==
               {6, 1, 7}

      assert Calendrical.Coptic.day_of_week(coptic.year, coptic.month, coptic.day, :saturday) ==
               {1, 1, 7}
    end
  end

  describe "week_of_year and weeks_in_year" do
    test "the first day of the year is in week 1" do
      # Only the calendars that implement calendar-aligned weeks.
      for calendar <- [
            Calendrical.Hebrew,
            Calendrical.Islamic.Civil,
            Calendrical.Islamic.Tbla,
            Calendrical.Islamic.Observational,
            Calendrical.Islamic.Rgsa,
            Calendrical.Islamic.UmmAlQura
          ] do
        {:ok, %{year: year}} = Date.convert(@saturday, calendar)
        assert calendar.week_of_year(year, 1, 1) == {year, 1}
      end
    end

    test "the last day of the year is in the last week" do
      # Hebrew month 13 (Elul) is the final month even in ordinary
      # years, where month 6 (Adar I) does not exist.
      last_day = Calendrical.Hebrew.days_in_month(5786, 13)
      {weeks, _days_in_last_week} = Calendrical.Hebrew.weeks_in_year(5786)
      assert Calendrical.Hebrew.week_of_year(5786, 13, last_day) == {5786, weeks}

      last_day = Calendrical.Islamic.Civil.days_in_month(1447, 12)
      {weeks, _days_in_last_week} = Calendrical.Islamic.Civil.weeks_in_year(1447)
      assert Calendrical.Islamic.Civil.week_of_year(1447, 12, last_day) == {1447, weeks}
    end

    test "a Hebrew leap year has more weeks than an ordinary year" do
      assert Calendrical.Hebrew.weeks_in_year(5786) == {51, 6}
      assert Calendrical.Hebrew.weeks_in_year(5787) == {56, 6}
      assert Calendrical.Hebrew.leap_year?(5787)
    end

    test "weeks advance by one across a week boundary" do
      # Hebrew 5786 opens on a Tuesday (day 3 of the Sunday-first
      # week), so week 1 has five days and week 2 begins on 6 Tishri.
      assert Calendrical.Hebrew.day_of_week(5786, 1, 1, :default) == {3, 1, 7}
      assert Calendrical.Hebrew.week_of_year(5786, 1, 5) == {5786, 1}
      assert Calendrical.Hebrew.week_of_year(5786, 1, 6) == {5786, 2}
    end

    test "Ramadan 1447 falls in week 35 on the Islamic calendars" do
      for calendar <- [
            Calendrical.Islamic.Civil,
            Calendrical.Islamic.Tbla,
            Calendrical.Islamic.Observational,
            Calendrical.Islamic.Rgsa,
            Calendrical.Islamic.UmmAlQura
          ] do
        assert calendar.week_of_year(1447, 9, 1) == {1447, 35},
               "#{inspect(calendar)} Ramadan week"
      end
    end
  end
end
