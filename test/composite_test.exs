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
end
