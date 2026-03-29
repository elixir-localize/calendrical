defmodule Calendar.Kday.Test do
  use ExUnit.Case, async: true

  test "nth kday for k-day == day of date" do
    assert Calendrical.Kday.nth_kday(~D[2022-01-01], 1, 5) == ~D[2022-01-07]
    assert Calendrical.Kday.nth_kday(~D[2022-01-01], -1, 5) == ~D[2021-12-31]
    assert Calendrical.Kday.nth_kday(~D[2024-01-01], 3, 1) == ~D[2024-01-15]
    assert Calendrical.Kday.nth_kday(~D[2024-02-01], 3, 1) == ~D[2024-02-19]
  end

  test "last kday" do
    assert Calendrical.Kday.last_kday(~D[2024-05-30], 1) == ~D[2024-05-27]
  end
end
