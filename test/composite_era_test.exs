defmodule Calendrical.CompositeEraTest do
  @moduledoc """
  A composite calendar counts an era's days in one count through every
  change of calendar the era runs through.

  A member calendar counts an era's days from its own first day of the era,
  and the members' first days differ: the Julian and the Gregorian calendar
  begin the common era two days apart, and a Julian year reckoned from 25
  March begins it 83 days after one reckoned from 1 January. Passing
  `day_of_era/3` to the calendar in effect, as a composite did, stepped the
  count back a day at every Julian to Gregorian change and by 82 and 84 days
  at England's two changes of new-year day.

  The expected counts owe nothing to a calendar's own count of an era's
  days. A day of the common era is the days from the composite's first day
  of that era, plus one, and a day before it the days back from the era's
  last day, plus one, both by `Date.diff/2`. One count is fixed by Julian
  Day Numbers: 1 January AD 1 in the Julian calendar is day 1,721,424 and 14
  September 1752 in the Gregorian is day 2,361,222, the 639,799th day of
  the era.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}

  # The Julian calendar until 25 March 100 BC, then its year reckoned from
  # 25 March, and from 1 January again from AD 200: a change of calendar
  # within the years before the common era, whose days are counted back
  # from their last, 24 March AD 1 here, and a later change those years do
  # not reach.
  defmodule BeforeCommonEra do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[-0100-03-25 Calendrical.Julian.March25],
        ~D[0200-01-01 Calendrical.Julian.Jan1]
      ],
      base_calendar: Calendrical.Julian
  end

  # Three changes of calendar before the common era: to a year reckoned from
  # 25 March in 300 BC, back to one reckoned from 1 January in 200 BC, and
  # to 25 March again in 100 BC, which is the calendar in effect when the
  # era ends, on 24 March AD 1.
  defmodule ThriceBeforeCommonEra do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[-0300-03-25 Calendrical.Julian.March25],
        ~D[-0200-01-01 Calendrical.Julian.Jan1],
        ~D[-0100-03-25 Calendrical.Julian.March25]
      ],
      base_calendar: Calendrical.Julian
  end

  # A year reckoned from 25 March from the first, then from 1 January, then
  # the Gregorian calendar: the common era begins on 25 March AD 1.
  defmodule LadyDayFirst do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1600-01-01 Calendrical.Julian.Jan1],
        ~D[1752-09-14 Calendrical.Gregorian]
      ],
      base_calendar: Calendrical.Julian.March25
  end

  # The Coptic calendar, then the Julian from 45 BC and the Gregorian from
  # 1875, as `Calendrical.Composite` sketches Egypt's: the Coptic calendar
  # names its eras from another CLDR calendar than the other two.
  defmodule Egypt do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[-0045-01-01 Calendrical.Julian],
        ~D[1875-09-01 Calendrical.Gregorian]
      ],
      base_calendar: Calendrical.Coptic
  end

  # The Coptic calendar, then the Julian from AD 400: on either side of the
  # change the era is numbered 1, the Coptic calendar's one era and the
  # common era, which are not one era.
  defmodule CopticThenJulian do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[0400-01-01 Calendrical.Julian]],
      base_calendar: Calendrical.Coptic
  end

  # A change of calendar on the first day of the common era itself: the
  # years before it are the old calendar's and the era the new one's.
  defmodule AtTheEra do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[0001-01-01 Calendrical.Julian.Jan1]],
      base_calendar: Calendrical.Julian
  end

  # A change of calendar on the second day of the common era, so that the
  # era's first day is the last day of the old calendar.
  defmodule OnTheSecondDay do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[0001-01-02 Calendrical.Julian.Jan1]],
      base_calendar: Calendrical.Julian
  end

  # Every territory's reform calendar, with the last Julian day and the
  # first Gregorian day of its reform.
  defp reforms do
    for {territory, %{last_julian: last_julian, first_gregorian: first_gregorian}} <-
          Calendrical.Reform.reforms(),
        {:ok, calendar} <- [Calendrical.Reform.calendar_for(territory)],
        calendar != Japan do
      {calendar, Date.convert!(last_julian, calendar), Date.convert!(first_gregorian, calendar)}
    end
  end

  # A day of the common era as the days from the composite's first day of
  # it, plus one, and a day before it as the days back from the day before
  # that first day, plus one.
  defp counted(date, first_day_of_era) do
    case Date.diff(date, first_day_of_era) do
      days when days >= 0 -> {days + 1, 1}
      days -> {-days, 0}
    end
  end

  describe "a change from the Julian to the Gregorian calendar" do
    test "the first Gregorian day is the next day of the era, in every reform calendar" do
      reforms = reforms()
      assert length(reforms) == 33

      for {calendar, last_julian, first_gregorian} <- reforms do
        assert Date.diff(first_gregorian, last_julian) == 1, inspect(calendar)

        assert {count, 1} = Date.day_of_era(last_julian)

        assert Date.day_of_era(first_gregorian) == {count + 1, 1},
               "#{inspect(last_julian)} then #{inspect(first_gregorian)}"
      end
    end

    test "every day about the reform is counted from 1 January AD 1 of the calendar" do
      for {calendar, last_julian, _first_gregorian} <- reforms() do
        first_day = Date.new!(1, 1, 1, calendar)

        for offset <- [-800, -366, -40, -1, 0, 1, 2, 40, 366, 800, 40_000] do
          date = Date.add(last_julian, offset)

          assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
        end

        today = Date.convert!(~D[2026-06-15], calendar)
        assert Date.day_of_era(today) == counted(today, first_day)
      end
    end

    # Julian Day Numbers: 2,361,222 - 1,721,424 + 1.
    test "14 September 1752 in England is the 639,799th day of the era" do
      assert Date.to_gregorian_days(~D[1752-09-14]) - Date.to_gregorian_days(~D[0000-12-30]) + 1 ==
               639_799

      assert England.day_of_era(1752, 9, 2) == {639_798, 1}
      assert England.day_of_era(1752, 9, 14) == {639_799, 1}
      assert Date.day_of_era(~D[1752-09-14 Calendrical.Reform.England]) == {639_799, 1}
    end

    test "Sweden's count runs on through 1700, 1712 and 1753" do
      first_day = Date.new!(1, 1, 1, Sweden)

      for {before, later} <- [
            {~D[1700-02-28 Calendrical.Reform.Sweden], ~D[1700-03-01 Calendrical.Reform.Sweden]},
            {~D[1712-02-30 Calendrical.Reform.Sweden], ~D[1712-03-01 Calendrical.Reform.Sweden]},
            {~D[1753-02-17 Calendrical.Reform.Sweden], ~D[1753-03-01 Calendrical.Reform.Sweden]}
          ] do
        assert Date.diff(later, before) == 1
        assert Date.day_of_era(before) == counted(before, first_day)
        assert Date.day_of_era(later) == counted(later, first_day)
      end
    end
  end

  describe "a change of the day the year begins on" do
    # England's year began on 25 March from 1155 to 1751. 24 March of the
    # year labelled 1750 is the day before 25 March 1751.
    test "England's count runs on through 1155 and 1751" do
      first_day = Date.new!(1, 1, 1, England)

      for {before, later} <- [
            {~D[1155-03-24 Calendrical.Reform.England],
             ~D[1155-03-25 Calendrical.Reform.England]},
            {~D[1750-03-24 Calendrical.Reform.England],
             ~D[1751-03-25 Calendrical.Reform.England]},
            {~D[1752-09-02 Calendrical.Reform.England], ~D[1752-09-14 Calendrical.Reform.England]}
          ] do
        assert Date.diff(later, before) == 1
        assert {count, 1} = Date.day_of_era(before)
        assert Date.day_of_era(later) == {count + 1, 1}
        assert Date.day_of_era(before) == counted(before, first_day)
        assert Date.day_of_era(later) == counted(later, first_day)
      end
    end

    test "every day of England's four calendars is counted from 1 January AD 1" do
      first_day = Date.new!(1, 1, 1, England)

      for iso <-
            [~D[0001-06-15], ~D[1100-06-15], ~D[1155-04-05], ~D[1400-02-10], ~D[1700-12-25]] ++
              [~D[1751-06-15], ~D[1752-01-10], ~D[1752-09-13], ~D[1752-09-14], ~D[2026-06-15]] do
        date = Date.convert!(iso, England)

        assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
        assert Date.year_of_era(date) |> elem(1) == 1
      end
    end

    # Where a year reckoned from 25 March is the first calendar, the common
    # era begins on 25 March AD 1, and the later calendars keep that count.
    test "the count is the first calendar's where it begins the era" do
      first_day = Date.new!(1, 3, 25, LadyDayFirst)

      assert Date.day_of_era(first_day) == {1, 1}
      assert Date.day_of_era(Date.add(first_day, -1)) == {1, 0}

      for date <- [
            ~D[1599-12-31 Calendrical.CompositeEraTest.LadyDayFirst],
            ~D[1600-01-01 Calendrical.CompositeEraTest.LadyDayFirst],
            ~D[1752-09-02 Calendrical.CompositeEraTest.LadyDayFirst],
            ~D[1752-09-14 Calendrical.CompositeEraTest.LadyDayFirst],
            ~D[2026-06-15 Calendrical.CompositeEraTest.LadyDayFirst]
          ] do
        assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
      end
    end
  end

  describe "the years before the common era" do
    test "are counted back from 31 December 1 BC in a reform calendar" do
      assert England.day_of_era(1, 1, 1) == {1, 1}
      assert England.day_of_era(-1, 12, 31) == {1, 0}
      assert England.day_of_era(-1, 12, 30) == {2, 0}
      assert England.day_of_era(-1, 1, 1) == {366, 0}
    end

    # The days of an era counted back from its last are counted as the
    # latest calendar it runs through counts them: from 24 March AD 1, the
    # day before the first of a year reckoned from 25 March, and not from 31
    # December 1 BC as the Julian calendar alone counts them.
    test "are counted back through a change of calendar from the last day of the era" do
      first_day = Date.new!(1, 3, 25, BeforeCommonEra)
      last_before = Date.new!(-100, 3, 24, BeforeCommonEra)
      first_after = Date.new!(-100, 3, 25, BeforeCommonEra)

      assert Date.diff(first_after, last_before) == 1
      assert {count, 0} = Date.day_of_era(last_before)
      assert Date.day_of_era(first_after) == {count - 1, 0}

      # The common era, which begins on 25 March AD 1, runs on through the
      # change of AD 200.
      last_of_199 = Date.new!(199, 12, 31, BeforeCommonEra)
      first_of_200 = Date.new!(200, 1, 1, BeforeCommonEra)

      assert Date.diff(first_of_200, last_of_199) == 1
      assert {count, 1} = Date.day_of_era(last_of_199)
      assert Date.day_of_era(first_of_200) == {count + 1, 1}

      for date <- [
            last_before,
            first_after,
            Date.new!(-150, 6, 1, BeforeCommonEra),
            Date.new!(-2, 12, 31, BeforeCommonEra),
            Date.add(first_day, -1),
            first_day,
            Date.new!(100, 6, 15, BeforeCommonEra),
            last_of_199,
            first_of_200,
            Date.new!(1800, 6, 15, BeforeCommonEra)
          ] do
        assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
      end
    end
  end

  describe "the years before the common era, through three changes of calendar" do
    # The last of the four calendars is in effect when the era ends, so
    # every day before the common era is counted back from 24 March AD 1,
    # in the first calendar and in the third, whose own counts are back from
    # 31 December 1 BC.
    test "are counted back from the era's last day in the latest calendar" do
      first_day = Date.new!(1, 3, 25, ThriceBeforeCommonEra)

      assert Date.day_of_era(first_day) == {1, 1}
      assert Date.day_of_era(Date.add(first_day, -1)) == {1, 0}

      for {before, later} <- [
            {Date.new!(-300, 3, 24, ThriceBeforeCommonEra),
             Date.new!(-300, 3, 25, ThriceBeforeCommonEra)},
            {Date.new!(-201, 12, 31, ThriceBeforeCommonEra),
             Date.new!(-200, 1, 1, ThriceBeforeCommonEra)},
            {Date.new!(-100, 3, 24, ThriceBeforeCommonEra),
             Date.new!(-100, 3, 25, ThriceBeforeCommonEra)}
          ] do
        assert Date.diff(later, before) == 1
        assert {count, 0} = Date.day_of_era(before)
        assert Date.day_of_era(later) == {count - 1, 0}
      end

      for date <- [
            Date.new!(-400, 6, 1, ThriceBeforeCommonEra),
            Date.new!(-300, 3, 24, ThriceBeforeCommonEra),
            Date.new!(-300, 3, 25, ThriceBeforeCommonEra),
            Date.new!(-250, 6, 1, ThriceBeforeCommonEra),
            Date.new!(-201, 12, 31, ThriceBeforeCommonEra),
            Date.new!(-200, 1, 1, ThriceBeforeCommonEra),
            Date.new!(-150, 6, 1, ThriceBeforeCommonEra),
            Date.new!(-100, 3, 24, ThriceBeforeCommonEra),
            Date.new!(-100, 3, 25, ThriceBeforeCommonEra),
            Date.new!(-50, 6, 1, ThriceBeforeCommonEra),
            Date.new!(1800, 6, 15, ThriceBeforeCommonEra)
          ] do
        assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
      end
    end
  end

  describe "a change of calendar where one era ends and another begins" do
    test "leaves each era counted from its own end" do
      assert AtTheEra.calendar_for_date(1, 1, 1) == Calendrical.Julian.Jan1
      assert AtTheEra.calendar_for_date(-1, 12, 31) == Calendrical.Julian

      assert AtTheEra.day_of_era(1, 1, 1) == {1, 1}
      assert AtTheEra.day_of_era(1, 1, 2) == {2, 1}
      assert AtTheEra.day_of_era(-1, 12, 31) == {1, 0}
      assert AtTheEra.day_of_era(-1, 12, 30) == {2, 0}
    end
  end

  describe "a change of calendar on the second day of the common era" do
    # The era's first day is the last day of its segment: the day before it
    # is a day of another era, and the day after it of another calendar.
    test "leaves the era's first day its first" do
      first_day = Date.new!(1, 1, 1, OnTheSecondDay)

      assert OnTheSecondDay.calendar_for_date(1, 1, 1) == Calendrical.Julian
      assert OnTheSecondDay.calendar_for_date(1, 1, 2) == Calendrical.Julian.Jan1
      assert Date.day_of_era(first_day) == {1, 1}

      for days <- -3..3 do
        date = Date.add(first_day, days)
        assert Date.day_of_era(date) == counted(date, first_day), inspect(date)
      end
    end
  end

  describe "calendars that name their eras from different CLDR calendars" do
    # Era 1 of the Coptic calendar and era 1 of the Julian are two eras,
    # though numbered alike, so the common era is counted from its own
    # first day, 1 January AD 1 in the Julian calendar, and not on from the
    # Coptic calendar's count.
    test "do not share an era of the same number" do
      assert Calendrical.Coptic.era_calendar_type() == :coptic
      assert Calendrical.Julian.era_calendar_type() == :gregorian

      last_coptic = Date.convert!(~D[0399-12-31 Calendrical.Julian], CopticThenJulian)
      first_julian = ~D[0400-01-01 Calendrical.CompositeEraTest.CopticThenJulian]
      later = ~D[0500-06-01 Calendrical.CompositeEraTest.CopticThenJulian]

      assert CopticThenJulian.calendar_for_date(last_coptic) == Calendrical.Coptic
      assert {_day, 1} = Date.day_of_era(last_coptic)

      assert Date.day_of_era(last_coptic) ==
               {Date.diff(last_coptic, Date.new!(1, 1, 1, Calendrical.Coptic)) + 1, 1}

      for date <- [first_julian, later] do
        assert Date.day_of_era(date) ==
                 {Date.diff(date, Date.new!(1, 1, 1, Calendrical.Julian)) + 1, 1},
               inspect(date)
      end
    end

    # The Coptic calendar's one era is not the Julian calendar's, so each
    # counts its own; the Julian and Gregorian calendars share the common
    # era, which runs on through 1875.
    test "each count their own, and those that share an era count on" do
      coptic = Date.new!(-400, 1, 1, Egypt)
      assert Egypt.calendar_for_date(coptic) == Calendrical.Coptic
      assert Date.day_of_era(coptic) == Calendrical.Coptic.day_of_era(-400, 1, 1)

      first_day = Date.new!(1, 1, 1, Egypt)
      assert Date.day_of_era(first_day) == {1, 1}

      before = Date.convert!(~D[1875-08-31], Egypt)
      later = Date.convert!(~D[1875-09-01], Egypt)

      assert Egypt.calendar_for_date(before) == Calendrical.Julian
      assert Egypt.calendar_for_date(later) == Calendrical.Gregorian
      assert Date.day_of_era(before) == counted(before, first_day)
      assert Date.day_of_era(later) == counted(later, first_day)
    end
  end

  describe "Japan's eras" do
    # CLDR's Japanese eras begin Meiji on 23 October 1868, Heisei on 8
    # January 1989 and Reiwa on 1 May 2019. Meiji runs through the adoption
    # of the Gregorian calendar on 1 January 1873, the day after the second
    # of the twelfth lunisolar month.
    test "are counted from their first days, through the change of 1873" do
      meiji = ~D[1868-10-23]
      last_lunisolar = Date.convert!(~D[1872-12-31], Japan)
      first_gregorian = ~D[1873-01-01 Calendrical.Reform.Japan]

      assert {last_lunisolar.month, last_lunisolar.day} == {12, 2}

      assert Date.day_of_era(last_lunisolar) == {Date.diff(~D[1872-12-31], meiji) + 1, 232}
      assert Date.day_of_era(first_gregorian) == {Date.diff(~D[1873-01-01], meiji) + 1, 232}

      assert Japan.day_of_era(2019, 4, 30) == {Date.diff(~D[2019-04-30], ~D[1989-01-08]) + 1, 235}
      assert Japan.day_of_era(2019, 5, 1) == {1, 236}
    end
  end

  describe "day_of_era/3 and year_of_era/3" do
    test "name the same era on every day about a change of calendar" do
      for {calendar, last_julian, _first_gregorian} <- reforms(), offset <- -3..3 do
        date = Date.add(last_julian, offset)
        {_day, era} = Date.day_of_era(date)
        {_year, year_era} = Date.year_of_era(date)

        assert era == year_era, "#{inspect(calendar)} on #{inspect(date)}"
      end
    end

    test "a date the calendar does not have is an error" do
      assert England.day_of_era(1752, 9, 5) == {:error, :invalid_date}
      assert Sweden.day_of_era(1753, 2, 20) == {:error, :invalid_date}
    end

    # A composite refuses a date it does not have before its member
    # calendar is asked, so a member's own refusal is reached only here: it
    # is the answer, unchanged.
    test "a member calendar's refusal of a date is the answer" do
      segments = Calendrical.Composite.Config.segments(England.__config__())

      assert Calendrical.Composite.Era.day_of_era(segments, 3, 2023, 2, 30) ==
               {:error, :invalid_date}
    end
  end
end
