defmodule Calendrical.CopticTest do
  use ExUnit.Case

  doctest Calendrical.Coptic

  test "day of week" do
    {:ok, gregorian_date} = Date.new(2019, 12, 9, Calendrical.Gregorian)
    {:ok, coptic_date} = Date.convert(gregorian_date, Calendrical.Coptic)
    # 2019-12-09 is a Monday; Coptic weeks number from Sunday = 1.
    assert Calendrical.day_of_week(coptic_date) == 2
  end

  test "months in year" do
    assert Calendrical.Coptic.months_in_year(2000) == 13
  end

  test "~D sigil" do
    assert ~U[1736-13-01T00:00:00.0Z Calendrical.Coptic]
    assert ~D[1736-13-01 Calendrical.Coptic]
    assert ~D[1736-13-05 Calendrical.Coptic]
  end
end
