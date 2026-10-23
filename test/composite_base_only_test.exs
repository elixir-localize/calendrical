defmodule Calendrical.CompositeBaseOnlyTest do
  @moduledoc """
  A composite of its base calendar alone (`calendars: []`) has no month a
  change of calendar cuts short, and compiles without a warning: the
  composite's tests for such a month were guards over an empty list, which
  the type checker reports as never succeeding. Its months, and their days
  and weeks, are the base calendar's.

  """

  use ExUnit.Case, async: true

  @source """
  defmodule Calendrical.CompositeBaseOnlyTest.Gregorian do
    use Calendrical.Composite, calendars: [], base_calendar: Calendrical.Gregorian
  end
  """

  test "compiles without a warning and answers as its base calendar" do
    {modules, diagnostics} = Code.with_diagnostics(fn -> Code.compile_string(@source) end)

    assert Enum.filter(diagnostics, &(&1.severity == :warning)) == []

    # The module is compiled here, at run time, so it is called through the
    # name compile_string/1 returns rather than written out.
    assert [{calendar, _binary}] = modules
    assert calendar == Calendrical.CompositeBaseOnlyTest.Gregorian

    assert calendar.days_in_month(2024, 2) == 29
    assert calendar.days_in_month(2023, 2) == 28

    assert calendar.month(2024, 2) ==
             Date.range(Date.new!(2024, 2, 1, calendar), Date.new!(2024, 2, 29, calendar))

    for day <- 1..31 do
      assert calendar.week_of_month(2024, 3, day) ==
               Calendrical.Gregorian.week_of_month(2024, 3, day)
    end
  end
end
