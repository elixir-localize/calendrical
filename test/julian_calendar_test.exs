defmodule Calendrical.Julian.Test do
  use ExUnit.Case, async: true
  import Calendrical.Helper

  test "that we can localize a julian date" do
    assert Calendrical.localize(date(2019, 03, 01, Calendrical.Julian), :era) == "AD"
  end

  test "shift years in a Julian date" do
    {:ok, date} = Date.new(1, 1, 1, Calendrical.Julian)
    shifted = Date.shift(date, year: 1)
    assert shifted.year == 2
    assert shifted.month == 1
    assert shifted.day == 1
  end

  test "Calendar conversion from Julian starting March 25 for dates before new year" do
    assert {:ok, ~D[1751-01-12 Calendrical.Gregorian]} ==
             Date.convert(~D[1750-01-01 Calendrical.Julian.March25], Calendrical.Gregorian)
  end

  test "Calendar conversion from Julian starting March 25 for dates after new year" do
    assert {:ok, ~D[1751-04-05 Calendrical.Gregorian]} ==
             Date.convert(~D[1751-03-25 Calendrical.Julian.March25], Calendrical.Gregorian)
  end

  test "Calendar conversion to Julian starting March 25 for dates before new year" do
    assert {:ok, ~D[1750-01-01 Calendrical.Julian.March25]} ==
             Date.convert(~D[1751-01-12 Calendrical.Gregorian], Calendrical.Julian.March25)
  end

  test "Calendar conversion to Julian starting March 25 for dates after new year" do
    assert {:ok, ~D[1751-03-25 Calendrical.Julian.March25]} ==
             Date.convert(~D[1751-04-05 Calendrical.Gregorian], Calendrical.Julian.March25)
  end
end
