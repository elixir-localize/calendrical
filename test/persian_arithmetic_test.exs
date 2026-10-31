defmodule Calendrical.PersianArithmeticTest do
  @moduledoc """
  The Persian calendar begins every year from the equinox, computed by
  Astro for the 50,000 years either side of 2000. ICU's Persian calendar
  is arithmetic, by a 33-year cycle, and the two agree on most years near
  the present.

  The oracle is ICU4C's: the day counts of `persianTestCases1` in
  `test/intltest/incaltst.cpp` (from ICU4X, by Reingold's fixed days, so
  ISO days are fixed days plus 365).

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

  # The March 2091 equinox falls within seconds of true noon in Tehran, so
  # seconds of ΔT decide whether 1470 begins on 20 or 21 March: ICU begins
  # it on the 21st, and Astro's equinox, just before noon, on the 20th.
  @decided_by_seconds [{763_436, 1469, 12, 30}, {763_437, 1470, 1, 1}]

  test "ICU's test dates, both ways" do
    for {fixed_days, year, month, day} = test_case <- @icu_test_cases,
        test_case not in @decided_by_seconds do
      assert Persian.date_from_iso_days(fixed_days + 365) == {year, month, day}
      assert Persian.date_to_iso_days(year, month, day) == fixed_days + 365
    end

    assert Persian.date_from_iso_days(763_436 + 365) == {1470, 1, 1}
    assert Persian.date_from_iso_days(763_437 + 365) == {1470, 1, 2}
  end

  test "every year has 365 or 366 days" do
    for year <- -1000..3100 do
      assert Persian.days_in_year(year) in [365, 366], "year #{year}"
      assert Persian.leap_year?(year) == (Persian.days_in_year(year) == 366)
    end
  end

  test "year 1 begins on 22 March 622 and the year before it is year 0" do
    assert Date.convert(~D[0622-03-22], Persian) == {:ok, Date.new!(1, 1, 1, Persian)}
    assert Date.convert(~D[0622-03-21], Persian) == {:ok, Date.new!(0, 12, 30, Persian)}
    assert Date.convert(Date.new!(0, 1, 1, Persian), Calendar.ISO) == {:ok, ~D[0621-03-21]}
  end

  test "every day follows the day before, in the twentieth and twenty-first centuries" do
    for {first, last} <- [{~D[1898-01-01], ~D[1902-12-31]}, {~D[2098-01-01], ~D[2103-12-31]}] do
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

  test "years far from the present begin the day after the year before ends" do
    for year <- Enum.concat(-5000..-4900, 9900..10_000) do
      last_day = Persian.days_in_month(year, 12)

      assert Persian.date_to_iso_days(year, 12, last_day) + 1 ==
               Persian.date_to_iso_days(year + 1, 1, 1)

      assert Persian.date_from_iso_days(Persian.date_to_iso_days(year, 1, 1)) == {year, 1, 1}
    end
  end

  # Near the ends of Astro's years, ΔT puts the equinox in universal time
  # months from March: year 51,378 begins on 2 December 51,998.
  test "every day round-trips near the first and last years Astro answers for" do
    for year <- Enum.concat(-48_621..-48_617, 51_374..51_378),
        day <- 0..(Persian.days_in_year(year) - 1) do
      iso_days = Persian.date_to_iso_days(year, 1, 1) + day
      {^year, month, day_of_month} = Persian.date_from_iso_days(iso_days)
      assert Persian.date_to_iso_days(year, month, day_of_month) == iso_days
    end

    assert Persian.new_year_gregorian(51_999) == {:ok, Date.new!(51_998, 12, 2)}
  end

  test "a date far from the present converts and parses" do
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
