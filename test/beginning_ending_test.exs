defmodule Calendrical.BeginsEnds.Test do
  use ExUnit.Case, async: true

  test "The US fiscal calendar for fiscal year start and end years" do
    assert Calendrical.start_end_gregorian_years(2019, %Calendrical.Config{
             month_of_year: 10
           }) ==
             {2018, 2019}
  end

  test "The UK fiscal calendar for fiscal year start and end years" do
    assert Calendrical.start_end_gregorian_years(2019, %Calendrical.Config{
             month_of_year: 4
           }) ==
             {2019, 2020}
  end
end
