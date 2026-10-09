defmodule Calendrical.CompositeDiffTest do
  @moduledoc """
  The count of years, quarters, months, weeks and days between two dates of
  a composite calendar: the inverse of its `plus/6`, the largest count it can
  add to the earlier date without passing the later.

  The counts expected here are worked by hand from the days themselves. Where
  two stretches of days carry the same dates the later has none of its own
  (England's 1 January to 24 March 1156, the test calendar of Russia's
  September to December 1699), and a count runs through them as through any
  other days. Where a change of calendar changes the numbers of the years, as
  Japan's did from 1228 to 1873, the years between are no years of the count.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}
  alias Calendrical.Russia

  describe "across days that have no dates of their own" do
    # The Julian 15 June to 20 December 1155 are the Lady Day year's
    # month 4 day 15 to month 10 day 20: six months and five days.
    test "counts the months to a date before them" do
      assert England.diff({1155, 4, 15}, {1155, 10, 20}, :months) == 6
      assert England.diff({1155, 10, 20}, {1155, 4, 15}, :months) == -6
      assert England.diff({1155, 4, 15}, {1155, 10, 20}, :quarters) == 2
      assert England.diff({1155, 4, 15}, {1155, 10, 20}, :years) == 0
      assert England.diff({1155, 4, 15}, {1155, 10, 20}, :days) == 188
      assert England.diff({1155, 4, 15}, {1155, 10, 20}, :weeks) == 26
    end

    # The Julian 20 December 1154, a date of the base calendar, to 10
    # April 1156, the Lady Day year 1156's month 2 day 10: 477 days
    # through the dateless stretch, and seventeen months — the months
    # of the stretch are walked too, and 1155 holds thirteen.
    test "counts through them to a date after them" do
      assert England.diff({1154, 12, 20}, {1156, 2, 10}, :months) == 17
      assert England.diff({1156, 2, 10}, {1154, 12, 20}, :months) == -17
      assert England.diff({1154, 12, 20}, {1156, 2, 10}, :quarters) == 5
      assert England.diff({1154, 12, 20}, {1156, 2, 10}, :years) == 1
      assert England.diff({1154, 12, 20}, {1156, 2, 10}, :days) == 477
      assert England.diff({1154, 12, 20}, {1156, 2, 10}, :weeks) == 68

      # A year of thirteen counted months, and the month before it.
      assert England.diff({1155, 4, 15}, {1156, 4, 15}, :months) == 13
      assert England.diff({1155, 4, 15}, {1156, 4, 14}, :months) == 12
      assert England.diff({1155, 4, 15}, {1156, 4, 15}, :years) == 1
      assert England.diff({1155, 4, 15}, {1156, 4, 14}, :years) == 0
    end

    # In the test calendar of Russia the days of September to December
    # 1699 have no dates and no months. The September year 1699's month
    # 10, the Julian June, to the January year 1700's February is eight
    # dated months, and to its June a year.
    test "counts through them where they begin a year" do
      assert Russia.diff({1699, 10, 15}, {1700, 2, 15}, :months) == 8
      assert Russia.diff({1699, 10, 15}, {1700, 2, 14}, :months) == 7
      assert Russia.diff({1699, 10, 15}, {1700, 6, 15}, :years) == 1
      assert Russia.diff({1700, 6, 15}, {1699, 10, 15}, :months) == -12
    end
  end

  describe "across a change of the years' numbers" do
    # The tenth day of the fifth month of Japan's lunisolar 1228, Meiji 5, is
    # 15 June 1872, and its year gave way to 1873 on 1 January. To 10 June
    # 1873 is 360 days: seven lunisolar months to the year's twelfth, and
    # six of the Gregorian calendar's to June.
    test "counts the years and months that pass, not the years between the numbers" do
      assert Japan.diff({1228, 5, 10}, {1873, 6, 10}, :days) == 360
      assert Japan.diff({1228, 5, 10}, {1873, 6, 10}, :years) == 1
      assert Japan.diff({1228, 5, 10}, {1873, 6, 10}, :months) == 13
      assert Japan.diff({1228, 5, 10}, {1873, 6, 9}, :months) == 12
      assert Japan.diff({1228, 5, 10}, {1873, 6, 10}, :quarters) == 4
      assert Japan.diff({1873, 6, 10}, {1228, 5, 10}, :months) == -13
      assert Japan.diff({1873, 6, 10}, {1228, 5, 10}, :years) == -1
    end

    # A year and a month: the fifth month a year on is May 1873, and June is
    # the month after it.
    test "is what Localize measures a duration with" do
      from = Date.new!(1228, 5, 10, Japan)
      to = Date.new!(1873, 6, 10, Japan)

      assert {:ok, %Localize.Duration{year: 1, month: 1, day: 0}} =
               Localize.Duration.new(from, to)
    end
  end

  # The count is the inverse of `plus/6`: the largest count that does not
  # pass the later date. About the changes of calendar below every day has a
  # date of its own, so the day `plus/6` reaches is the day its date names.
  describe "is the largest count plus/6 can add without passing the later date" do
    test "about each change of calendar" do
      {:ok, russia} = Calendrical.Reform.calendar_for(:RU)

      for {calendar, changes} <- [
            {Sweden, changes(Sweden)},
            {russia, changes(russia)},
            {England, Enum.drop(changes(England), 1)}
          ],
          change <- changes,
          from_days <- (change - 400)..(change + 400)//17,
          span <- [1, 45, 200, 400, 800],
          date_part <- [:months, :years, :quarters] do
        from = calendar.date_from_iso_days(from_days)
        to = calendar.date_from_iso_days(from_days + span)
        count = calendar.diff(from, to, date_part)
        context = "#{inspect(calendar)} #{inspect(from)} #{inspect(to)} #{date_part}"

        assert reached(calendar, from, date_part, count) <= from_days + span, context
        assert reached(calendar, from, date_part, count + 1) > from_days + span, context
        assert calendar.diff(to, from, date_part) == -count, context
      end
    end
  end

  # The search itself, on calendars whose days are numbered from 0 and whose
  # months and years are plain numbers of days: the first count tried comes
  # from the days between the two dates, at 31 days a month and 366 a year,
  # and is far too small where a month is ten days and far too large where
  # it is fifty.
  describe "Calendrical.Composite.Diff.diff/4" do
    alias Calendrical.Composite.Diff

    defmodule Tens do
      @moduledoc false
      def date_to_iso_days(_year, _month, day), do: day
      def days_in_week, do: 7
      def reach(_year, _month, day, :months, count), do: day + count * 10
      def reach(_year, _month, day, :years, count), do: day + count * 100
    end

    defmodule Fifties do
      @moduledoc false
      def date_to_iso_days(_year, _month, day), do: day
      def days_in_week, do: 7
      def reach(_year, _month, day, :months, count), do: day + count * 50
      def reach(_year, _month, day, :years, count), do: day + count * 5000
    end

    test "finds a count far above the first tried" do
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1000}, :months) == 99
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1003}, :months) == 100
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1000}, :years) == 9
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1000}, :quarters) == 33
      assert Diff.diff(Tens, {0, 0, 1000}, {0, 0, 3}, :months) == -99
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 3}, :months) == 0
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 12}, :months) == 0
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 13}, :months) == 1
    end

    test "finds a count far below the first tried" do
      assert Diff.diff(Fifties, {0, 0, 0}, {0, 0, 10_000}, :months) == 200
      assert Diff.diff(Fifties, {0, 0, 0}, {0, 0, 9_999}, :months) == 199
      assert Diff.diff(Fifties, {0, 0, 0}, {0, 0, 10_000}, :years) == 2
      assert Diff.diff(Fifties, {0, 0, 0}, {0, 0, 4_999}, :years) == 0
      assert Diff.diff(Fifties, {0, 0, 10_000}, {0, 0, 0}, :months) == -200
      assert Diff.diff(Fifties, {0, 0, 0}, {0, 0, 40}, :months) == 0
    end

    test "counts weeks and days from the days themselves" do
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1000}, :days) == 997
      assert Diff.diff(Tens, {0, 0, 3}, {0, 0, 1000}, :weeks) == 142
      assert Diff.diff(Tens, {0, 0, 1000}, {0, 0, 3}, :weeks) == -142
    end
  end

  # Meiji 3, 1226 of Japan's lunisolar calendar, had a second tenth month and
  # so thirteen months, more days than the 366 a first count of the years is
  # taken at. From the tenth of its first month to the fifth of the next
  # year's first month is thirteen months less five days.
  describe "in a lunisolar year of thirteen months" do
    test "counts no year until the year is out" do
      assert Japan.months_in_year(1226) == 13
      assert Japan.diff({1226, 1, 10}, {1227, 1, 5}, :years) == 0
      assert Japan.diff({1226, 1, 10}, {1227, 1, 5}, :months) == 12
      assert Japan.diff({1226, 1, 10}, {1227, 1, 10}, :years) == 1
      assert Japan.diff({1226, 1, 10}, {1227, 1, 10}, :months) == 13
    end
  end

  defp changes(calendar) do
    calendar.__config__() |> Enum.drop(1) |> Enum.map(&elem(&1, 0))
  end

  defp reached(calendar, {year, month, day}, date_part, count) do
    {year, month, day} = calendar.plus(year, month, day, date_part, count)
    calendar.date_to_iso_days(year, month, day)
  end
end
