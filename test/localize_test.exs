defmodule Calendrical.LocalizeTest do
  use ExUnit.Case, async: true

  test "Localized era with variant" do
    assert Calendrical.localize(~D[2019-01-01], :era, era: :variant) == "CE"
    assert Calendrical.localize(~D[-2019-01-01], :era, era: :variant) == "BCE"
  end

  test "Localized am/pm with variant" do
    assert Calendrical.localize(%{hour: 11}, :am_pm, am_pm: :variant) == "am"
    assert Calendrical.localize(%{hour: 12}, :am_pm, am_pm: :variant) == "pm"
  end

  test "Localizing a day of week in a calendar whose weeks don't start on Monday" do
    {:ok, he} = Calendrical.calendar_from_locale("he")
    {:ok, date} = Date.new(2025, 1, 26, he)
    assert "Sun" == Calendrical.localize(date, :day_of_week)
  end

  test "Localizing a month day in a calendar whose years don't start in January" do
    {:ok, date} = Date.new(2025, 1, 1, Calendrical.Fiscal.AU)
    assert "Jul" == Calendrical.localize(date, :month)

    {:ok, date} = Date.new(2025, 7, 1, Calendrical.Fiscal.AU)
    assert "Jan" == Calendrical.localize(date, :month)

    {:ok, date} = Date.new(2025, 12, 1, Calendrical.Fiscal.AU)
    assert "Jun" == Calendrical.localize(date, :month)
  end

  test "Localised days of the week for a calendar whose week doesn't start on Monday" do
    {:ok, he} = Calendrical.calendar_from_locale("he")
    {:ok, date} = Date.new(2025, 1, 26, he)

    assert [
             {1, "Sun"},
             {2, "Mon"},
             {3, "Tue"},
             {4, "Wed"},
             {5, "Thu"},
             {6, "Fri"},
             {7, "Sat"}
           ] == Calendrical.localize(date, :days_of_week)
  end
end
