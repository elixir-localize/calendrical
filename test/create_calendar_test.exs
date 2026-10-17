defmodule Calendrical.Create.Test do
  use ExUnit.Case, async: true

  test "that we can create a calendar with a month configuration" do
    assert {:ok, _module} = Calendrical.new(:my_new_calendar, :week, pattern: [4, 4, 5])
  end

  test "that an invalid option is an error" do
    assert {:error, %ArgumentError{message: message}} =
             Calendrical.new(:my_calendar, :week, invalid_option: "blah")

    assert message =~ "unknown options [:invalid_option]"
  end
end
