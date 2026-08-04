defmodule Calendrical.Reform.SwedenTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Reform.Sweden
  doctest Calendrical.Reform.Sweden.Transitional

  alias Calendrical.{Gregorian, Julian}
  alias Calendrical.Reform.Sweden

  describe "1700 — the dropped leap day" do
    test "there is no 29 February 1700" do
      refute Sweden.valid_date?(1700, 2, 29)
    end

    test "28 February 1700 is followed by 1 March 1700" do
      day_before = ~D[1700-02-28 Calendrical.Reform.Sweden]
      assert Date.shift(day_before, day: 1) == ~D[1700-03-01 Calendrical.Reform.Sweden]
    end

    test "1 March 1700 is the physical day the Julian calendar calls 29 February 1700" do
      assert Date.convert!(~D[1700-03-01 Calendrical.Reform.Sweden], Julian) ==
               ~D[1700-02-29 Calendrical.Julian]
    end
  end

  describe "1712 — the 30 February" do
    test "30 February 1712 is a valid date" do
      assert Sweden.valid_date?(1712, 2, 30)
    end

    test "February 1712 has 30 days and 1712 has 367 days" do
      assert Sweden.days_in_month(1712, 2) == 30
      assert Sweden.days_in_year(1712) == 367
    end

    test "29 February 1712 is followed by 30 February then 1 March" do
      feb_29 = ~D[1712-02-29 Calendrical.Reform.Sweden]
      feb_30 = Date.shift(feb_29, day: 1)
      assert feb_30 == ~D[1712-02-30 Calendrical.Reform.Sweden]
      assert Date.shift(feb_30, day: 1) == ~D[1712-03-01 Calendrical.Reform.Sweden]
    end

    test "30 February 1712 is the physical day the Julian calendar calls 29 February 1712" do
      assert Date.convert!(~D[1712-02-30 Calendrical.Reform.Sweden], Julian) ==
               ~D[1712-02-29 Calendrical.Julian]
    end
  end

  describe "1753 — the Gregorian adoption" do
    test "11 days are missing across the transition" do
      day_before = ~D[1753-02-17 Calendrical.Reform.Sweden]
      assert Date.shift(day_before, day: 1) == ~D[1753-03-01 Calendrical.Reform.Sweden]
    end

    test "18-28 February 1753 are not valid dates" do
      for d <- 18..28 do
        refute Sweden.valid_date?(1753, 2, d), "expected #{d} Feb 1753 to be invalid"
      end
    end

    test "after 1753 the Gregorian leap rule applies" do
      # 1800 is not a Gregorian leap year
      refute Sweden.valid_date?(1800, 2, 29)
    end
  end

  describe "round-trips across every segment" do
    test "Sweden -> Gregorian -> Sweden is stable in each era" do
      for date <- [
            ~D[1699-06-15 Calendrical.Reform.Sweden],
            ~D[1705-06-15 Calendrical.Reform.Sweden],
            ~D[1730-06-15 Calendrical.Reform.Sweden],
            ~D[1800-06-15 Calendrical.Reform.Sweden]
          ] do
        assert date |> Date.convert!(Gregorian) |> Date.convert!(Sweden) == date
      end
    end
  end
end
