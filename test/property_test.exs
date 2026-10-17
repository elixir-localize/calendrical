defmodule Calendrical.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Calendar

  @max_runs 50_000

  property "next and previous weeks" do
    check all(
            date <- Calendrical.Test.DateGenerator.generate_date_in_week_calendar(),
            max_runs: @max_runs
          ) do
      this = Calendrical.Interval.week(date)
      previous = Calendrical.previous(this, :week, clamp: true)
      next = Calendrical.next(this, :week, clamp: true)

      assert Calendrical.date_to_iso_days(this.last) + 1 ==
               Calendrical.date_to_iso_days(next.first)

      assert Calendrical.date_to_iso_days(previous.last) + 1 ==
               Calendrical.date_to_iso_days(this.first)
    end
  end

  property "next and previous months" do
    check all(
            date <- Calendrical.Test.DateGenerator.generate_date_in_week_calendar(),
            max_runs: @max_runs
          ) do
      this = Calendrical.Interval.month(date)
      previous = Calendrical.previous(this, :month, clamp: true)
      next = Calendrical.next(this, :month, clamp: true)

      assert Calendrical.date_to_iso_days(this.last) + 1 ==
               Calendrical.date_to_iso_days(next.first)

      assert Calendrical.date_to_iso_days(previous.last) + 1 ==
               Calendrical.date_to_iso_days(this.first)
    end
  end

  property "next and previous quarters" do
    check all(
            date <- Calendrical.Test.DateGenerator.generate_date_in_week_calendar(),
            max_runs: @max_runs
          ) do
      this = Calendrical.Interval.quarter(date)
      previous = Calendrical.previous(this, :quarter, clamp: true)
      next = Calendrical.next(this, :quarter, clamp: true)

      assert Calendrical.date_to_iso_days(this.last) + 1 ==
               Calendrical.date_to_iso_days(next.first)

      assert Calendrical.date_to_iso_days(previous.last) + 1 ==
               Calendrical.date_to_iso_days(this.first)
    end
  end
end
