defmodule Calendrical.CompositeShiftTest do
  @moduledoc """
  Shifting a date of a composite calendar by years and months, about every
  change of calendar.

  The rule is the one `Calendrical.Composite` documents: the months are
  counted on through each calendar's own months, a year being twelve of them,
  and a day the month reached does not have becomes the month's next day that
  exists, or its last.

  The expected dates are found by that rule on the calendar's days, and
  never by its arithmetic. A day's civil month is the month of the calendar
  in effect on it, the Julian calendar's for a Julian year reckoned from
  another day than 1 January, whatever number that style gives the year. The
  month reached is that month and twelve months a year and the months on, and
  its days are the days of the calendar that fall in it. Only
  `date_from_iso_days/1`, `calendar_for_iso_days/1`, and the reading of a
  date back as its day are asked of the composite.

  Where a year's number does not change on 1 January two stretches of days
  carry the same year, month and day (England's January to 24 March of 1155
  and of 1156), and the later has no dates. A day of it is no day of its
  month here, and a month with no dates is left out.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Sweden}
  alias Calendrical.Russia

  # A year reckoned from Christmas, then from 25 March, then from 1 January.
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

  # A year reckoned from 1 September that takes effect on 15 November, part
  # of the way through a month and through its own year.
  defmodule MidYear do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [Date.new!(1493, 11, 15, Calendrical.Julian.Sept1)],
      base_calendar: Calendrical.Julian
  end

  # A year reckoned from 25 March and then from 1 September.
  defmodule September do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1155-03-25 Calendrical.Julian.March25],
        ~D[1500-09-01 Calendrical.Julian.Sept1]
      ],
      base_calendar: Calendrical.Julian
  end

  # A year reckoned from 1 March, whose January and February carry the
  # number of the year before.
  defmodule March do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[1400-03-01 Calendrical.Julian.March1]],
      base_calendar: Calendrical.Julian
  end

  # The Coptic calendar, of thirteen months, and then the Julian, as the
  # example of `Calendrical.Composite` has Egypt.
  defmodule Egypt do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[-0045-01-01 Calendrical.Julian]],
      base_calendar: Calendrical.Coptic
  end

  @julian_styles [
    Calendrical.Julian,
    Calendrical.Julian.Jan1,
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25
  ]

  @durations [
    [month: 1],
    [month: -1],
    [month: 2],
    [month: -2],
    [month: 7],
    [month: -7],
    [month: 12],
    [month: -12],
    [month: 13],
    [month: -13],
    [year: 1],
    [year: -1],
    [year: 2],
    [year: -2],
    [year: 1, month: 1],
    [year: -1, month: 3],
    [year: 1, month: -1],
    [year: -2, month: 11],
    [year: 3, month: -30]
  ]

  # The furthest a duration above reaches, in days, and a month over.
  @reach 1300

  defp civil(calendar, iso_days) do
    member = calendar.calendar_for_iso_days(iso_days)
    civil = if member in @julian_styles, do: Calendrical.Julian, else: member

    civil.date_from_iso_days(iso_days)
  end

  # A day is a date when its year, month and day read back as the day.
  defp date?(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)

    calendar.valid_date?(year, month, day) and
      calendar.date_to_iso_days(year, month, day) == iso_days
  end

  defp changes(calendar) do
    calendar.__config__() |> Enum.drop(1) |> Enum.map(&elem(&1, 0))
  end

  # The dates of each civil month about the calendar's changes, by their
  # day of the month.
  defp months(calendar, window) do
    calendar
    |> changes()
    |> Enum.flat_map(&((&1 - window - @reach)..(&1 + window + @reach)))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.filter(&date?(calendar, &1))
    |> Enum.group_by(
      fn iso_days ->
        {year, month, _day} = civil(calendar, iso_days)
        {year, month}
      end,
      fn iso_days -> {elem(civil(calendar, iso_days), 2), iso_days} end
    )
  end

  # The date a duration of years and months reaches from a day, by the rule.
  defp reached(calendar, months, iso_days, duration) do
    {year, month, day} = civil(calendar, iso_days)
    count = Keyword.get(duration, :year, 0) * 12 + Keyword.get(duration, :month, 0)
    index = year * 12 + (month - 1) + count

    case Map.get(months, {Integer.floor_div(index, 12), Integer.mod(index, 12) + 1}) do
      nil ->
        :no_date_in_the_month

      days ->
        {_day, iso_days} =
          Enum.find(days, &(elem(&1, 0) == day)) ||
            Enum.find(days, &(elem(&1, 0) > day)) ||
            List.last(days)

        calendar.date_from_iso_days(iso_days)
    end
  end

  # Every shift of every date within `window` days of a change of calendar
  # that does not reach the date the rule gives: `{date, shift, got, expected}`.
  defp wrong(calendar, window) do
    months = months(calendar, window)

    dates =
      calendar
      |> changes()
      |> Enum.flat_map(&((&1 - window)..(&1 + window)))
      |> Enum.uniq()
      |> Enum.filter(&date?(calendar, &1))

    for iso_days <- dates,
        duration <- @durations,
        expected = reached(calendar, months, iso_days, duration),
        expected != :no_date_in_the_month,
        {year, month, day} = calendar.date_from_iso_days(iso_days),
        {shift, got} <- shifts(calendar, year, month, day, duration),
        got != expected do
      {{year, month, day}, shift, got, expected}
    end
  end

  # A duration through `shift_date/4`, as `Date.shift/2` asks, and through
  # `plus/6` as months, and as years where it is whole years.
  defp shifts(calendar, year, month, day, duration) do
    years = Keyword.get(duration, :year, 0)
    months = Keyword.get(duration, :month, 0)

    [
      {duration, calendar.shift_date(year, month, day, Duration.new!(duration))},
      {{:months, years * 12 + months},
       calendar.plus(year, month, day, :months, years * 12 + months)}
    ] ++
      if months == 0,
        do: [{{:years, years}, calendar.plus(year, month, day, :years, years)}],
        else: []
  end

  describe "a shift by years and months reaches the month counted on, and its day" do
    test "in England, whose year turned on 25 March from 1155 to 1751" do
      assert wrong(England, 420) == []
    end

    test "in Sweden, with its transitional calendar of 1700 to 1712" do
      assert wrong(Sweden, 420) == []
    end

    test "in Russia, whose year turned on 1 March, then 1 September, then 1 January" do
      assert wrong(Russia, 420) == []
    end

    test "where a year reckoned from Christmas, 25 March, 1 September or 1 March takes effect" do
      for calendar <- [Christmas, MidYear, September, March] do
        assert wrong(calendar, 420) == [], inspect(calendar)
      end
    end

    # Japan's calendar before 1873 was lunisolar, with a thirteenth month in
    # some years: the rule's twelve months a year is not its own.
    test "in every territory's reform calendar from the Julian to the Gregorian" do
      for {territory, _reform} <- Calendrical.Reform.reforms(),
          {:ok, calendar} = Calendrical.Reform.calendar_for(territory),
          calendar != Calendrical.Reform.Japan do
        assert wrong(calendar, 120) == [], inspect(calendar)
      end
    end
  end

  # England's 1751 began on 25 March and ended on 31 December, so its March
  # has no first day, and the March before it, of 1750, ended on the 24th.
  describe "a month a change of calendar begins part of the way through" do
    test "is shifted from, by months and by years" do
      assert Date.shift(~D[1751-03-25 Calendrical.Reform.England], month: 1) ==
               ~D[1751-04-25 Calendrical.Reform.England]

      assert Date.shift(~D[1751-03-25 Calendrical.Reform.England], month: -1) ==
               ~D[1750-02-25 Calendrical.Reform.England]

      assert Date.shift(~D[1751-03-25 Calendrical.Reform.England], year: 1) ==
               ~D[1752-03-25 Calendrical.Reform.England]

      assert Date.shift(~D[1751-03-25 Calendrical.Reform.England], year: -1) ==
               ~D[1750-03-25 Calendrical.Reform.England]

      assert Date.shift(~D[1751-03-31 Calendrical.Reform.England], year: -1, month: 3) ==
               ~D[1750-06-30 Calendrical.Reform.England]
    end

    # 10 March 1752, a year back, is 10 March 1751: a day of the year that
    # began on 25 March 1750.
    test "is shifted to" do
      assert Date.shift(~D[1752-03-10 Calendrical.Reform.England], year: -1) ==
               ~D[1750-03-10 Calendrical.Reform.England]

      assert Date.shift(~D[1750-03-10 Calendrical.Reform.England], year: 1) ==
               ~D[1752-03-10 Calendrical.Reform.England]

      assert Date.shift(~D[1751-04-10 Calendrical.Reform.England], month: -1) ==
               ~D[1750-03-10 Calendrical.Reform.England]
    end

    # Russia went from 31 January to 14 February 1918.
    test "where a reform took the first days of the month" do
      {:ok, calendar} = Calendrical.Reform.calendar_for(:RU)

      assert Date.shift(Date.new!(1918, 2, 20, calendar), year: -1) ==
               Date.new!(1917, 2, 20, calendar)

      assert Date.shift(Date.new!(1918, 2, 20, calendar), month: -1) ==
               Date.new!(1918, 1, 20, calendar)

      assert Date.shift(Date.new!(1917, 2, 5, calendar), year: 1) ==
               Date.new!(1918, 2, 14, calendar)
    end

    # Japan's lunisolar year 1228 of the calendar, Meiji 5, had twelve
    # months, and its twelfth had two days: the day after the second was
    # 1 January 1873. Under the lunisolar calendar a year keeps the month
    # by its name: Meiji 3, 1226, had a second tenth month, so its twelfth
    # month is the thirteenth of the year. Meiji 6 would have had a second
    # sixth month, so a year from the tenth month of Meiji 5 is thirteen
    # months, counted on into November 1873: 22 November, a year after the
    # 22 November 1872 it began on.
    test "where a lunisolar calendar gave way to the Gregorian" do
      japan = Calendrical.Reform.Japan

      for {date, duration, expected} <- [
            {{1228, 5, 10}, [year: 1], {1873, 5, 10}},
            {{1228, 5, 10}, [month: 7], {1228, 12, 2}},
            {{1228, 5, 10}, [month: 13], {1873, 6, 10}},
            {{1228, 12, 1}, [month: 1], {1873, 1, 1}},
            {{1873, 1, 21}, [month: -1], {1228, 12, 2}},
            {{1873, 1, 1}, [year: -1], {1228, 1, 1}},
            {{1874, 2, 25}, [year: -2], {1228, 2, 25}},
            {{1228, 5, 10}, [year: 1, month: 1], {1873, 6, 10}},
            {{1228, 10, 22}, [year: 1], {1873, 11, 22}},
            {{1228, 10, 22}, [month: 12], {1873, 10, 22}},
            {{1228, 12, 1}, [year: -2], {1226, 13, 1}},
            {{1228, 5, 10}, [year: -1], {1227, 5, 10}},
            {{1227, 5, 10}, [year: -1], {1226, 5, 10}},
            {{1226, 5, 10}, [year: 1], {1227, 5, 10}},
            {{1226, 5, 10}, [month: 12], {1227, 4, 10}}
          ] do
        {year, month, day} = date

        assert japan.shift_date(year, month, day, Duration.new!(duration)) == expected,
               "#{inspect(date)} #{inspect(duration)}"
      end
    end

    # A year is as many months as the calendar in effect on the date
    # counts: thirteen in the Coptic calendar. The Julian calendar took
    # effect part of the way through a Coptic month, so a year on from the
    # month before is that month, and its last day where it lacks the day;
    # and a year on from the month after is the thirteenth month counted
    # on, the Julian calendar's first.
    test "where a calendar of thirteen months gave way to one of twelve" do
      [change] = changes(Egypt)
      {year, month, last} = Egypt.date_from_iso_days(change - 1)
      {julian_year, julian_month, 1} = Egypt.date_from_iso_days(change)
      a_year = Duration.new!(year: 1)

      assert Egypt.calendar_for_iso_days(change - 1) == Calendrical.Coptic
      assert last < 30

      assert Egypt.shift_date(year - 1, month, last, a_year) == {year, month, last}
      assert Egypt.shift_date(year - 1, month, last + 1, a_year) == {year, month, last}
      assert Egypt.plus(year - 1, month, last + 1, :years, 1) == {year, month, last}
      assert Egypt.plus(year - 1, month, last + 1, :months, 13) == {year, month, last}

      assert Egypt.shift_date(year - 1, month + 1, 10, a_year) == {julian_year, julian_month, 10}
      assert Egypt.plus(year - 1, month + 1, 10, :years, 1) == {julian_year, julian_month, 10}

      assert Egypt.shift_date(year - 1, month - 1, 10, a_year) == {year, month - 1, 10}
    end

    test "with a time of day" do
      noon = NaiveDateTime.new!(1751, 3, 25, 12, 0, 0, {0, 0}, Calendrical.Reform.England)

      assert NaiveDateTime.shift(noon, month: -1, hour: 1) ==
               NaiveDateTime.new!(1750, 2, 25, 13, 0, 0, {0, 0}, Calendrical.Reform.England)
    end
  end

  # The months a member calendar counts for a shift, which are the months
  # walked across a change of calendar.
  describe "Calendrical.Composite.Shift.months/4" do
    alias Calendrical.Composite.Shift

    test "is twelve a year in a calendar of twelve months" do
      assert Shift.months(Calendrical.Gregorian, 2026, 6, Duration.new!(year: 1)) == 12
      assert Shift.months(Calendrical.Gregorian, 2026, 6, Duration.new!(month: 7)) == 7
      assert Shift.months(Calendrical.Julian, 1582, 10, Duration.new!(year: -3, month: 2)) == -34

      assert Shift.months(Calendrical.Julian.March25, 1751, 3, Duration.new!(year: 2, month: -1)) ==
               23
    end

    test "is thirteen a year in the Coptic calendar, of thirteen months" do
      assert Shift.months(Calendrical.Coptic, 1742, 5, Duration.new!(year: 1)) == 13
      assert Shift.months(Calendrical.Coptic, 1742, 5, Duration.new!(year: -2, month: 1)) == -25
    end

    # The year after Meiji 5, 1229 had the lunisolar calendar gone on, has a
    # second sixth month.
    test "runs through a lunisolar calendar's leap month" do
      assert Shift.months(Calendrical.LunarJapanese, 1228, 5, Duration.new!(year: 1)) == 12
      assert Shift.months(Calendrical.LunarJapanese, 1228, 10, Duration.new!(year: 1)) == 13
    end

    # England's March 1751 began on the 25th.
    test "is twelve a year where the calendar is a composite, and has no first of the month" do
      england = Calendrical.Reform.England

      refute england.valid_date?(1751, 3, 1)
      assert Shift.months(england, 1751, 3, Duration.new!(year: 2, month: 1)) == 25
      assert Shift.months(england, 1751, 3, Duration.new!(year: -1)) == -12
    end

    test "is the count itself for plus/6 by months, and a year's months by years" do
      assert Shift.months(Calendrical.Coptic, 1742, 5, :months, 7) == 7
      assert Shift.months(Calendrical.Coptic, 1742, 5, :years, 2) == 26
      assert Shift.months(Calendrical.Gregorian, 2026, 6, :years, -3) == -36
    end
  end
end
