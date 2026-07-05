defmodule Calendrical.ApiTest do
  @moduledoc """
  Tests for the `Calendrical` top-level API: period navigation,
  weekend/weekday classification, weekday numbering, localization
  shortcuts, and utility conversions.

  """

  use ExUnit.Case, async: true

  @sunday ~D[2026-07-05]

  describe "period navigation" do
    test "next/2 across period types" do
      assert Calendrical.next(@sunday, :day) == ~D[2026-07-06]
      assert Calendrical.next(@sunday, :week) == ~D[2026-07-12]
      assert Calendrical.next(@sunday, :month) == ~D[2026-08-05]
      assert Calendrical.next(@sunday, :quarter) == ~D[2026-10-05]
      assert Calendrical.next(@sunday, :year) == ~D[2027-07-05]
    end

    test "previous/2 across period types" do
      assert Calendrical.previous(@sunday, :day) == ~D[2026-07-04]
      assert Calendrical.previous(@sunday, :week) == ~D[2026-06-28]
      assert Calendrical.previous(@sunday, :month) == ~D[2026-06-05]
      assert Calendrical.previous(@sunday, :year) == ~D[2025-07-05]
    end

    test "current/2 returns the date itself for its own period" do
      assert Calendrical.current(@sunday, :week) == @sunday
      assert Calendrical.current(@sunday, :quarter) == @sunday
    end

    test "month navigation clamps at month end" do
      assert Calendrical.next(~D[2026-01-31], :month) == ~D[2026-02-28]
    end

    test "navigation works on non-ISO calendars" do
      {:ok, julian} = Date.convert(@sunday, Calendrical.Julian)
      assert Calendrical.next(julian, :day) == Date.add(julian, 1)
    end
  end

  describe "weekend and weekday classification" do
    test "weekend?/1 and weekday?/1 with the default territory" do
      assert Calendrical.weekend?(~D[2026-07-04])
      refute Calendrical.weekend?(~D[2026-07-06])
      assert Calendrical.weekday?(~D[2026-07-06])
      refute Calendrical.weekday?(@sunday)
    end

    test "weekend days differ by territory" do
      # Saudi Arabia's weekend is Friday and Saturday.
      assert Calendrical.weekend(:SA) == [5, 6]
      assert Calendrical.weekdays(:US) == [1, 2, 3, 4, 5]
      assert Calendrical.weekend?(~D[2026-07-03], territory: :SA)
      refute Calendrical.weekend?(@sunday, territory: :SA)
    end
  end

  describe "weekday numbering" do
    test "iso_days_to_day_of_week returns the documented 1..7 range" do
      # 2026-07-06 is a Monday, 2026-07-05 a Sunday.
      monday_days = Calendrical.date_to_iso_days(~D[2026-07-06])
      sunday_days = Calendrical.date_to_iso_days(@sunday)

      assert Calendrical.iso_days_to_day_of_week(monday_days) == Calendrical.monday()
      assert Calendrical.iso_days_to_day_of_week(sunday_days) == Calendrical.sunday()
    end

    test "weekday constants cover the week" do
      assert Calendrical.monday() == 1
      assert Calendrical.tuesday() == 2
      assert Calendrical.wednesday() == 3
      assert Calendrical.thursday() == 4
      assert Calendrical.friday() == 5
      assert Calendrical.saturday() == 6
      assert Calendrical.sunday() == 7
    end
  end

  describe "kday invariants with the 1..7 weekday range" do
    test "kday_on_or_before returns the same day when it matches" do
      assert Calendrical.Kday.kday_on_or_before(@sunday, 7) == @sunday
      assert Calendrical.Kday.kday_on_or_before(@sunday, 1) == ~D[2026-06-29]
    end

    test "kday_on_or_after returns the same day when it matches" do
      assert Calendrical.Kday.kday_on_or_after(@sunday, 7) == @sunday
      assert Calendrical.Kday.kday_on_or_after(@sunday, 1) == ~D[2026-07-06]
    end
  end

  describe "localization shortcuts" do
    test "localize month and weekday names" do
      assert Calendrical.localize(@sunday, :month, locale: :en) == "Jul"
      assert Calendrical.localize(@sunday, :day_of_week, locale: :en) == "Sun"
    end

    test "localize days_of_week returns the numbered week" do
      days = Calendrical.localize(@sunday, :days_of_week, locale: :en)
      assert {1, "Mon"} in days
      assert {7, "Sun"} in days
      assert length(days) == 7
    end
  end

  describe "wrappers and conversions" do
    test "date-taking wrappers" do
      assert Calendrical.week_of_year(@sunday) == {2026, 27}
      assert Calendrical.quarter_of_year(@sunday) == 3
      assert Calendrical.year_of_era(@sunday) == {2026, 1}
    end

    test "convert/2 between calendars" do
      assert Calendrical.convert(@sunday, Calendrical.Julian) ==
               {:ok, ~D[2026-06-22 Calendrical.Julian]}
    end

    test "validate_calendar/1" do
      assert Calendrical.validate_calendar(Calendrical.Persian) == {:ok, Calendrical.Persian}

      assert {:error, %Calendrical.InvalidCalendarModuleError{}} =
               Calendrical.validate_calendar(NotACalendar)
    end

    test "modified_julian_day/1" do
      assert Calendrical.modified_julian_day(@sunday) == 61_226.0
    end

    test "date_from_day_of_year/2" do
      assert Calendrical.date_from_day_of_year(2026, 100) == ~D[2026-04-10]
      assert Calendrical.date_from_day_of_year(2024, 60) == ~D[2024-02-29]
    end
  end
end
