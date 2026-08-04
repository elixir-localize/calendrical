defmodule Calendrical.ReformTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Reform

  describe "known_territories/0 and reform_date/1" do
    test "the table covers the 34 ncal territories" do
      territories = Calendrical.Reform.known_territories()
      assert length(territories) == 34
      assert :GB in territories
      assert :RU in territories
      assert :LU in territories
    end

    test "reform_date/1 returns the last Julian and first Gregorian dates" do
      assert {:ok, %{last_julian: last, first_gregorian: first}} =
               Calendrical.Reform.reform_date(:GB)

      assert last == ~D[1752-09-02 Calendrical.Julian]
      assert first == ~D[1752-09-14 Calendrical.Gregorian]
    end

    test "reform_date/1 accepts a string territory case-insensitively" do
      assert {:ok, _} = Calendrical.Reform.reform_date("gb")
    end

    test "reform_date/1 derives the territory from a LanguageTag" do
      {:ok, tag} = Localize.validate_locale("sv-SE")

      assert {:ok, %{last_julian: ~D[1753-02-17 Calendrical.Julian]}} =
               Calendrical.Reform.reform_date(tag)
    end

    test "reforms/0 exposes the whole table" do
      table = Calendrical.Reform.reforms()
      assert map_size(table) == 34
      assert table[:GB].first_gregorian == ~D[1752-09-14 Calendrical.Gregorian]
    end
  end

  describe "calendar_for/1 from a locale" do
    test "derives the territory from a LanguageTag" do
      {:ok, tag} = Localize.validate_locale("en-GB")
      assert {:ok, Calendrical.Reform.GB} = Calendrical.Reform.calendar_for(tag)
    end

    test "reform_date/1 rejects an unknown territory" do
      assert {:error, :unknown_territory} = Calendrical.Reform.reform_date(:XX)
    end
  end

  describe "calendar_for/1 — United Kingdom (1752)" do
    setup do
      {:ok, calendar} = Calendrical.Reform.calendar_for(:GB)
      %{calendar: calendar}
    end

    test "11 days are missing across the September 1752 transition", %{calendar: calendar} do
      day_before = Date.new!(1752, 9, 2, calendar)
      assert Date.shift(day_before, day: 1) == Date.new!(1752, 9, 14, calendar)
    end

    test "September 3-13, 1752 are not valid dates", %{calendar: calendar} do
      for d <- 3..13 do
        refute calendar.valid_date?(1752, 9, d), "expected #{d} Sep 1752 to be invalid"
      end
    end

    test "is Julian before the reform and Gregorian after", %{calendar: calendar} do
      # Julian rule before: 1700 is a leap year
      assert calendar.valid_date?(1700, 2, 29)
      # Gregorian rule after: 1900 is not a leap year
      refute calendar.valid_date?(1900, 2, 29)
    end
  end

  describe "calendar_for/1 — Russia (1918)" do
    test "31 January 1918 is followed by 14 February 1918" do
      {:ok, calendar} = Calendrical.Reform.calendar_for(:RU)
      day_before = Date.new!(1918, 1, 31, calendar)
      assert Date.shift(day_before, day: 1) == Date.new!(1918, 2, 14, calendar)

      for d <- 1..13 do
        refute calendar.valid_date?(1918, 2, d), "expected #{d} Feb 1918 to be invalid"
      end
    end
  end

  describe "calendar_for/1 — curated calendars" do
    test "Sweden returns the curated Calendrical.Reform.Sweden" do
      assert {:ok, Calendrical.Reform.Sweden} = Calendrical.Reform.calendar_for(:SE)
      # The curated calendar models the transitional history (30 February 1712).
      assert Calendrical.Reform.Sweden.valid_date?(1712, 2, 30)
    end

    test "Japan returns the curated lunisolar Calendrical.Reform.Japan" do
      assert {:ok, Calendrical.Reform.Japan} = Calendrical.Reform.calendar_for(:JP)
    end

    test "the raw reform table still records ncal's simplified data" do
      # reform_date/reforms expose the ncal table even where calendar_for is curated.
      assert {:ok, %{last_julian: ~D[1753-02-17 Calendrical.Julian]}} =
               Calendrical.Reform.reform_date(:SE)

      assert Calendrical.Reform.reforms()[:JP].last_julian ==
               ~D[1918-12-18 Calendrical.Julian]
    end
  end

  describe "calendar_for/1 errors and idempotency" do
    test "returns :unknown_territory for a code with no reform date" do
      assert {:error, :unknown_territory} = Calendrical.Reform.calendar_for(:XX)
    end

    test "is idempotent — the same territory returns the same module" do
      assert {:ok, first} = Calendrical.Reform.calendar_for(:FR)
      assert {:ok, second} = Calendrical.Reform.calendar_for(:FR)
      assert first == second
    end
  end
end
