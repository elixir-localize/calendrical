defmodule Calendrical.UCaCalendarTest do
  @moduledoc """
  The calendar module a language tag's `-u-ca-<name>` extension means.
  Localize does not depend on Calendrical, so the mapping is Calendrical's
  to give (user, 2026-10-06): the module `calendar_from_cldr_calendar_type/1`
  gives the name, refined by the locale where its territory says more than
  the name does, `gregory` to the territory's Gregorian calendar and
  `chinese` in Vietnam to the Vietnamese calendar.

  The table is written out here, a name as a language tag spells it against
  the module it means, and is held to every calendar CLDR has.

  """

  use ExUnit.Case, async: true

  # {CLDR calendar type, its spelling in a language tag, its calendar}
  @calendars [
    {:gregorian, "gregory", Calendrical.Gregorian},
    {:buddhist, "buddhist", Calendrical.Buddhist},
    {:chinese, "chinese", Calendrical.Chinese},
    {:coptic, "coptic", Calendrical.Coptic},
    {:dangi, "dangi", Calendrical.Korean},
    {:ethiopic, "ethiopic", Calendrical.Ethiopic},
    {:ethiopic_amete_alem, "ethioaa", Calendrical.Ethiopic.AmeteAlem},
    {:hebrew, "hebrew", Calendrical.Hebrew},
    {:indian, "indian", Calendrical.Indian},
    {:islamic, "islamic", Calendrical.Islamic.Observational},
    {:islamic_civil, "islamic-civil", Calendrical.Islamic.Civil},
    {:islamic_rgsa, "islamic-rgsa", Calendrical.Islamic.Rgsa},
    {:islamic_tbla, "islamic-tbla", Calendrical.Islamic.Tbla},
    {:islamic_umalqura, "islamic-umalqura", Calendrical.Islamic.UmmAlQura},
    {:japanese, "japanese", Calendrical.Japanese},
    {:persian, "persian", Calendrical.Persian},
    {:roc, "roc", Calendrical.Roc},
    {:iso8601, "iso8601", Calendrical.ISO}
  ]

  # Locales of territories that prefer the Gregorian calendar, and two that
  # prefer another.
  @locales ["en", "en-GB", "de", "ja", "fr-CA", "ar-SA", "fa-IR", "th"]

  test "the table has every calendar CLDR has" do
    assert Enum.sort(for {type, _name, _calendar} <- @calendars, do: type) ==
             Enum.sort([:iso8601 | Localize.known_calendars()])
  end

  test "a name alone is its calendar, as an atom and as a language tag spells it" do
    for {type, name, calendar} <- @calendars do
      assert Calendrical.calendar_from_cldr_calendar_type(type) == {:ok, calendar}
      assert Calendrical.calendar_from_cldr_calendar_type(name) == {:ok, calendar}
    end
  end

  test "a locale's -u-ca- name is the calendar the name alone is" do
    for {type, name, calendar} <- @calendars, type != :gregorian, locale <- @locales do
      assert Calendrical.calendar_from_locale("#{locale}-u-ca-#{name}") == {:ok, calendar},
             "#{locale}-u-ca-#{name}"
    end
  end

  test "a language tag is read as its text is" do
    {:ok, tag} = Localize.validate_locale("en-GB-u-ca-hebrew")
    assert Calendrical.calendar_from_locale(tag) == {:ok, Calendrical.Hebrew}
  end

  describe "the locale refines a name its territory says more about" do
    test "gregory is the territory's Gregorian calendar, with its weeks" do
      assert Calendrical.calendar_from_locale("en-u-ca-gregory") == {:ok, Calendrical.US}
      assert Calendrical.calendar_from_locale("en-GB-u-ca-gregory") == {:ok, Calendrical.GB}
      assert Calendrical.calendar_from_locale("fa-IR-u-ca-gregory") == {:ok, Calendrical.IR}

      # GB's weeks begin on Monday and its first holds four days of the year,
      # where the United States' begin on Sunday.
      assert Calendrical.GB.__config__().day_of_week == 1
      assert Calendrical.US.__config__().day_of_week == 7
    end

    test "naming the calendar a territory already prefers changes nothing" do
      for locale <- ["en", "en-GB", "de", "ja", "fr-CA"] do
        assert Calendrical.calendar_from_locale("#{locale}-u-ca-gregory") ==
                 Calendrical.calendar_from_locale(locale),
               locale
      end

      assert Calendrical.calendar_from_locale("fa-IR-u-ca-persian") ==
               Calendrical.calendar_from_locale("fa-IR")
    end

    test "chinese in Vietnam is the Vietnamese calendar" do
      assert Calendrical.calendar_from_locale("vi-u-ca-chinese") == {:ok, Calendrical.Vietnamese}

      assert Calendrical.calendar_from_locale("vi-VN-u-ca-chinese") ==
               {:ok, Calendrical.Vietnamese}

      assert Calendrical.calendar_from_locale("zh-u-ca-chinese") == {:ok, Calendrical.Chinese}
      assert Calendrical.calendar_from_locale("vi-u-ca-dangi") == {:ok, Calendrical.Korean}
    end
  end

  describe "the calendars CLDR has no name for" do
    test "resolve by name and are not valid in a language tag" do
      for {identifier, calendar} <- Calendrical.additional_calendars(), identifier != :iso8601 do
        name = identifier |> Atom.to_string() |> String.replace("_", "-")

        assert Calendrical.calendar_from_cldr_calendar_type(identifier) == {:ok, calendar}
        assert Calendrical.calendar_from_cldr_calendar_type(name) == {:ok, calendar}

        assert {:error, %Localize.InvalidLocaleError{}} =
                 Calendrical.calendar_from_locale("en-u-ca-#{name}")
      end
    end
  end

  test "what is no locale or name is an error, never a raise" do
    for value <- [123, 1.5, %{}, [], {:a, 1}, "", :"", "en-u-ca-notacal", "not a locale"] do
      assert {:error, exception} = Calendrical.calendar_from_locale(value)
      assert is_exception(exception), inspect(value)
    end

    for value <- [nil, 123, 1.5, %{}, [], {:a, 1}, "", :"", :not_a_calendar, "not-a-calendar"] do
      assert {:error, exception} = Calendrical.calendar_from_cldr_calendar_type(value)
      assert is_exception(exception), inspect(value)
    end
  end
end
