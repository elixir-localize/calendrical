defmodule Calendrical.Islamic.UmmAlQura.EquivalenceTest do
  @moduledoc """
  Compares the tabular `Calendrical.Islamic.UmmAlQura`, which is KACST's
  official published table, with `Calendrical.Islamic.UmmAlQura.Astronomical`,
  which computes the Umm al-Qura rules documented by R.H. van Gent from
  sunset, moonset and conjunction at Mecca, for every month from 1420 AH.

  * From 1420 to 1450 AH the two agree in every month except 1446/6, where
    moonset precedes sunset by about seven seconds and the astronomical
    calendar starts the month a day later.

  * From 1451 to 1500 AH KACST's published table departs from the rule as
    computed astronomically: the astronomical calendar is never later than
    KACST, and at most one day earlier.

  Era 2 (1392–1419 AH) is excluded because the astronomical rule there is a
  best-effort approximation of the historical practice.

  """

  use ExUnit.Case, async: false

  alias Calendrical.Islamic.UmmAlQura
  alias Calendrical.Islamic.UmmAlQura.Astronomical

  @tag timeout: :infinity
  test "astronomical minus tabular month starts, 1420 to 1500 AH" do
    differences =
      for(year <- 1420..1500, month <- 1..12, do: {year, month})
      |> Task.async_stream(
        fn {year, month} = key ->
          {:ok, tabular} = UmmAlQura.first_day_of_month(year, month)
          {:ok, astronomical} = Astronomical.first_day_of_month(year, month)
          {key, Date.diff(astronomical, tabular)}
        end,
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, difference} -> difference end)

    to_1450 =
      for {{year, _month}, days} = difference <- differences,
          year <= 1450,
          days != 0,
          do: difference

    assert to_1450 == [{{1446, 6}, 1}]

    from_1451 = for {{year, _month}, days} <- differences, year >= 1451, uniq: true, do: days
    assert Enum.all?(from_1451, &(&1 in [-1, 0])), "unexpected differences #{inspect(from_1451)}"
  end
end
