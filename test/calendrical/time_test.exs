defmodule Calendrical.TimeTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Time

  describe "parse/2 — ISO 8601 short-circuit" do
    test "HH:MM:SS parses in every locale" do
      for locale <- [:en, :"en-GB", :de, :fr, :ja, :ar] do
        assert {:ok, ~T[14:30:00]} = Calendrical.Time.parse("14:30:00", locale: locale)
      end
    end

    test "HH:MM parses too" do
      assert {:ok, ~T[14:30:00]} = Calendrical.Time.parse("14:30:00", locale: :en)
    end

    test "fractional seconds preserved" do
      assert {:ok, time} = Calendrical.Time.parse("14:30:00.123456", locale: :en)
      assert time.hour == 14
      assert time.minute == 30
      assert time.second == 0
      assert {123_456, 6} = time.microsecond
    end
  end

  describe "parse/2 — locale 12-hour patterns" do
    test "en accepts `2:30 PM`" do
      assert {:ok, ~T[14:30:00]} = Calendrical.Time.parse("2:30 PM", locale: :en)
    end

    test "en accepts `2:30 AM`" do
      assert {:ok, ~T[02:30:00]} = Calendrical.Time.parse("2:30 AM", locale: :en)
    end

    test "en accepts lowercase `pm`" do
      assert {:ok, ~T[14:30:00]} = Calendrical.Time.parse("2:30 pm", locale: :en)
    end

    test "en medium accepts seconds `2:30:45 PM`" do
      assert {:ok, ~T[14:30:45]} = Calendrical.Time.parse("2:30:45 PM", locale: :en)
    end

    test "12:00 PM is noon, 12:00 AM is midnight" do
      assert {:ok, ~T[12:00:00]} = Calendrical.Time.parse("12:00 PM", locale: :en)
      assert {:ok, ~T[00:00:00]} = Calendrical.Time.parse("12:00 AM", locale: :en)
    end
  end

  describe "parse/2 — locale 24-hour patterns" do
    test "de short pattern `14:30`" do
      assert {:ok, ~T[14:30:00]} = Calendrical.Time.parse("14:30", locale: :de)
    end

    test "de medium pattern `14:30:45`" do
      assert {:ok, ~T[14:30:45]} = Calendrical.Time.parse("14:30:45", locale: :de)
    end

    test "fr 24-hour" do
      assert {:ok, ~T[23:59:59]} = Calendrical.Time.parse("23:59:59", locale: :fr)
    end

    test "ja 24-hour" do
      assert {:ok, ~T[09:15:00]} = Calendrical.Time.parse("9:15:00", locale: :ja)
    end
  end

  describe "parse/2 — error path" do
    test "garbage rejected" do
      assert {:error, %Calendrical.TimeParseError{input: "not a time"}} =
               Calendrical.Time.parse("not a time", locale: :en)
    end

    test "out-of-range hour rejected" do
      assert {:error, _} = Calendrical.Time.parse("25:00:00", locale: :de)
    end

    test "out-of-range minute rejected" do
      assert {:error, _} = Calendrical.Time.parse("12:60:00", locale: :en)
    end
  end
end
