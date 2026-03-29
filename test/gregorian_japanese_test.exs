defmodule Calendrical.Japanese.Test do
  use ExUnit.Case, async: true

  alias Calendrical.Japanese

  test "Year of Japanese Era around transitions" do
    assert Calendrical.year_of_era(Date.convert!(~D[2019-05-01], Japanese)) == {1, 236}

    assert Calendrical.year_of_era(Date.convert!(~D[2019-04-30], Japanese)) == {31, 235}
    assert Calendrical.year_of_era(Date.convert!(~D[1989-01-08], Japanese)) == {1, 235}

    assert Calendrical.year_of_era(Date.convert!(~D[1989-01-07], Japanese)) == {64, 234}
    assert Calendrical.year_of_era(Date.convert!(~D[1926-12-25], Japanese)) == {1, 234}

    assert Calendrical.year_of_era(Date.convert!(~D[1926-12-24], Japanese)) == {15, 233}
    assert Calendrical.year_of_era(Date.convert!(~D[1912-07-30], Japanese)) == {1, 233}

    assert Calendrical.year_of_era(~D[1912-06-16 Calendrical.Japanese]) == {45, 232}

    assert Calendrical.year_of_era(~D[1865-04-07 Calendrical.Japanese]) == {1, 231}
    assert Calendrical.year_of_era(~D[1868-09-07 Calendrical.Japanese]) == {4, 231}

    assert Calendrical.year_of_era(~D[1868-10-23 Calendrical.Japanese]) == {1, 232}
  end

  test "Era localization" do
    assert Calendrical.localize(Date.convert!(~D[2019-05-01], Calendrical.Japanese), :era) ==
             "Reiwa"

    assert Calendrical.localize(Date.convert!(~D[2019-04-30], Calendrical.Japanese), :era) ==
             "Heisei"

    assert Calendrical.localize(Date.convert!(~D[1989-01-08], Calendrical.Japanese), :era) ==
             "Heisei"

    assert Calendrical.localize(Date.convert!(~D[1989-01-07], Calendrical.Japanese), :era) ==
             "Shōwa"

    assert Calendrical.localize(Date.convert!(~D[1926-12-24], Calendrical.Japanese), :era) ==
             "Taishō"
  end
end
