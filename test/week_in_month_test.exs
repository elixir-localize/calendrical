defmodule Calendrical.WeekInMonth.Test do
  use ExUnit.Case, async: true
  import Calendrical.Helper

  test "Week in month for gregorian dates with ISO Week configuration" do
    assert Calendrical.week_of_month(~D[2019-01-01]) == {1, 1}

    # The Gregorian calendar has an ISO Week week configuration
    # So this gregorian date is actually in the next year, first month
    assert Calendrical.week_of_month(~D[2018-12-31]) == {1, 1}
    assert Calendrical.week_of_month(~D[2019-12-30]) == {1, 1}
    assert Calendrical.week_of_month(~D[2019-12-28]) == {12, 4}
  end

  test "Week in month for gregorian dates with first week starting on January 1st" do
    assert Calendrical.week_of_month(date(2019, 01, 01, Calendrical.BasicWeek)) == {1, 1}
    assert Calendrical.week_of_month(date(2018, 12, 31, Calendrical.BasicWeek)) == {12, 5}
    assert Calendrical.week_of_month(date(2019, 12, 30, Calendrical.BasicWeek)) == {12, 5}
    assert Calendrical.week_of_month(date(2019, 12, 28, Calendrical.BasicWeek)) == {12, 4}

    assert Calendrical.week_of_month(date(2019, 04, 01, Calendrical.BasicWeek)) == {4, 1}
    assert Calendrical.week_of_month(date(2019, 04, 07, Calendrical.BasicWeek)) == {4, 1}
    assert Calendrical.week_of_month(date(2019, 04, 08, Calendrical.BasicWeek)) == {4, 2}
  end

  test "Week 53 of a long year belongs to month 12, never month 13" do
    # Gregorian's ISO-week configuration: 2017 and 2023 are long
    # years. Week 53 carries the leap week appended to month 12 —
    # the quarter arithmetic must not produce month 13.
    assert Calendrical.week_of_year(~D[2017-12-31]) == {2017, 53}
    assert Calendrical.week_of_month(~D[2017-12-28]) == {12, 5}
    assert Calendrical.week_of_month(~D[2017-12-31]) == {12, 5}
    assert Calendrical.week_of_month(~D[2023-12-31]) == {12, 5}

    # The week-calendar path agrees: ISO year 2015 is a long year and
    # ISOWeek has the default 4, 5, 4 configuration, so month 12
    # spans weeks 49 to 53.
    assert Calendrical.week_of_month(date(2015, 53, 1, Calendrical.ISOWeek)) == {12, 5}
  end

  test "Week in month for ISOWeek which has a 4, 5, 4 configuration" do
    assert Calendrical.week_of_month(date(2019, 01, 1, Calendrical.ISOWeek)) == {1, 1}
    assert Calendrical.week_of_month(date(2018, 04, 1, Calendrical.ISOWeek)) == {1, 4}
    assert Calendrical.week_of_month(date(2019, 05, 1, Calendrical.ISOWeek)) == {2, 1}
    assert Calendrical.week_of_month(date(2019, 12, 1, Calendrical.ISOWeek)) == {3, 3}
    assert Calendrical.week_of_month(date(2019, 13, 1, Calendrical.ISOWeek)) == {3, 4}
    assert Calendrical.week_of_month(date(2019, 14, 1, Calendrical.ISOWeek)) == {4, 1}
  end
end
