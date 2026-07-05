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
end
