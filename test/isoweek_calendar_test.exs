defmodule Calendrical.ISOWeek.Test do
  use ExUnit.Case, async: true

  test "the configuration of ISOWeek calendar" do
    config = %Calendrical.Config{
      begins_or_ends: :begins,
      calendar: Calendrical.ISOWeek,
      day_of_week: 1,
      first_or_last: :first,
      min_days_in_first_week: 4,
      month_of_year: 1,
      weeks_in_month: [4, 5, 4],
      year: :majority
    }

    assert Calendrical.ISOWeek.__config__() == config
  end
end
