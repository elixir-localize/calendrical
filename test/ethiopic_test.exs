defmodule Calendrical.EthiopicTest do
  use ExUnit.Case

  doctest Calendrical.Ethiopic

  test "day of week" do
    {:ok, gregorian_date} = Date.new(2019, 12, 9, Calendrical.Gregorian)
    {:ok, ethiopic_date} = Date.convert(gregorian_date, Calendrical.Ethiopic)
    assert Calendrical.day_of_week(ethiopic_date) == 1
  end

  test "months in year" do
    assert Calendrical.Ethiopic.months_in_year(2000) == 13
  end

  test "~D sigil" do
    assert ~U[1736-13-01T00:00:00.0Z Calendrical.Ethiopic]
    assert ~D[1736-13-01 Calendrical.Ethiopic]
    assert ~D[1736-13-05 Calendrical.Ethiopic]
  end
end
