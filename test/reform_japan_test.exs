defmodule Calendrical.Reform.JapanTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Reform.Japan

  alias Calendrical.{Gregorian, LunarJapanese}
  alias Calendrical.Reform.Japan

  describe "1873 — the lunisolar-to-Gregorian transition" do
    test "the lunisolar era runs up to the reform, the Gregorian era from 1873-01-01" do
      # 1872-12-31 (Gregorian) is the last lunisolar day; in LunarJapanese's
      # continuous year numbering that is 1228-12-02.
      last_lunisolar = Date.new!(1228, 12, 2, Japan)
      assert Date.convert!(last_lunisolar, Gregorian) == ~D[1872-12-31 Calendrical.Gregorian]

      assert Date.shift(last_lunisolar, day: 1) == Date.new!(1873, 1, 1, Japan)
    end

    test "no physical days are skipped across the reform" do
      before = Date.new!(1228, 12, 2, Japan)
      first_gregorian = Date.new!(1873, 1, 1, Japan)
      assert Date.diff(first_gregorian, before) == 1
    end

    test "dates on or after 1873-01-01 follow the Gregorian rules" do
      assert Japan.valid_date?(1873, 1, 1)
      # 1900 is not a Gregorian leap year
      refute Japan.valid_date?(1900, 2, 29)
    end

    test "post-reform dates carry Japanese era years (1873 is Meiji 6)" do
      # The Gregorian side is Calendrical.Japanese, so era data is available.
      assert Japan.year_of_era(1873, 1, 1) == {6, 232}
    end
  end

  describe "round-trips across the reform" do
    test "a pre-reform lunisolar date round-trips through its base calendar" do
      lunisolar = Date.new!(1228, 12, 2, Japan)
      iso = Date.convert!(lunisolar, LunarJapanese)
      assert Date.convert!(iso, Japan) == lunisolar
    end

    test "a post-reform date round-trips through Gregorian" do
      date = Date.new!(1900, 6, 15, Japan)
      assert date |> Date.convert!(Gregorian) |> Date.convert!(Japan) == date
    end
  end
end
