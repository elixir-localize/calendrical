defmodule Calendrical.JulianVariantsTest do
  @moduledoc """
  Tests for the Julian year-shift variants (`March1`, `March25`,
  `Sept1`, `Dec25`).

  Each variant relabels the Julian year to begin on a historical
  new-year day, using the beginning-year convention: the year
  label is the Julian year that contains the year's first day.

  """

  use ExUnit.Case, async: true

  @variants [
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25
  ]

  describe "year boundaries (beginning-year convention)" do
    test "March1: the year changes on Julian March 1" do
      assert Date.convert(~D[2024-03-13], Calendrical.Julian.March1) ==
               {:ok, ~D[2023-02-29 Calendrical.Julian.March1]}

      assert Date.convert(~D[2024-03-14], Calendrical.Julian.March1) ==
               {:ok, ~D[2024-03-01 Calendrical.Julian.March1]}
    end

    test "March25: the year changes on Julian March 25" do
      assert Date.convert(~D[2024-04-06], Calendrical.Julian.March25) ==
               {:ok, ~D[2023-03-24 Calendrical.Julian.March25]}

      assert Date.convert(~D[2024-04-07], Calendrical.Julian.March25) ==
               {:ok, ~D[2024-03-25 Calendrical.Julian.March25]}
    end

    test "Sept1: the year changes on Julian September 1" do
      assert Date.convert(~D[2024-09-13], Calendrical.Julian.Sept1) ==
               {:ok, ~D[2023-08-31 Calendrical.Julian.Sept1]}

      assert Date.convert(~D[2024-09-14], Calendrical.Julian.Sept1) ==
               {:ok, ~D[2024-09-01 Calendrical.Julian.Sept1]}
    end

    test "Dec25: the year changes on Julian December 25" do
      assert Date.convert(~D[2025-01-06], Calendrical.Julian.Dec25) ==
               {:ok, ~D[2023-12-24 Calendrical.Julian.Dec25]}

      assert Date.convert(~D[2025-01-07], Calendrical.Julian.Dec25) ==
               {:ok, ~D[2024-12-25 Calendrical.Julian.Dec25]}
    end
  end

  describe "round-trips" do
    test "every variant round-trips through a full year of dates" do
      for variant <- @variants,
          day_offset <- 0..366 do
        date = Date.add(~D[2023-06-15], day_offset)
        {:ok, in_variant} = Date.convert(date, variant)
        assert {:ok, ^date} = Date.convert(in_variant, Calendar.ISO)
      end
    end

    test "variant dates agree with plain Julian on month and day" do
      for variant <- @variants, day_offset <- 0..30 do
        date = Date.add(~D[2024-06-01], day_offset)
        {:ok, julian} = Date.convert(date, Calendrical.Julian)
        {:ok, in_variant} = Date.convert(date, variant)

        assert {julian.month, julian.day} == {in_variant.month, in_variant.day}
      end
    end
  end

  # Each day of two years, as a plain Julian date and a variant date.
  defp day_pairs(variant) do
    for day_offset <- 0..730 do
      iso = Date.add(~D[2023-01-01], day_offset)
      {Date.convert!(iso, Calendrical.Julian), Date.convert!(iso, variant)}
    end
  end

  describe "month lengths follow the date's own Julian month" do
    test "days_in_month/2 agrees with valid_date?/3 for every month of every year" do
      for variant <- [Calendrical.Julian.Jan1 | @variants],
          year <- 2020..2027,
          month <- 1..12,
          day <- 1..31 do
        assert variant.valid_date?(year, month, day) == day <= variant.days_in_month(year, month),
               "#{inspect(variant)} #{year}-#{month}-#{day}"
      end
    end

    test "Date.days_in_month/1 matches plain Julian" do
      for variant <- @variants, {julian, in_variant} <- day_pairs(variant) do
        assert Date.days_in_month(in_variant) == Date.days_in_month(julian)
      end
    end

    test "a March1 February follows the leap year of its Julian year" do
      # March1 label 2023 runs 1 March 2023 to 29 February 2024 (Julian).
      assert Calendrical.Julian.March1.days_in_month(2023, 2) == 29
      assert Calendrical.Julian.March1.days_in_month(2024, 2) == 28
      assert Calendrical.Julian.Sept1.days_in_month(2024, 9) == 30
    end

    test "days_in_month/1 is the Julian month's length" do
      assert Calendrical.Julian.March25.days_in_month(1) == 31
      assert Calendrical.Julian.March25.days_in_month(2) == {:error, :unresolved}
    end
  end

  describe "arithmetic follows the Julian date" do
    test "Date.shift/2 lands on the same day as in plain Julian" do
      durations =
        [month: -13, month: -1, month: 1, month: 11, month: 13, year: -1, year: 1] ++
          [week: 1, week: -3, day: 1, day: -400]

      for variant <- [Calendrical.Julian.Jan1 | @variants],
          {julian, in_variant} <- day_pairs(variant),
          {unit, n} <- durations do
        duration = Duration.new!([{unit, n}])

        assert Date.convert!(Date.shift(in_variant, duration), Calendar.ISO) ==
                 Date.convert!(Date.shift(julian, duration), Calendar.ISO),
               "#{inspect(in_variant)} + #{unit} #{n}"
      end
    end

    test "plain Julian shifts by weeks" do
      assert Date.shift(~D[2025-01-01 Calendrical.Julian], week: 1) ==
               ~D[2025-01-08 Calendrical.Julian]

      assert Calendrical.Julian.plus(2025, 1, 1, :weeks, 2) == {2025, 1, 15}
    end
  end

  describe "year-relative months, years and times" do
    test "month/2 tiles the year from its first day to its last" do
      for variant <- [Calendrical.Julian.Jan1 | @variants], year <- [2023, 2024] do
        ranges = for month <- 1..12, do: variant.month(year, month)
        first = Date.to_gregorian_days(Enum.at(ranges, 0).first)
        last = Date.to_gregorian_days(List.last(ranges).last)

        assert first == variant.first_iso_day_of_year(year)
        assert last == variant.last_iso_day_of_year(year)

        ranges
        |> Enum.zip(tl(ranges))
        |> Enum.each(fn {range, next} ->
          assert Date.to_gregorian_days(range.last) + 1 == Date.to_gregorian_days(next.first)
        end)

        # A date's month of the year is its Julian month, which names it
        for range <- ranges, date <- [range.first, range.last] do
          assert Calendrical.month_of_year(date) == date.month
        end
      end
    end

    test "extended_year/3 and related_gregorian_year/3 hold for every date of the year" do
      for variant <- @variants, {_julian, date} <- day_pairs(variant) do
        assert variant.extended_year(date.year, date.month, date.day) == date.year

        {:ok, first} =
          Date.new(
            date.year,
            variant.first_day_of_year(date.year) |> elem(1),
            variant.first_day_of_year(date.year) |> elem(2),
            variant
          )

        assert variant.related_gregorian_year(date.year, date.month, date.day) ==
                 Date.convert!(first, Calendar.ISO).year
      end
    end

    test "a naive datetime keeps its time of day" do
      for variant <- @variants do
        {:ok, naive} = NaiveDateTime.new(2024, 6, 1, 10, 30, 15, {0, 0}, variant)
        {:ok, iso} = NaiveDateTime.convert(naive, Calendar.ISO)
        assert {iso.hour, iso.minute, iso.second} == {10, 30, 15}
        assert {:ok, ^naive} = NaiveDateTime.convert(iso, variant)
      end
    end
  end
end
