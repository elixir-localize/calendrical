defmodule Calendrical.LocaleCalendar.Test do
  use ExUnit.Case, async: true

  test "that we get the Persian calendar for territory IR" do
    assert Calendrical.Preference.calendar_from_territory(:IR) ==
             {:ok, Calendrical.Persian}
  end

  test "that we get the Persian calendar for locale fa-IR" do
    {:ok, locale} = Localize.validate_locale("fa-IR")

    assert Calendrical.Preference.calendar_from_locale(locale) ==
             {:ok, Calendrical.Persian}
  end

  test "that we get the Gregorian calendar for locale en-US" do
    {:ok, locale} = Localize.validate_locale("en-US")

    assert Calendrical.Preference.calendar_from_locale(locale) ==
             {:ok, Calendrical.US}
  end

  test "that we get the Gregorian calendar for locale en-001" do
    {:ok, locale} = Localize.validate_locale("en-001")

    assert Calendrical.Preference.calendar_from_locale(locale) ==
             {:ok, Calendrical.Gregorian}
  end

  test "that we get the Gregorian calendar for locale en" do
    {:ok, locale} = Localize.validate_locale("en")

    assert Calendrical.Preference.calendar_from_locale(locale) ==
             {:ok, Calendrical.US}
  end
end
