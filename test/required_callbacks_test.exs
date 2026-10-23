defmodule Calendrical.RequiredCallbacksTest do
  @moduledoc """
  Every callback of the Calendrical behaviour is required, so a consumer
  asks any calendar any question and never whether it can (user,
  2026-10-16). The five that were optional — `cldr_calendar_type/3`,
  `parsing_calendars/0`, `months_in_leap_year/0`,
  `date_from_cardinal_date/3` and `calendar_from_cldr_calendar_type/1` —
  have defaults that answer as a caller did where a calendar had none, and
  a calendar whose answer differs gives its own. That every calendar
  exports each one is held by `test/calendar_contract_test.exs`.

  """

  use ExUnit.Case, async: true

  test "the behaviour has no optional callbacks" do
    assert Calendrical.behaviour_info(:optional_callbacks) == []
  end

  describe "the defaults" do
    test "name a calendar's dates by its one CLDR calendar" do
      assert Calendrical.Gregorian.cldr_calendar_type(2026, 1, 1) == :gregorian

      # A composite answers for the calendar in effect on the date.
      assert Calendrical.Reform.Japan.cldr_calendar_type(1872, 1, 1) == :chinese
    end

    test "read a date in the calendar itself" do
      assert Calendrical.Gregorian.parsing_calendars() == [Calendrical.Gregorian]

      # A composite names its members.
      assert Calendrical.Gregorian in Calendrical.Reform.England.parsing_calendars()
    end

    test "count a leap year's months as the most a year has" do
      assert Calendrical.Gregorian.months_in_leap_year() == 12
      assert Calendrical.Hebrew.months_in_leap_year() == 13
      assert Calendrical.Chinese.months_in_leap_year() == 13
    end

    test "read a written date as the calendar's own fields" do
      assert Calendrical.Hebrew.date_from_cardinal_date(5785, 1, 15) == {5785, 1, 15}

      assert {:error, %Calendrical.InvalidDateError{}} =
               Calendrical.Gregorian.date_from_cardinal_date(2026, 2, 30)
    end

    test "resolve a CLDR calendar type through the family" do
      assert Calendrical.Gregorian.calendar_from_cldr_calendar_type(:hebrew) ==
               {:ok, Calendrical.Hebrew}
    end
  end

  # A leap month is written by its own name, which the inversion of a
  # written date does not take, so it is read back as the leap month and
  # not the month of its number: the Chinese year 4662 has a second sixth
  # month, its month 7, from 25 July 2025.
  test "a leap month is read back as the leap month" do
    assert {:ok, text} =
             Localize.Date.to_string(Date.new!(4662, 7, 1, Calendrical.Chinese),
               format: :long,
               locale: :en
             )

    assert Localize.Date.parse(text, calendar: Calendrical.Chinese, format: :long, locale: :en) ==
             {:ok, Date.new!(4662, 7, 1, Calendrical.Chinese)}
  end
end
