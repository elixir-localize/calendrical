defmodule Calendrical.Islamic.UmmAlQuraCivilTest do
  @moduledoc """
  `Calendrical.Islamic.UmmAlQura` outside KACST's tables (1 AH to 1500 AH)
  is the arithmetic civil calendar, as ICU falls back to it, and joins the
  tables without a gap or overlap.

  The oracle is ICU4C's civil calendar (`islamcal.cpp`): year `y` begins
  `(y - 1) * 354 + floor((3 + 11 * y) / 30)` days after its epoch, julian
  day 1948440 (19 July 622, ISO day 227,380), month `m` begins
  `ceil(29.5 * (m - 1))` days after its year, and a year is leap when
  `(14 + 11 * y) mod 30 < 11`. ICU takes that remainder with C's `%`; the
  floored remainder is used here, as its year starts use.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Islamic.UmmAlQura

  @epoch 227_380

  defp year_start(year), do: @epoch + (year - 1) * 354 + Integer.floor_div(3 + 11 * year, 30)
  defp month_start(year, month), do: year_start(year) + div(59 * (month - 1) + 1, 2)
  defp leap_year?(year), do: Integer.mod(14 + 11 * year, 30) < 11

  test "the years outside the tables are ICU's civil years" do
    for year <- Enum.concat(-1000..0, 1501..2500) do
      assert UmmAlQura.leap_year?(year) == leap_year?(year), "year #{year}"
      assert UmmAlQura.days_in_year(year) == year_start(year + 1) - year_start(year)

      for month <- 1..12 do
        assert UmmAlQura.date_to_iso_days(year, month, 1) == month_start(year, month)
        assert UmmAlQura.date_from_iso_days(month_start(year, month)) == {year, month, 1}
      end
    end
  end

  test "the tables begin and end where the civil calendar's years do" do
    assert UmmAlQura.date_to_iso_days(1, 1, 1) == year_start(1)
    assert Date.from_gregorian_days(year_start(1)) == ~D[0622-07-19]
    assert Date.from_gregorian_days(year_start(1501) - 1) == ~D[2077-11-16]

    assert UmmAlQura.date_to_iso_days(1500, 12, UmmAlQura.days_in_month(1500, 12)) + 1 ==
             year_start(1501)
  end

  test "every day across both joins follows the day before" do
    for {first, last} <- [{~D[0620-01-01], ~D[0625-12-31]}, {~D[2075-01-01], ~D[2080-12-31]}] do
      days = Date.to_gregorian_days(first)..Date.to_gregorian_days(last)

      days
      |> Enum.map(&{&1, UmmAlQura.date_from_iso_days(&1)})
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [{iso_days, date}, {_next_iso_days, next}] ->
        assert next == next_date(date), "after #{inspect(date)}"
        {year, month, day} = date
        assert UmmAlQura.date_to_iso_days(year, month, day) == iso_days
        assert UmmAlQura.valid_date?(year, month, day)
      end)
    end
  end

  test "the year before 1 AH is year 0" do
    assert Date.convert(~D[0622-07-19], UmmAlQura) == {:ok, Date.new!(1, 1, 1, UmmAlQura)}
    assert Date.convert(~D[0622-07-18], UmmAlQura) == {:ok, Date.new!(0, 12, 29, UmmAlQura)}
  end

  test "a date outside the tables converts and parses" do
    assert {:ok, %Date{calendar: UmmAlQura} = date} = Date.convert(~D[0500-03-15], UmmAlQura)
    assert Date.convert(date, Calendar.ISO) == {:ok, ~D[0500-03-15]}
    assert {:ok, %Date{year: 1600}} = Date.new(1600, 1, 1, UmmAlQura)

    assert {:ok, %Date{calendar: UmmAlQura}} =
             Localize.Date.parse("0500-03-15", calendar: UmmAlQura)
  end

  test "first_day_of_month/2 answers for the tables only" do
    assert {:error, %Calendrical.IslamicYearOutOfRangeError{year: 0}} =
             UmmAlQura.first_day_of_month(0, 1)

    assert {:error, %Calendrical.IslamicYearOutOfRangeError{year: 1501}} =
             UmmAlQura.first_day_of_month(1501, 1)
  end

  defp next_date({year, month, day}) do
    cond do
      day < UmmAlQura.days_in_month(year, month) -> {year, month, day + 1}
      month < 12 -> {year, month + 1, 1}
      true -> {year + 1, 1, 1}
    end
  end
end
