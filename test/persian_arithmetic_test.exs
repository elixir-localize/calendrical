defmodule Calendrical.PersianArithmeticTest do
  @moduledoc """
  The Persian calendar outside the years whose new year is computed from
  the equinox (Persian 380 to 2378) follows ICU's arithmetic Persian
  calendar, and joins the astronomical years without a gap or overlap.

  The oracles are ICU4C's: the day counts of `persianTestCases1` in
  `test/intltest/incaltst.cpp` (from ICU4X, by Reingold's fixed days, so
  ISO days are fixed days plus 365), and ICU's leap-year rule from
  `PersianCalendar::isLeapYear`, a different formula from the year
  starts the calendar is built on. ICU's rule takes the remainder with
  C's `%`, which calls every year before 0 leap against ICU's own year
  starts; the floored remainder is used here.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Persian

  @icu_test_cases [
    {656_786, 1178, 1, 1},
    {664_224, 1198, 5, 10},
    {671_401, 1218, 1, 7},
    {694_799, 1282, 1, 29},
    {702_806, 1304, 1, 1},
    {704_424, 1308, 6, 3},
    {708_842, 1320, 7, 7},
    {709_409, 1322, 1, 29},
    {709_580, 1322, 7, 14},
    {727_274, 1370, 12, 27},
    {728_714, 1374, 12, 6},
    {739_330, 1403, 12, 30},
    {739_331, 1404, 1, 1},
    {744_313, 1417, 8, 19},
    {763_436, 1469, 12, 30},
    {763_437, 1470, 1, 1},
    {764_652, 1473, 4, 28},
    {775_123, 1501, 12, 29},
    {775_488, 1502, 12, 29},
    {775_487, 1502, 12, 28},
    {775_489, 1503, 1, 1},
    {775_490, 1503, 1, 2},
    {1_317_873, 2987, 12, 29},
    {1_317_874, 2988, 1, 1},
    {1_317_875, 2988, 1, 2}
  ]

  # ICU's years after 2378 that its 33-year cycle makes leap and are common.
  @icu_common_years [
    2389,
    2393,
    2422,
    2426,
    2455,
    2459,
    2488,
    2492,
    2521,
    2525,
    2554,
    2558,
    2587,
    2591,
    2620,
    2624,
    2653,
    2657,
    2686,
    2690,
    2719,
    2723,
    2748,
    2752,
    2756,
    2781,
    2785,
    2789,
    2818,
    2822,
    2847,
    2851,
    2855,
    2880,
    2884,
    2888,
    2913,
    2917,
    2921,
    2946,
    2950,
    2954,
    2979,
    2983,
    2987
  ]

  defp icu_leap_year?(year) do
    cond do
      year in @icu_common_years -> false
      (year - 1) in @icu_common_years -> true
      true -> Integer.mod(25 * year + 11, 33) < 8
    end
  end

  test "ICU's test dates, both ways" do
    for {fixed_days, year, month, day} <- @icu_test_cases do
      assert Persian.date_from_iso_days(fixed_days + 365) == {year, month, day}
      assert Persian.date_to_iso_days(year, month, day) == fixed_days + 365
    end
  end

  test "the arithmetic years are leap as ICU has them" do
    for year <- Enum.concat(-1000..379, 2379..3100) do
      assert Persian.leap_year?(year) == icu_leap_year?(year), "year #{year}"
      assert Persian.days_in_year(year) == if(icu_leap_year?(year), do: 366, else: 365)
    end
  end

  test "year 1 begins on 21 March 622 and the year before it is year 0" do
    assert Date.convert(~D[0622-03-21], Persian) == {:ok, Date.new!(1, 1, 1, Persian)}
    assert Date.convert(~D[0622-03-20], Persian) == {:ok, Date.new!(0, 12, 29, Persian)}
    assert Date.convert(Date.new!(0, 1, 1, Persian), Calendar.ISO) == {:ok, ~D[0621-03-21]}
  end

  test "every day across both joins follows the day before" do
    for {first, last} <- [{~D[0999-01-01], ~D[1003-12-31]}, {~D[2997-01-01], ~D[3002-12-31]}] do
      days = Date.to_gregorian_days(first)..Date.to_gregorian_days(last)

      days
      |> Enum.map(&{&1, Persian.date_from_iso_days(&1)})
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [{iso_days, date}, {_next_iso_days, next}] ->
        assert next == next_date(date), "after #{inspect(date)}"
        {year, month, day} = date
        assert Persian.date_to_iso_days(year, month, day) == iso_days
        assert Persian.valid_date?(year, month, day)
      end)
    end
  end

  test "years far from the astronomical ones begin the day after the year before ends" do
    for year <- Enum.concat(-5000..-4900, 9900..10_000) do
      last_day = Persian.days_in_month(year, 12)

      assert Persian.date_to_iso_days(year, 12, last_day) + 1 ==
               Persian.date_to_iso_days(year + 1, 1, 1)

      assert Persian.date_from_iso_days(Persian.date_to_iso_days(year, 1, 1)) == {year, 1, 1}
    end
  end

  test "a date outside the astronomical years converts and parses" do
    assert {:ok, %Date{year: 279, calendar: Persian}} = Date.convert(~D[0900-06-01], Persian)
    assert {:ok, %Date{year: 2879, calendar: Persian}} = Date.convert(~D[3500-06-01], Persian)

    assert {:ok, ~D[0900-06-01]} =
             Date.convert(~D[0900-06-01], Persian) |> elem(1) |> Date.convert(Calendar.ISO)

    assert {:ok, %Date{calendar: Persian}} = Localize.Date.parse("0001-001", calendar: Persian)
  end

  defp next_date({year, month, day}) do
    cond do
      day < Persian.days_in_month(year, month) -> {year, month, day + 1}
      month < 12 -> {year, month + 1, 1}
      true -> {year + 1, 1, 1}
    end
  end
end
