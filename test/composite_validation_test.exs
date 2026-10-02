defmodule Calendrical.CompositeValidationTest do
  @moduledoc """
  What a composite calendar can hold: each change of calendar a date of the
  calendar that takes effect on it, on a day of its own; every calendar a
  calendar module of months that is no composite itself; and no calendar
  numbering its first year before the last year of the calendar before it.

  The facts the cases rest on are the calendars' own: 1700 is a leap year
  of the Julian calendar and not of the Gregorian; 3 September 1752 of the
  Julian calendar is 14 September of the Gregorian; the Hebrew year 5660
  began in September 1899; a year reckoned from 25 December takes the number
  of the Julian year it ends in, and one reckoned from 25 March the number
  of the Julian year it begins in.

  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Calendrical.Composite

  # A year reckoned from 1 September from 1099, then from 25 March from
  # 1200: the year 1200 runs from 1 September 1199 to 24 March 1201.
  defmodule SeptemberThenLadyDay do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1100-09-01 Calendrical.Julian.Sept1],
        ~D[1200-03-25 Calendrical.Julian.March25]
      ]
  end

  # A year reckoned from 25 December from 1099, then from 25 March from
  # 1200: the year 1200 runs from 25 December 1199 to 24 March 1201.
  defmodule ChristmasThenLadyDay do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [
        ~D[1100-12-25 Calendrical.Julian.Dec25],
        ~D[1200-03-25 Calendrical.Julian.March25]
      ]
  end

  # Christmas style gives way to Lady Day style on 25 December 1200, the
  # first day of the Christmas year 1201: the day before is in its year
  # 1200, and the Lady Day year 1200 goes on to 24 March 1201.
  defmodule LadyDayOnChristmas do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[1200-12-25 Calendrical.Julian.March25]],
      base_calendar: Calendrical.Julian.Dec25
  end

  defmodule NoCldrCalendar do
    @moduledoc false
    def valid_date?(_year, _month, _day), do: true
  end

  # A calendar module that raises for a date it does not reach.
  defmodule Unreached do
    @moduledoc false
    def cldr_calendar_type, do: :gregorian
    def calendar_base, do: :month
    def valid_date?(_year, _month, _day), do: true
    def date_to_iso_days(_year, _month, _day), do: raise(ArgumentError, "not reached")
  end

  describe "the list of changes of calendar" do
    test "is a list of dates" do
      assert Composite.new(Validation.ImproperList, calendars: [~D[1700-03-01] | :not_a_date]) ==
               {:error, :must_be_a_list_of_dates}

      assert Composite.new(Validation.NotADate, calendars: "1700-03-01") ==
               {:error, :must_be_a_list_of_dates}
    end
  end

  describe "a change of calendar on a day its calendar does not have" do
    test "is an invalid date" do
      for date <- [
            %{year: 1700, month: 13, day: 1, calendar: Calendrical.Gregorian},
            %{year: 1700, month: 2, day: 30, calendar: Calendrical.Gregorian},
            %{year: 1700, month: 2, day: 29, calendar: Calendrical.Gregorian},
            %{year: 1700, month: 2, day: 29, calendar: Calendar.ISO},
            %{year: 1700, month: 3, day: 0, calendar: Calendrical.Gregorian},
            %{year: "1700", month: 3, day: 1, calendar: Calendrical.Gregorian},
            %{year: 1700, month: 3, day: nil, calendar: Calendrical.Gregorian}
          ] do
        assert Composite.new(Validation.NoSuchDay, calendars: [date]) == {:error, :invalid_date},
               inspect(date)
      end

      refute Code.ensure_loaded?(Validation.NoSuchDay)

      # Fields that are not integers are no date, whatever the calendar says.
      assert Composite.new(Validation.NoIntegerYear,
               calendars: [%{year: "1900", month: 1, day: 1, calendar: Unreached}]
             ) == {:error, :invalid_date}
    end

    test "is a date where its calendar has the day" do
      assert {:ok, calendar} =
               Composite.new(Validation.JulianLeapDay,
                 calendars: [%{year: 1700, month: 2, day: 29, calendar: Calendrical.Julian}],
                 base_calendar: Calendrical.Gregorian
               )

      assert calendar.calendar_for_date(1700, 2, 29) == Calendrical.Julian
      assert calendar.valid_date?(1700, 2, 29)
    end
  end

  describe "a calendar that is no calendar module" do
    test "is an invalid calendar module, as a change or as the base calendar" do
      for calendar <- [nil, "Calendrical.Gregorian", :not_a_calendar, String, NoCldrCalendar] do
        date = %{year: 1700, month: 3, day: 1, calendar: calendar}

        assert {:error, %Calendrical.InvalidCalendarModuleError{module: ^calendar}} =
                 Composite.new(Validation.NoCalendar, calendars: [date])

        assert {:error, %Calendrical.InvalidCalendarModuleError{module: ^calendar}} =
                 Composite.new(Validation.NoBaseCalendar,
                   calendars: [~D[1700-03-01 Calendrical.Gregorian]],
                   base_calendar: calendar
                 )
      end
    end

    test "that raises for a date it does not reach is answered with what it raised" do
      assert {:error, %ArgumentError{message: "not reached"}} =
               Composite.new(Validation.Unreached,
                 calendars: [%{year: 1900, month: 1, day: 1, calendar: Unreached}]
               )

      refute Code.ensure_loaded?(Validation.Unreached)
    end

    test "is Calendar.ISO taken as the Gregorian calendar" do
      assert {:ok, calendar} =
               Composite.new(Validation.ISO,
                 calendars: [~D[1700-03-01]],
                 base_calendar: Calendar.ISO
               )

      assert calendar.calendar_for_date(1700, 3, 1) == Calendrical.Gregorian
      assert calendar.calendar_for_date(1600, 3, 1) == Calendrical.Gregorian
    end
  end

  describe "a calendar a composite does not count months through" do
    test "is no composite calendar" do
      assert Composite.new(Validation.Nested,
               calendars: [~D[1800-01-01 Calendrical.Reform.England]]
             ) == {:error, :must_not_be_composite_calendars}

      assert Composite.new(Validation.NestedBase,
               calendars: [~D[1800-01-01 Calendrical.Gregorian]],
               base_calendar: Calendrical.Reform.England
             ) == {:error, :must_not_be_composite_calendars}
    end

    test "is no calendar of weeks" do
      assert Composite.new(Validation.Weeks,
               calendars: [%{year: 2000, month: 1, day: 1, calendar: Calendrical.ISOWeek}],
               base_calendar: Calendrical.Gregorian
             ) == {:error, :must_not_be_week_calendars}
    end
  end

  describe "two changes of calendar on one day" do
    test "are refused" do
      assert Composite.new(Validation.SameDay,
               calendars: [
                 ~D[1752-09-14 Calendrical.Gregorian],
                 ~D[1752-09-03 Calendrical.Julian]
               ]
             ) == {:error, :must_take_effect_on_different_days}
    end
  end

  describe "the number of the year" do
    # The Hebrew year on 31 December 1899 was 5660: the Gregorian years from
    # 1900 to 5660 would carry the numbers of Hebrew years before them.
    test "must not go back at a change of calendar" do
      assert Composite.new(Validation.HebrewThenGregorian,
               calendars: [~D[1900-01-01 Calendrical.Gregorian]],
               base_calendar: Calendrical.Hebrew
             ) == {:error, :years_must_not_go_back}

      # The Christmas year 1201 began on 25 December 1200, and the Lady Day
      # year 1200 runs to 24 March 1201.
      assert Composite.new(Validation.LadyDayAfterChristmas,
               calendars: [~D[1200-12-26 Calendrical.Julian.March25]],
               base_calendar: Calendrical.Julian.Dec25
             ) == {:error, :years_must_not_go_back}
    end

    test "may stay the same through a change of calendar" do
      assert LadyDayOnChristmas.calendar_for_date(1200, 12, 24) == Calendrical.Julian.Dec25
      assert LadyDayOnChristmas.calendar_for_date(1200, 12, 25) == Calendrical.Julian.March25

      assert Date.convert!(Date.new!(1200, 12, 25, LadyDayOnChristmas), Calendrical.Julian) ==
               ~D[1200-12-25 Calendrical.Julian]
    end
  end

  describe "a change of calendar before the base calendar's year -9999" do
    test "takes effect after the base calendar, which has no first day" do
      assert {:ok, calendar} =
               Composite.new(Validation.Early,
                 calendars: [%{year: -20_000, month: 1, day: 1, calendar: Calendrical.Gregorian}]
               )

      change = Calendrical.Gregorian.date_to_iso_days(-20_000, 1, 1)

      assert calendar.calendar_for_iso_days(change - 1) == Calendrical.Julian
      assert calendar.calendar_for_iso_days(change) == Calendrical.Gregorian
      assert calendar.calendar_for_date(1700, 3, 1) == Calendrical.Gregorian
      refute calendar.valid_date?(1700, 2, 29)
    end
  end

  describe "use Calendrical.Composite" do
    test "raises for a configuration it cannot keep" do
      assert_raise ArgumentError, ~r/must not number its first year/, fn ->
        Code.compile_string("""
        defmodule Validation.CompiledHebrewThenGregorian do
          use Calendrical.Composite,
            calendars: [~D[1900-01-01 Calendrical.Gregorian]],
            base_calendar: Calendrical.Hebrew
        end
        """)
      end

      assert_raise ArgumentError, ~r/a date of its own calendar/, fn ->
        Code.compile_string("""
        defmodule Validation.CompiledNoSuchDay do
          use Calendrical.Composite,
            calendars: [%{year: 1700, month: 2, day: 29, calendar: Calendrical.Gregorian}]
        end
        """)
      end

      assert_raise Calendrical.InvalidCalendarModuleError, fn ->
        Code.compile_string("""
        defmodule Validation.CompiledNoCalendar do
          use Calendrical.Composite,
            calendars: [%{year: 1700, month: 3, day: 1, calendar: Validation.NotACalendar}]
        end
        """)
      end
    end
  end

  # Where two stretches of a year's days carry the same dates one has none
  # of its own, and the year's range runs between the dates of the other,
  # in the order of the days.
  describe "year/1" do
    test "runs between the dates that have days of their own" do
      for {calendar, year, first, last, days_in_year} <- [
            # 1 January 1155 to 24 March 1156.
            {Calendrical.Reform.England, 1155, ~D[1155-01-01], ~D[1155-12-31], 449},
            # 1 September 1699 to 31 December 1700.
            {Calendrical.Russia, 1700, ~D[1700-01-01], ~D[1700-12-31], 488},
            # 1 September 1199 to 24 March 1201.
            {SeptemberThenLadyDay, 1200, ~D[1200-01-01], ~D[1200-12-31], 571},
            # 25 December 1199 to 24 March 1201.
            {ChristmasThenLadyDay, 1200, ~D[1200-01-01], ~D[1200-12-31], 456}
          ] do
        context = "#{inspect(calendar)} #{year}"

        {range, warnings} = with_io(:stderr, fn -> calendar.year(year) end)

        assert warnings == "", context
        assert range.step == 1, context
        assert Date.convert!(range.first, Calendrical.Julian) == julian(first), context
        assert Date.convert!(range.last, Calendrical.Julian) == julian(last), context
        assert Enum.count(range) == Date.diff(julian(last), julian(first)) + 1, context
        assert calendar.days_in_year(year) == days_in_year, context
      end
    end

    test "is every day of a year whose days all have dates of their own" do
      # England's 1751 ran from 25 March to 31 December, and 1752 lost the
      # eleven days from 3 to 13 September.
      assert %Date.Range{first: first, last: last} = Calendrical.Reform.England.year(1751)
      assert Date.convert!(first, Calendrical.Julian) == ~D[1751-03-25 Calendrical.Julian]
      assert Date.convert!(last, Calendrical.Julian) == ~D[1751-12-31 Calendrical.Julian]

      assert Enum.count(Calendrical.Reform.England.year(1752)) == 355
      assert Enum.count(SeptemberThenLadyDay.year(1100)) == 366
    end
  end

  defp julian(%Date{year: year, month: month, day: day}) do
    Date.new!(year, month, day, Calendrical.Julian)
  end
end
