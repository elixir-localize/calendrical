defmodule Calendrical.CompositeLabelTest do
  @moduledoc """
  The calendar a composite reads a date's year, month and day in.

  A date falls, by the order of its year, month and day, in the segment of
  the last change of calendar whose first day's it is not before. A calendar
  whose year turns after its first month has days that come, by that order,
  before the day it took effect on: Russia's year reckoned from 1 September
  began on 1 September 1492 as 1493, and that year's January to August fell
  to the calendar before, where they are no days. Such a date is read in the
  segment that has its year.

  Nothing expected here comes from the code under test. A day's year, month
  and day are those of the calendar in effect on it, the member's own
  `date_from_iso_days/1`, and the test is that they read back as the day: for
  every day whose year, month and day no other day has. Two days that have
  them alike, as 15 January 1155 and 15 January 1156 in England, can be
  named by them only once.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}
  alias Calendrical.Russia

  # A year reckoned from Christmas, then from 25 March, then from 1 January:
  # each of the first two turns after its first month.
  defmodule Christmas do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1100-12-25 Calendrical.Julian.Dec25],
        ~D[1300-03-25 Calendrical.Julian.March25],
        ~D[1600-01-01 Calendrical.Julian.Jan1]
      ],
      base_calendar: Calendrical.Julian
  end

  # A year reckoned from 25 March, as England's was, and then from 1
  # September: the September year takes effect under a calendar that is not
  # the base calendar.
  defmodule September do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1155-03-25 Calendrical.Julian.March25],
        ~D[1500-09-01 Calendrical.Julian.Sept1]
      ],
      base_calendar: Calendrical.Julian
  end

  # Every territory's reform calendar, and the calendars above.
  defp composites do
    reforms =
      for {territory, _reform} <- Calendrical.Reform.reforms(),
          {:ok, calendar} <- [Calendrical.Reform.calendar_for(territory)],
          do: calendar

    Enum.uniq([England, Sweden, Japan, Russia, Christmas, September | reforms])
  end

  # The days about each change of calendar whose year, month and day are no
  # other day's, and do not read back as the day.
  defp unread(calendar, days_about_a_change) do
    changes = calendar.__config__() |> Enum.drop(1) |> Enum.map(&elem(&1, 0))

    days =
      changes
      |> Enum.flat_map(&((&1 - days_about_a_change)..(&1 + days_about_a_change)))
      |> Enum.uniq()

    labels = Map.new(days, &{&1, calendar.date_from_iso_days(&1)})
    days_with = labels |> Map.values() |> Enum.frequencies()

    for iso_days <- Enum.sort(days),
        {year, month, day} = label = Map.fetch!(labels, iso_days),
        Map.fetch!(days_with, label) == 1,
        not (calendar.valid_date?(year, month, day) and
               calendar.date_to_iso_days(year, month, day) == iso_days) do
      label
    end
  end

  describe "a day whose year, month and day are no other day's" do
    # 29 February 1156 is the one exception, where the year turned on 25
    # March from 1155. Its January to 24 March carry the year 1155, as the
    # January to 24 March before them do, and are read as those: February
    # 1155, which had 28 days.
    test "is a date of the calendar, and reads back as the day" do
      for calendar <- composites() do
        expected = if calendar in [England, September], do: [{1155, 2, 29}], else: []

        # Japan's lunisolar months are found from new moons, a few a second.
        days_about_a_change = if calendar == Japan, do: 90, else: 800

        assert unread(calendar, days_about_a_change) == expected, inspect(calendar)
      end
    end

    test "is read in the calendar in effect on it" do
      for calendar <- [England, Sweden, Russia, Christmas],
          {change, _year, _month, _day, _calendar} <- Enum.drop(calendar.__config__(), 1),
          iso_days <- (change - 400)..(change + 400)//7 do
        {year, month, day} = calendar.date_from_iso_days(iso_days)

        if calendar.valid_date?(year, month, day) and
             calendar.date_to_iso_days(year, month, day) == iso_days do
          assert calendar.calendar_for_date(year, month, day) ==
                   calendar.calendar_for_iso_days(iso_days),
                 "#{inspect(calendar)} #{inspect({year, month, day})}"
        end
      end
    end
  end

  describe "the first year of a calendar whose year turns after its first month" do
    # The year Russia reckoned from 1 September began on 1 September 1492
    # and ran to 31 August 1493: 365 days, each a date of the calendar.
    test "has every one of its days, those before the day it took effect on too" do
      first = Date.convert!(~D[1492-09-01 Calendrical.Julian], Russia)

      for offset <- 0..364 do
        date = Date.add(first, offset)

        assert date.year == 1493
        assert Russia.valid_date?(date.year, date.month, date.day), inspect(date)
        assert Date.diff(date, first) == offset, inspect(date)
        assert Russia.calendar_for_date(date) == Calendrical.Julian.Sept1
      end

      assert Date.add(first, 365).year == 1494

      assert Date.convert!(~D[1493-01-15 Calendrical.Russia], Calendrical.Julian) ==
               ~D[1493-01-15 Calendrical.Julian]

      assert Date.new(1493, 1, 15, Russia) == {:ok, ~D[1493-01-15 Calendrical.Russia]}

      assert Date.day_of_week(~D[1493-01-15 Calendrical.Russia]) ==
               Date.day_of_week(~D[1493-01-15 Calendrical.Julian])
    end

    # 1493 was no leap year, and the year ran from September 1492 to August
    # 1493, twelve months of the calendar in effect.
    test "is the year its questions are answered for" do
      assert Russia.days_in_year(1493) == 365
      assert Russia.days_in_month(1493, 2) == 28
      refute Russia.leap_year?(1493)
      assert Russia.months_in_year(1493) == 12
    end

    # The year reckoned from 1 September began on 1 September 1499 as 1500,
    # a leap year of the Julian calendar, under the year reckoned from 25
    # March, of which that day was in 1499.
    test "under a calendar that is not the base calendar" do
      assert Date.convert!(~D[1499-09-01 Calendrical.Julian], September) ==
               ~D[1500-09-01 Calendrical.CompositeLabelTest.September]

      assert Date.convert!(~D[1499-08-31 Calendrical.Julian], September) ==
               ~D[1499-08-31 Calendrical.CompositeLabelTest.September]

      for julian <- [
            ~D[1500-01-01 Calendrical.Julian],
            ~D[1500-02-29 Calendrical.Julian],
            ~D[1500-08-31 Calendrical.Julian]
          ] do
        date = Date.convert!(julian, September)

        assert {date.year, date.month, date.day} == {1500, julian.month, julian.day}
        assert September.valid_date?(date.year, date.month, date.day), inspect(date)
        assert September.calendar_for_date(date) == Calendrical.Julian.Sept1
        assert Date.convert!(date, Calendrical.Julian) == julian
      end

      assert September.days_in_year(1500) == 366
      assert September.days_in_month(1500, 2) == 29
    end

    test "in a year reckoned from Christmas" do
      first = Date.convert!(~D[1099-12-25 Calendrical.Julian], Christmas)

      assert first == ~D[1100-12-25 Calendrical.CompositeLabelTest.Christmas]

      for {julian, expected} <- [
            {~D[1099-12-24 Calendrical.Julian], {1099, 12, 24}},
            {~D[1100-01-01 Calendrical.Julian], {1100, 1, 1}},
            {~D[1100-02-29 Calendrical.Julian], {1100, 2, 29}},
            {~D[1100-12-24 Calendrical.Julian], {1100, 12, 24}},
            {~D[1100-12-25 Calendrical.Julian], {1101, 12, 25}}
          ] do
        date = Date.convert!(julian, Christmas)

        assert {date.year, date.month, date.day} == expected
        assert Christmas.valid_date?(date.year, date.month, date.day), inspect(date)
        assert Date.convert!(date, Calendrical.Julian) == julian
      end
    end
  end

  describe "a year, month and day that two days have" do
    # England's year turned on 25 March from 1155: the days of January to
    # 24 March 1156 carry the year 1155, as those of 1155 do, and the year,
    # month and day name the earlier.
    test "name the day of the calendar they fall in by their order" do
      assert Date.convert!(~D[1155-01-15 Calendrical.Reform.England], Calendrical.Julian) ==
               ~D[1155-01-15 Calendrical.Julian]

      assert Date.convert!(~D[1156-01-15 Calendrical.Julian], England) ==
               ~D[1155-01-15 Calendrical.Reform.England]

      # Russia's September to December 1699 carry the year 1700, which the
      # year reckoned from 1 January kept: they name the later.
      assert Date.convert!(~D[1700-09-01 Calendrical.Russia], Calendrical.Julian) ==
               ~D[1700-09-01 Calendrical.Julian]

      assert Date.convert!(~D[1699-09-01 Calendrical.Julian], Russia) ==
               ~D[1700-09-01 Calendrical.Russia]
    end

    test "leave the month they are read in whole" do
      assert England.valid_date?(1155, 2, 28)
      refute England.valid_date?(1155, 2, 29)
      assert England.days_in_month(1155, 2) == 28
      assert Date.new(1155, 2, 29, England) == {:error, :invalid_date}
    end
  end

  describe "a year a calendar took no January of" do
    # England's 1751 ran from 25 March to 31 December, in the calendar
    # whose year was to begin on 1 January: it had no January, and no 29
    # February.
    test "is answered for by the calendar that had the year" do
      refute England.valid_date?(1751, 1, 15)
      refute England.leap_year?(1751)
      assert England.leap_year?(1752)
      assert England.days_in_year(1751) == 282
    end
  end

  describe "a date before the first change of calendar" do
    # The base calendar has no first day: a composite is its base calendar
    # as far back as that goes.
    test "is the base calendar's, however early" do
      for calendar <- [England, Sweden, Russia],
          {base, _first_change} = {hd(calendar.__config__()) |> elem(4), nil},
          {year, month, day} <- [{-9999, 1, 1}, {-10_000, 6, 15}, {-12_345, 12, 31}] do
        context = "#{inspect(calendar)} #{inspect({year, month, day})}"

        assert calendar.calendar_for_date(year, month, day) == base, context

        assert calendar.valid_date?(year, month, day) == base.valid_date?(year, month, day),
               context

        assert calendar.date_to_iso_days(year, month, day) ==
                 base.date_to_iso_days(year, month, day),
               context

        iso_days = base.date_to_iso_days(year, month, day)

        assert calendar.date_from_iso_days(iso_days) == base.date_from_iso_days(iso_days), context
        assert calendar.calendar_for_iso_days(iso_days) == base, context
        assert calendar.days_in_month(year, month) == base.days_in_month(year, month), context
        assert calendar.days_in_year(year) == base.days_in_year(year), context
      end

      assert {:ok, date} = Date.new(-10_000, 6, 15, England)

      assert Date.day_of_week(date) ==
               Date.day_of_week(Date.new!(-10_000, 6, 15, Calendrical.Julian))
    end
  end

  # The rule itself, on segments written out: each a calendar, the days it
  # is in effect on and the years those days carry.
  describe "Calendrical.Composite.Label.segment/5" do
    alias Calendrical.Composite.Label
    alias Calendrical.Julian

    @segments [
      %{calendar: Julian, first: nil, last: 100, first_year: nil, last_year: 1099},
      %{calendar: Julian, first: 101, last: 200, first_year: 1100, last_year: 1100},
      %{calendar: Julian, first: 201, last: nil, first_year: 1100, last_year: nil}
    ]

    test "is the segment a date falls in when that has days of its year" do
      assert Label.segment(@segments, 0, 1099, 6, 15) == 0
      assert Label.segment(@segments, 1, 1100, 6, 15) == 1
      assert Label.segment(@segments, 2, 1100, 6, 15) == 2
      assert Label.segment(@segments, 2, 2026, 6, 15) == 2
    end

    test "is otherwise a segment whose calendar has the date on a day of its own" do
      iso_days = Julian.date_to_iso_days(1100, 6, 15)

      segments = [
        Enum.at(@segments, 0),
        %{Enum.at(@segments, 1) | first: iso_days - 300, last: iso_days - 1},
        %{Enum.at(@segments, 2) | first: iso_days}
      ]

      assert Label.segment(segments, 0, 1100, 6, 15) == 2
      assert Label.segment(segments, 0, 1100, 6, 14) == 1
    end

    # The last day of a segment is a day of it, and the first.
    test "on its first day or its last" do
      iso_days = Julian.date_to_iso_days(1100, 6, 15)

      ends_on = fn last ->
        [
          Enum.at(@segments, 0),
          %{Enum.at(@segments, 1) | first: iso_days - 600, last: iso_days - 301},
          %{
            calendar: Julian,
            first: iso_days - 300,
            last: last,
            first_year: 1100,
            last_year: 1100
          },
          %{Enum.at(@segments, 2) | first: last + 1}
        ]
      end

      assert Label.segment(ends_on.(iso_days), 0, 1100, 6, 15) == 2
      assert Label.segment(ends_on.(iso_days - 1), 0, 1100, 6, 15) == 3
      assert Label.segment(ends_on.(iso_days + 300), 0, 1100, 6, 15) == 2
    end

    # 30 February is no date of the Julian calendar, and 15 June 1100 is a
    # date of it that is on no day of the segments below.
    test "or the first to have the year, where none has the date" do
      assert Label.segment(@segments, 0, 1100, 2, 30) == 1

      segments = List.update_at(@segments, 2, &%{&1 | last: 300})

      assert Label.segment(segments, 0, 1100, 6, 15) == 1
    end

    test "and where no segment has the year, the segment the date falls in" do
      segments = Enum.take(@segments, 2)

      assert Label.segment(segments, 0, 1500, 6, 15) == 0
      assert Label.segment(segments, 1, 1500, 6, 15) == 1
    end
  end
end
