defmodule Calendrical.SolarTermTest do
  @moduledoc """
  The day of a solar term, which every calendar answers (`solar_term/2`).

  `Calendrical.Lunisolar.solar_term/3` takes the function that gives the
  place a calendar is reckoned at, so a caller had to know which calendars
  have one (`location/1`) and which meridian to use for the rest. A calendar
  answers for itself now: a lunisolar calendar at its own meridian, and any
  other at the traditional reference for the terms, the Chinese calendar's.

  The days known apart from the library are those of the Chinese calendar
  for 2025 and 2026, as published: Qingming, the fifth term, on 4 April
  2025; Dongzhi, the twenty-second, the winter solstice, on 21 December
  2025; and Lichun, the first, on 4 February 2026.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Lunisolar

  @lunisolar [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  describe "solar_term/2" do
    test "is the published day, in the Chinese calendar" do
      assert Calendrical.Chinese.solar_term(5, 2025) ==
               {:ok, ~D[2025-04-04 Calendrical.Gregorian]}

      assert Calendrical.Chinese.solar_term(22, 2025) ==
               {:ok, ~D[2025-12-21 Calendrical.Gregorian]}

      assert Calendrical.Chinese.solar_term(1, 2026) ==
               {:ok, ~D[2026-02-04 Calendrical.Gregorian]}
    end

    test "is reckoned at a lunisolar calendar's own meridian" do
      for calendar <- @lunisolar, index <- [1, 7, 13, 19, 24] do
        assert calendar.solar_term(index, 2002) ==
                 Lunisolar.solar_term(index, 2002, &calendar.location/1)
      end
    end

    test "is reckoned at the Chinese meridian in a calendar reckoned at no place" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Hebrew, Calendrical.Reform.England],
          index <- 1..24 do
        assert calendar.solar_term(index, 2025) == Calendrical.Chinese.solar_term(index, 2025)
      end
    end

    test "has its terms in order through the year, a fortnight or so apart" do
      days =
        for index <- [22, 23, 24] ++ Enum.to_list(1..21) do
          {:ok, date} = Calendrical.Gregorian.solar_term(index, 2025)
          Date.day_of_year(date)
        end

      # From Lichun, early in February, to Dongzhi; the three before
      # Lichun are of December and January.
      [dongzhi, xiaohan, dahan | from_lichun] = days

      assert from_lichun == Enum.sort(from_lichun)

      assert Enum.all?(Enum.chunk_every(from_lichun, 2, 1, :discard), fn [a, b] ->
               (b - a) in 14..16
             end)

      assert xiaohan < dahan and dahan < hd(from_lichun)
      assert dongzhi > List.last(from_lichun)
    end

    test "is an error for what is no term" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Chinese] do
        assert calendar.solar_term(25, 2025) == {:error, {:invalid_solar_term, 25}}
        assert calendar.solar_term(0, 2025) == {:error, {:invalid_solar_term, 0}}
      end
    end
  end
end
