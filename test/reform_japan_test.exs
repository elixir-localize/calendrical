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

  describe "a date's years are those of the calendar in effect" do
    # 1700-02-10 is in the lunar year that began in 1699, 己卯 (16) in
    # ICU4C 78.3's Chinese calendar and the twelfth year of Genroku.
    test "a pre-reform date answers as the lunisolar calendar" do
      %{year: year, month: month, day: day} = Date.convert!(~D[1700-02-10], Japan)

      assert Japan.year_of_era(year, month, day) == {12, 208}
      assert Japan.related_gregorian_year(year, month, day) == 1699
      assert Japan.cyclic_year(year, month, day) == 16
      assert Japan.extended_year(year, month, day) == year
    end

    # A partial date wholly inside one member is that member's: 1228 is
    # lunisolar throughout, so its cyclic year needs no day.
    test "a partial date wholly inside a member answers as that member" do
      assert Japan.cyclic_year(1228, 1, nil) == Japan.cyclic_year(1228, 1, 1)
      assert Japan.cyclic_year(1228, nil, nil) == Japan.cyclic_year(1228, 1, 1)
      refute Japan.cyclic_year(1228, 1, nil) == 1228
    end

    # A year that begins with a change of member is that member's
    # throughout: 1873 is Japanese from its first day.
    test "a year beginning with a change of member answers as that member" do
      assert Calendrical.Info.in_effect(Japan, 1873, nil, nil) == Calendrical.Japanese
      assert Calendrical.Info.in_effect(Japan, 1873, 1, nil) == Calendrical.Japanese

      assert Calendrical.Info.in_effect(Calendrical.Reform.England, 1155, nil, nil) ==
               Calendrical.Julian.March25
    end

    test "a post-reform date answers as the Japanese calendar" do
      assert Japan.year_of_era(2025, 3, 15) == {7, 236}
      assert Japan.related_gregorian_year(2025, 3, 15) == 2025
    end

    test "both sides of the reform name their eras from the Japanese calendar" do
      assert Japan.era_calendar_type() == :japanese
      assert Calendrical.Reform.England.era_calendar_type() == :gregorian

      assert Calendrical.localize(Date.convert!(~D[1700-02-10], Japan), :era, locale: :ja) == "元禄"
      assert Calendrical.localize(Date.convert!(~D[2025-03-15], Japan), :era, locale: :ja) == "令和"
    end
  end
end
