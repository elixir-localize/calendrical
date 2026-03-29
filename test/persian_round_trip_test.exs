defmodule Calendrical.Persian.RoundTrip.Test do
  use ExUnit.Case
  use ExUnitProperties

  @max_runs 2_000

  property "next and previous weeks" do
    check all(date <- Calendrical.Persian.DateGenerator.generate_date(), max_runs: @max_runs) do
      %{year: y, month: m, day: d} = date

      iso_days = Calendrical.Persian.date_to_iso_days(y, m, d)
      {year, month, day} = Calendrical.Persian.date_from_iso_days(iso_days)

      assert year == y
      assert month == m
      assert day == d
    end
  end
end
