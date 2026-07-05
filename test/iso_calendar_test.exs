defmodule Calendrical.ISOCalendarTest do
  @moduledoc """
  Tests for `Calendrical.ISO`, the Gregorian calendar with ISO 8601
  week rules (weeks start Monday, week 1 has at least 4 days).

  """

  use ExUnit.Case, async: true

  test "conversions round-trip through Calendar.ISO" do
    for date <- [~D[2026-01-01], ~D[2026-07-05], ~D[2020-02-29], ~D[2026-12-31]] do
      {:ok, converted} = Date.convert(date, Calendrical.ISO)
      assert {:ok, ^date} = Date.convert(converted, Calendar.ISO)
      assert {converted.year, converted.month, converted.day} == {date.year, date.month, date.day}
    end
  end

  test "week of year follows ISO 8601 rules" do
    # 2026-01-01 is a Thursday, so it belongs to ISO week 1 of 2026.
    assert Calendrical.ISO.week_of_year(2026, 1, 1) == {2026, 1}

    # 2027-01-01 is a Friday with only 3 days in the first week, so
    # it belongs to ISO week 53 of 2026.
    assert Calendrical.ISO.week_of_year(2027, 1, 1) == {2026, 53}
  end

  test "leap years match the Gregorian rule" do
    assert Calendrical.ISO.leap_year?(2024)
    refute Calendrical.ISO.leap_year?(2026)
    assert Calendrical.ISO.leap_year?(2000)
    refute Calendrical.ISO.leap_year?(1900)
  end

  test "days_in_month matches Calendar.ISO" do
    assert Calendrical.ISO.days_in_month(2026, 2) == 28
    assert Calendrical.ISO.days_in_month(2024, 2) == 29
    assert Calendrical.ISO.days_in_month(2026, 7) == 31
  end
end
