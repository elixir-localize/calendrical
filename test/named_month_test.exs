defmodule Calendrical.NamedMonthTest do
  @moduledoc """
  The days of a named month in a year, which every calendar answers
  (`named_month/2`).

  A month carries the name its own dates are of. `Calendrical.named_month/3`
  named a month by its number, which is the month's name only where a
  calendar numbers its months as CLDR names them: the ninth month of a
  Hebrew year of twelve is Sivan, CLDR's tenth, and was answered with the
  days of its tenth, Tamuz.

  The months are known apart from the library. CLDR numbers the Hebrew
  months from Tishri, 1, with Adar I the sixth and Adar the seventh in
  every year, so Sivan is its tenth and has 30 days, the ninth month of a
  year of twelve and the tenth of a year with Adar I. A Lady Day year
  begins on 25 March, so its March is its first seven days and its last
  twenty-four. The Chinese year that began in January 2023 has a leap
  second month.

  """

  use ExUnit.Case, async: true

  describe "named_month/2" do
    test "is the month's days where a calendar numbers its months as they are named" do
      assert Calendrical.Gregorian.named_month(2026, 5) ==
               [
                 Date.range(
                   ~D[2026-05-01 Calendrical.Gregorian],
                   ~D[2026-05-31 Calendrical.Gregorian]
                 )
               ]

      assert Calendrical.Gregorian.named_month(2026, 14) == []
    end

    test "is the days of the month whose dates are of the name, in the Hebrew calendar" do
      sivan = 10

      assert Calendrical.Hebrew.named_month(5785, sivan) ==
               [Date.range(~D[5785-09-01 Calendrical.Hebrew], ~D[5785-09-30 Calendrical.Hebrew])]

      assert Calendrical.Hebrew.named_month(5787, sivan) ==
               [Date.range(~D[5787-10-01 Calendrical.Hebrew], ~D[5787-10-30 Calendrical.Hebrew])]
    end

    test "is each stretch of a month a year begins within" do
      assert Calendrical.Julian.March25.named_month(1750, 3) == [
               Date.range(
                 ~D[1750-01-01 Calendrical.Julian.March25],
                 ~D[1750-01-07 Calendrical.Julian.March25]
               ),
               Date.range(
                 ~D[1750-13-01 Calendrical.Julian.March25],
                 ~D[1750-13-24 Calendrical.Julian.March25]
               )
             ]
    end

    test "is a month and the leap month after it, in a lunisolar year that has one" do
      assert [second, leap_second] = Calendrical.Chinese.named_month(4660, 2)

      assert second.first == ~D[4660-02-01 Calendrical.Chinese]
      assert leap_second.first == ~D[4660-03-01 Calendrical.Chinese]
    end

    test "is the weeks of the month, in a calendar of weeks" do
      assert Calendrical.ISOWeek.named_month(2026, 3) == [Calendrical.ISOWeek.month(2026, 3)]
    end
  end

  describe "Calendrical.named_month/3" do
    test "is the calendar's own answer, and the Gregorian calendar's for Calendar.ISO" do
      assert Calendrical.named_month(5785, 10, Calendrical.Hebrew) ==
               Calendrical.Hebrew.named_month(5785, 10)

      assert Calendrical.named_month(2026, 5, Calendar.ISO) ==
               Calendrical.Gregorian.named_month(2026, 5)
    end
  end
end
