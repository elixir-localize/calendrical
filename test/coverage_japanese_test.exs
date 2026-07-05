defmodule Calendrical.Coverage.JapaneseTest do
  @moduledoc """
  Coverage tests for `Calendrical.Japanese`, the Gregorian-based Japanese
  calendar with imperial era structure.

  Era anchors: Reiwa (era 236) began 2019-05-01, Heisei (era 235) began
  1989-01-08, Showa (era 234) began 1926-12-25.

  """
  use ExUnit.Case, async: true

  alias Calendrical.Japanese

  describe "era transitions" do
    test "year_of_era/3 at the Reiwa transition (2019-05-01)" do
      assert Japanese.year_of_era(2019, 5, 1) == {1, 236}
      assert Japanese.year_of_era(2019, 4, 30) == {31, 235}
      assert Japanese.year_of_era(2026, 7, 5) == {8, 236}
    end

    test "year_of_era/3 at the Heisei transition (1989-01-08)" do
      assert Japanese.year_of_era(1989, 1, 8) == {1, 235}
      assert Japanese.year_of_era(1989, 1, 7) == {64, 234}
    end

    test "year_of_era/3 at the Showa transition (1926-12-25)" do
      assert Japanese.year_of_era(1926, 12, 25) == {1, 234}
    end

    test "year_of_era/1 uses the first day of the year" do
      assert Japanese.year_of_era(2019) == {31, 235}
      assert Japanese.year_of_era(2026) == {8, 236}
    end

    test "day_of_era/3 counts days from the era proclamation" do
      assert Japanese.day_of_era(2019, 5, 1) == {1, 236}
      assert Japanese.day_of_era(2019, 4, 30) == {11_070, 235}
    end

    test "calendar_year/3 is the era year" do
      assert Japanese.calendar_year(2019, 5, 1) == 1
      assert Japanese.calendar_year(2019, 4, 30) == 31
    end
  end

  describe "gregorian behaviour" do
    test "leap_year?/1 follows the Gregorian rules" do
      assert Japanese.leap_year?(2024)
      refute Japanese.leap_year?(2023)
      refute Japanese.leap_year?(1900)
      assert Japanese.leap_year?(2000)
    end

    test "valid_date?/3 true and false branches" do
      assert Japanese.valid_date?(2024, 2, 29)
      refute Japanese.valid_date?(2023, 2, 29)
      refute Japanese.valid_date?(2024, 13, 1)
    end

    test "days_in_month/2 and days_in_year/1" do
      assert Japanese.days_in_month(2024, 2) == 29
      assert Japanese.days_in_month(2023, 2) == 28
      assert Japanese.days_in_year(2024) == 366
      assert Japanese.days_in_year(2023) == 365
    end

    test "date_to_iso_days/3 and date_from_iso_days/1 round trip" do
      iso_days = Japanese.date_to_iso_days(2019, 5, 1)
      assert iso_days == Calendar.ISO.date_to_iso_days(2019, 5, 1)
      assert Japanese.date_from_iso_days(iso_days) == {2019, 5, 1}
    end

    test "day, month and quarter callbacks" do
      assert Japanese.month_of_year(2026, 7, 5) == 7
      assert Japanese.quarter_of_year(2026, 7, 5) == 3
      assert Japanese.day_of_year(2026, 7, 5) == 186
      assert Japanese.months_in_year(2024) == 12
      assert Japanese.cldr_calendar_type() == :japanese
    end
  end

  describe "conversions" do
    test "Date.convert/2 round trips through Calendar.ISO" do
      japanese_date = Date.convert!(~D[2019-05-01], Japanese)
      assert japanese_date == Date.new!(2019, 5, 1, Japanese)
      assert Date.convert(japanese_date, Calendar.ISO) == {:ok, ~D[2019-05-01]}
    end
  end

  describe "localization" do
    test "localized era names across the Reiwa transition" do
      assert Calendrical.localize(Date.new!(2019, 4, 30, Japanese), :era) == "Heisei"
      assert Calendrical.localize(Date.new!(2019, 5, 1, Japanese), :era) == "Reiwa"
    end

    test "localized month name" do
      assert Calendrical.localize(Date.new!(2019, 5, 1, Japanese), :month) == "May"
    end
  end
end
