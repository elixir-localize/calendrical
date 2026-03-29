defmodule Calendrical.PersianTest do
  use ExUnit.Case

  doctest Calendrical.Persian

  test "Persian calendar localization" do
    {:ok, date} = Date.new(1354, 1, 1, Calendrical.Persian)

    assert Calendrical.localize(date, :month, locale: "en") == "Farvardin"
    assert Calendrical.localize(date, :month, locale: "fa") == "فروردین"
    assert Calendrical.localize(date, :day_of_week, locale: "fa") == "جمعه"
    assert Calendrical.localize(date, :day_of_week, locale: "en") == "Fri"
  end

  test "day of week" do
    {:ok, gregorian_date} = Date.new(2019, 12, 9, Calendrical.Gregorian)
    {:ok, persian_date} = Date.convert(gregorian_date, Calendrical.Persian)
    assert Calendrical.day_of_week(persian_date) == 1
  end
end
