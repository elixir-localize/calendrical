defmodule Calendrical.CardinalMonth.Test do
  @moduledoc """
  Covers `cardinal_month/1`, which names the CLDR month a month of the year
  stands for. A year that begins in another month than the first numbers its
  months from there, so a year beginning in July has July as its first month
  and June as its twelfth; every other calendar's months are its CLDR
  calendar's.

  """

  use ExUnit.Case, async: true

  setup_all do
    {:ok, july} = Calendrical.new(Calendrical.CardinalMonth.Test.July, :month, month_of_year: 7)

    {:ok, april} =
      Calendrical.new(Calendrical.CardinalMonth.Test.April, :week,
        month_of_year: 4,
        min_days_in_first_week: 4,
        day_of_week: 1
      )

    {:ok, july: july, april: april}
  end

  test "a month-based year beginning in July counts its months from July", %{july: july} do
    assert Enum.map(1..12, &july.cardinal_month/1) == [7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6]
  end

  test "a week-based year beginning in April counts its months from April", %{april: april} do
    assert Enum.map(1..12, &april.cardinal_month/1) == [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
  end

  test "a year beginning in January keeps its months" do
    for calendar <- [Calendrical.Gregorian, Calendrical.ISOWeek, Calendrical.Julian] do
      assert Enum.map(1..12, &calendar.cardinal_month/1) == Enum.to_list(1..12)
    end
  end

  test "a lunisolar or thirteen-month calendar keeps its months" do
    assert Enum.map(1..13, &Calendrical.Hebrew.cardinal_month/1) == Enum.to_list(1..13)
    assert Enum.map(1..12, &Calendrical.Chinese.cardinal_month/1) == Enum.to_list(1..12)
  end

  test "the July year's first day is named July", %{july: july} do
    date = Date.convert!(~D[2025-07-01], july)

    assert {date.year, date.month, date.day} == {2026, 1, 1}
    assert july.cardinal_month(july.month_of_year(date.year, date.month, date.day)) == 7
    assert Calendrical.localize(date, :month) == "Jul"
  end
end
