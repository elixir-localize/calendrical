defmodule Calendrical.PreferenceTest do
  @moduledoc """
  Tests for `Calendrical.Preference` — territory preference lists
  and locale-driven calendar resolution, including the BCP 47
  `-u-ca-` (calendar) and `-u-fw-` (first day of week) extensions.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Preference

  describe "preferences_for_territory/1" do
    test "returns the CLDR preference list for a territory" do
      assert {:ok, [:persian, :gregorian | _rest]} = Preference.preferences_for_territory(:IR)
      assert {:ok, [:gregorian]} = Preference.preferences_for_territory(:US)
    end

    test "returns an error for an unknown territory" do
      assert {:error, %Localize.UnknownTerritoryError{}} =
               Preference.preferences_for_territory(:YY)
    end
  end

  describe "calendar_from_territory/1" do
    test "returns the first loaded preferred calendar" do
      assert Preference.calendar_from_territory(:IR) == {:ok, Calendrical.Persian}
    end

    test "resolves gregorian-preferring territories to their territory calendar" do
      assert Preference.calendar_from_territory(:US) == {:ok, Calendrical.US}
      assert Preference.calendar_from_territory(:GB) == {:ok, Calendrical.GB}
    end
  end

  describe "calendar_from_locale/1 with the -u-ca- extension" do
    test "honours an explicit calendar request" do
      assert Preference.calendar_from_locale("en-u-ca-coptic") == {:ok, Calendrical.Coptic}
      assert Preference.calendar_from_locale("en-u-ca-persian") == {:ok, Calendrical.Persian}
      assert Preference.calendar_from_locale("en-u-ca-japanese") == {:ok, Calendrical.Japanese}
      assert Preference.calendar_from_locale("en-u-ca-iso8601") == {:ok, Calendrical.ISOWeek}
    end

    test "resolves an explicit gregorian request through the territory" do
      # ca-gregory selects the calendar system; week conventions still
      # come from the territory.
      assert Preference.calendar_from_locale("en-GB-u-ca-gregory") == {:ok, Calendrical.GB}
      assert Preference.calendar_from_locale("fa-IR-u-ca-gregory") == {:ok, Calendrical.IR}
    end

    test "an explicit request overrides the territory preference" do
      # Iran prefers Persian, but the locale asks for islamic-civil.
      assert Preference.calendar_from_locale("fa-IR-u-ca-islamic-civil") ==
               {:ok, Calendrical.Islamic.Civil}
    end
  end

  describe "calendar_from_locale/1 with the -u-fw- extension" do
    test "fw-mon resolves to the plain Gregorian calendar" do
      assert Preference.calendar_from_locale("en-u-fw-mon") == {:ok, Calendrical.Gregorian}
    end

    test "other first days resolve to a derived Gregorian calendar" do
      assert {:ok, module} = Preference.calendar_from_locale("en-u-fw-sun")
      assert module == Calendrical.Gregorian.Sun
      assert module.__config__().day_of_week == 7
      assert {:ok, _date} = Date.convert(~D[2026-07-05], module)
    end
  end

  describe "calendar_from_locale/1 without extensions" do
    test "falls back to the territory preference" do
      assert Preference.calendar_from_locale("fa-IR") == {:ok, Calendrical.Persian}
      assert Preference.calendar_from_locale("en-GB") == {:ok, Calendrical.GB}
    end

    test "rejects invalid locales" do
      assert {:error, %Localize.InvalidLocaleError{}} = Preference.calendar_from_locale(12_345)
    end
  end

  describe "calendar_module/1" do
    test "maps CLDR calendar types to modules" do
      assert Preference.calendar_module(:persian) == Calendrical.Persian
      assert Preference.calendar_module(:iso8601) == Calendrical.ISOWeek
      assert Preference.calendar_module(:gregorian) == Calendrical.Gregorian
    end
  end
end
