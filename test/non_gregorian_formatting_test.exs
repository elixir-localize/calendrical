defmodule Calendrical.NonGregorianFormattingTest do
  use ExUnit.Case, async: true

  # Localize writes `w` and `Y` in the date's calendar's own weeks, its
  # `week_of_year/3`, never the locale's week data, so each calendar here is
  # its own oracle.
  describe "Localize.DateTime.Formatter — the calendar's own weeks" do
    test "a Hebrew date's week is the Hebrew calendar's" do
      {:ok, date} = Date.new(5784, 9, 12, Calendrical.Hebrew)
      {week_year, week} = Calendrical.Hebrew.week_of_year(5784, 9, 12)

      assert Localize.DateTime.Formatter.format(date, "w", :"he-IL", %{}) ==
               {:ok, Integer.to_string(week)}

      assert Localize.DateTime.Formatter.format(date, "Y", :"he-IL", %{}) ==
               {:ok, Integer.to_string(week_year)}
    end

    test "a Japanese date's week is the Japanese calendar's" do
      {:ok, date} = Date.new(2024, 7, 1, Calendrical.Japanese)
      {_week_year, week} = Calendrical.Japanese.week_of_year(2024, 7, 1)

      assert Localize.DateTime.Formatter.format(date, "w", :"ja-JP", %{}) ==
               {:ok, Integer.to_string(week)}
    end

    test "a Buddhist date's week is the Buddhist calendar's" do
      {:ok, date} = Date.new(2569, 5, 16, Calendrical.Buddhist)
      {_week_year, week} = Calendrical.Buddhist.week_of_year(2569, 5, 16)

      assert Localize.DateTime.Formatter.format(date, "w", :"th-TH", %{}) ==
               {:ok, Integer.to_string(week)}
    end
  end
end
