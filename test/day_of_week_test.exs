defmodule Calendrical.DayOfWeekTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @max_runs 50_000

  property "Day of week for Calendrical.Gregorian and Calendar.ISO are the same" do
    check all(
            date <- Calendrical.Date.generate_date_in_calendar(Calendar.ISO),
            max_runs: @max_runs
          ) do
      gregorian = Date.convert!(date, Calendrical.Gregorian)
      assert Date.day_of_week(date) == Date.day_of_week(gregorian)
    end
  end

  property "Day of week for Calendrical.Behaviour.Gregorian and Calendar.ISO are the same" do
    check all(
            date <- Calendrical.Date.generate_date_in_calendar(Calendar.ISO),
            max_runs: @max_runs
          ) do
      gregorian = Date.convert!(date, Calendrical.Behaviour.Gregorian)
      assert Date.day_of_week(date) == Date.day_of_week(gregorian)
    end
  end

  property "Day of week for calendars that start on Sunday are one more than Gregorian" do
    check all(
            date <-
              Calendrical.Date.generate_date_in_calendar(Calendrical.Test.Calendars.Month.Sunday),
            max_runs: @max_runs
          ) do
      gregorian = Date.convert!(date, Calendrical.Gregorian)
      gregorian_day = Date.day_of_week(gregorian)
      sunday_day = Date.day_of_week(date)

      assert gregorian.year == date.year && gregorian.month == date.month &&
               gregorian.day == date.day

      assert sunday_day == Localize.Utils.Math.amod(gregorian_day + 1, 7)
    end
  end

  property "Day of week for calendars that start on Friday are three more than Gregorian" do
    check all(
            date <-
              Calendrical.Date.generate_date_in_calendar(Calendrical.Test.Calendars.Month.Friday),
            max_runs: @max_runs
          ) do
      gregorian = Date.convert!(date, Calendrical.Gregorian)
      gregorian_day = Date.day_of_week(gregorian)
      friday_day = Date.day_of_week(date)

      assert gregorian.year == date.year && gregorian.month == date.month &&
               gregorian.day == date.day

      assert friday_day == Localize.Utils.Math.amod(gregorian_day + 3, 7)
    end
  end

  test "Israeli Gregorian calendar beginning_of_week" do
    {:ok, il_calendar} = Calendrical.calendar_from_locale("he")
    {:ok, il_date} = Date.new(2025, 1, 8, il_calendar)
    assert Date.new!(2025, 1, 5, il_calendar) == Date.beginning_of_week(il_date)
  end
end
