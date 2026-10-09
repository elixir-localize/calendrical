defmodule Calendrical.CompositeTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Composite

  describe "Russia — February 1918 transition" do
    test "31 January 1918 is followed by 14 February 1918" do
      day_before = ~D[1918-01-31 Calendrical.Russia]
      day_after = Date.shift(day_before, day: 1)
      assert day_after == ~D[1918-02-14 Calendrical.Russia]
    end

    test "13 days are missing in February 1918" do
      for d <- 1..13 do
        refute Calendrical.Russia.valid_date?(1918, 2, d), "expected #{d} Feb 1918 to be invalid"
      end
    end
  end

  describe "Calendrical.Composite.new/2" do
    test "creates a composite calendar at runtime" do
      # Binding the module from the return value keeps the compiler
      # from flagging remote calls to a module that only exists once
      # this test has run.
      assert {:ok, denmark} =
               Calendrical.Composite.new(MyTest.Composite.Denmark,
                 calendars: [~D[1700-03-01 Calendrical.Gregorian]]
               )

      assert denmark == MyTest.Composite.Denmark

      # Should be in effect: Julian before 1700-03-01, Gregorian after.
      assert denmark.valid_date?(1700, 3, 1)
      assert denmark.valid_date?(1700, 1, 1)
    end

    test "returns :module_already_exists if the module is already loaded" do
      assert {:module_already_exists, Calendrical.Russia} =
               Calendrical.Composite.new(Calendrical.Russia, calendars: [~D[1900-01-01]])
    end
  end

  describe "a composite calendar's configuration" do
    # Julian 25 March 1155 is 1 April in the Gregorian calendar, seven days
    # on, and Julian 25 March 1751 is 5 April, eleven days on.
    test "is its changes of calendar: the first day of each, and its calendar" do
      assert [
               {_first, -9999, 1, 1, Calendrical.Julian},
               {lady_day, 1155, 1, 1, Calendrical.Julian.March25},
               {january, 1751, 3, 25, Calendrical.Julian.Jan1},
               {gregorian, 1752, 9, 14, Calendrical.Gregorian}
             ] = Calendrical.Reform.England.__config__()

      assert lady_day == Date.to_gregorian_days(~D[1155-04-01])
      assert january == Date.to_gregorian_days(~D[1751-04-05])
      assert gregorian == Date.to_gregorian_days(~D[1752-09-14])
    end

    test "is the same in a calendar created at runtime" do
      {:ok, calendar} =
        Calendrical.Composite.new(MyTest.Composite.Configured,
          calendars: [~D[1700-03-01 Calendrical.Gregorian]]
        )

      assert [
               {_first, -9999, 1, 1, Calendrical.Julian},
               {gregorian, 1700, 3, 1, Calendrical.Gregorian}
             ] = calendar.__config__()

      assert gregorian == Date.to_gregorian_days(~D[1700-03-01])
    end
  end
end
