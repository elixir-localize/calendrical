defmodule Calendrical.Diff.Test do
  use ExUnit.Case, async: true

  alias Calendrical.Base.Common

  doctest Calendrical.Hebrew, only: [diff: 3]
  doctest Calendrical.Julian, only: [diff: 3]

  describe "Calendrical.diff/3" do
    test "a Calendar.ISO date counts as a Gregorian one" do
      to = Date.convert!(~D[2027-04-01], Calendrical.Gregorian)
      assert Calendrical.diff(~D[2026-01-01], to, :months) == 15
    end

    test "dates in different calendars are an error" do
      to = Date.convert!(~D[2027-04-01], Calendrical.Julian)

      assert {:error, %Calendrical.IncompatibleCalendarError{}} =
               Calendrical.diff(~D[2026-01-01], to, :months)
    end

    test "a date part that is not one of the five is an error" do
      assert {:error, %Calendrical.InvalidPartError{part: :fortnights}} =
               Calendrical.diff(~D[2026-01-01], ~D[2027-04-01], :fortnights)
    end

    test "a value that is not a date is an error" do
      assert {:error, %Calendrical.MissingFieldsError{}} =
               Calendrical.diff(nil, ~D[2027-04-01], :months)

      assert {:error, %Calendrical.MissingFieldsError{}} =
               Calendrical.diff(~D[2026-01-01], %{year: 2027}, :months)
    end

    test "a calendar that is not a Calendrical calendar is an error" do
      date = %{year: 2026, month: 1, day: 1, calendar: String}

      assert {:error, %Calendrical.InvalidCalendarModuleError{}} =
               Calendrical.diff(date, date, :months)
    end
  end

  describe "a calendar's own arithmetic" do
    test "England's 1752 reform: a month across the dropped days, a day between them" do
      assert Calendrical.Reform.England.diff({1752, 8, 20}, {1752, 9, 20}, :months) == 1
      assert Calendrical.Reform.England.diff({1752, 9, 2}, {1752, 9, 14}, :days) == 1
    end

    test "a Julian year-start variant counts its own counted months" do
      # Label year 2024 of March25 runs 25 March 2024 to 24 March 2025:
      # thirteen counted months, twelve of them whole from its first day.
      assert Calendrical.Julian.March25.diff({2024, 1, 1}, {2024, 13, 24}, :months) == 12
      assert Calendrical.Julian.March25.diff({2024, 1, 1}, {2025, 1, 1}, :months) == 13
    end

    test "a 31st plus a month is the shorter month's last day, one month on" do
      assert Calendrical.Gregorian.diff({2026, 1, 31}, {2026, 2, 28}, :months) == 1
      assert Calendrical.Gregorian.diff({2026, 1, 31}, {2026, 3, 30}, :months) == 1
    end
  end

  describe "a calendar's own month count agrees with the generic count" do
    for {calendar, year} <- [
          {Calendrical.Hebrew, 5780},
          {Calendrical.Chinese, 4660},
          {Calendrical.Korean, 4355},
          {Calendrical.LunarJapanese, 2680},
          {Calendrical.Vietnamese, 4660}
        ] do
      test "#{inspect(calendar)}" do
        calendar = unquote(calendar)
        from = {unquote(year), 1, 1}

        for years <- [1, 7, 19, 60] do
          to = {unquote(year) + years, 1, 1}
          assert calendar.diff(from, to, :months) == Common.diff(calendar, from, to, :months)
        end
      end
    end
  end
end
