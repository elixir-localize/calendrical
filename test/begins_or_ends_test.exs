defmodule Calendrical.BeginsOrEndsTest do
  @moduledoc """
  A calendar of weeks begins or ends its year by one rule, a weekday near
  a day of a Gregorian month, given as `:year_begins` or `:year_ends`; a
  month calendar takes neither.

  """

  use ExUnit.Case, async: true

  alias __MODULE__, as: T

  test "a calendar of weeks takes a rule for the year's beginning or its end" do
    assert {:ok, begins} =
             Calendrical.new(T.WeekBegins, :week, year_begins: {:monday, :on_or_before, {1, 4}})

    assert {:ok, ends} =
             Calendrical.new(T.WeekEnds, :week, year_ends: {:saturday, :nearest, {1, 31}})

    assert begins.info().weeks.first_day == 1
    assert ends.info().weeks.first_day == 7
    assert Calendrical.NRF.info().weeks.first_day == 7
  end

  test "a calendar of weeks refuses both rules at once, and a rule it cannot keep" do
    assert {:error, %Calendrical.InvalidOptionValueError{} = both_error} =
             Calendrical.new(T.WeekBoth, :week,
               year_begins: {:monday, :on_or_before, {1, 4}},
               year_ends: {:saturday, :nearest, {1, 31}}
             )

    assert Exception.message(both_error) =~ ":year_begins or :year_ends, not both"

    assert {:error, %Calendrical.InvalidOptionValueError{} = beyond_error} =
             Calendrical.new(T.WeekBeyond, :week, year_begins: {:monday, :on_or_before, {1, 9}})

    assert Exception.message(beyond_error) =~ ":year_begins must be"

    assert {:error, %Calendrical.InvalidOptionValueError{} = early_error} =
             Calendrical.new(T.WeekEarly, :week, year_ends: {:saturday, :on_or_after, {1, 10}})

    assert Exception.message(early_error) =~ ":year_ends must be"
  end

  test "left out, the year begins on the Monday on or before 1 January" do
    assert {:ok, default} = Calendrical.new(T.WeekDefault, :week, [])
    assert default.info().weeks.first_day == 1
    assert default.date_from_iso_days(Date.to_gregorian_days(~D[2026-01-01])) == {2026, 1, 4}
  end

  test "a month calendar refuses them" do
    assert {:error, %Calendrical.UnknownOptionError{} = message_error} =
             Calendrical.new(T.MonthEndsFirst, :month,
               year_ends: {:saturday, :nearest, {1, 31}},
               year_begins: {7, 1}
             )

    assert Exception.message(message_error) =~ "does not read the options [:year_ends]"
  end

  test "use Calendrical.Calendar.Weeks refuses a rule it cannot keep" do
    assert_raise Calendrical.InvalidOptionValueError,
                 ~r/:year_begins or :year_ends, not both/,
                 fn ->
                   Code.compile_string("""
                   defmodule Calendrical.BeginsOrEndsTest.UseBoth do
                     use Calendrical.Calendar.Weeks,
                       year_begins: {:monday, :on_or_before, {1, 4}},
                       year_ends: {:saturday, :nearest, {1, 31}}
                   end
                   """)
                 end
  end
end
