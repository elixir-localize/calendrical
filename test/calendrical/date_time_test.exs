defmodule Calendrical.DateTimeTest do
  use ExUnit.Case, async: true

  doctest Calendrical.DateTime

  describe "parse/2 — ISO 8601 short-circuit" do
    test "naive datetime parses in every locale" do
      for locale <- [:en, :de, :fr, :ja, :ar] do
        assert {:ok, ~N[2026-05-16 14:30:00]} =
                 Calendrical.DateTime.parse("2026-05-16T14:30:00", locale: locale)
      end
    end

    test "Z-suffix produces DateTime" do
      assert {:ok, dt} = Calendrical.DateTime.parse("2026-05-16T14:30:00Z", locale: :en)
      assert dt.year == 2026
      assert dt.time_zone == "Etc/UTC"
    end

    test "fractional seconds preserved" do
      assert {:ok, ndt} = Calendrical.DateTime.parse("2026-05-16T14:30:00.123", locale: :en)
      assert {123_000, 3} = ndt.microsecond
    end

    test "space separator (instead of T) is accepted" do
      # Stdlib `NaiveDateTime.from_iso8601/1` accepts space; we
      # gate on the shape so we accept it too. Common in logs,
      # Postgres `timestamp` columns, SQLite, etc.
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.DateTime.parse("2026-05-16 14:30:00", locale: :en)

      assert {:ok, dt} = Calendrical.DateTime.parse("2026-05-16 14:30:00Z", locale: :en)
      assert dt.time_zone == "Etc/UTC"
    end
  end

  describe "parse/2 — locale glue patterns" do
    test "en glue is `, `" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.DateTime.parse("May 16, 2026, 2:30 PM", locale: :en)
    end

    test "en glue with embedded comma in date half (backtrack-correctly)" do
      # `MMM d, y` puts a comma between day and year. The
      # locale glue is also `, ` — splitter must backtrack to
      # the LATEST glue position.
      assert {:ok, ~N[2017-07-10 09:15:00]} =
               Calendrical.DateTime.parse("Jul 10, 2017, 9:15 AM", locale: :en)
    end

    test "en short form `5/16/26, 2:30 PM`" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.DateTime.parse("5/16/26, 2:30 PM", locale: :en)
    end

    test "de uses `, ` glue with `dd.MM.y, HH:mm`" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.DateTime.parse("16.05.2026, 14:30", locale: :de)
    end

    test "en-GB short" do
      assert {:ok, ~N[2026-05-16 14:30:45]} =
               Calendrical.DateTime.parse("16/05/2026, 14:30:45", locale: :"en-GB")
    end

    test "ja uses space glue" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.DateTime.parse("2026/05/16 14:30:00", locale: :ja)
    end
  end

  describe "parse/2 — error path" do
    test "garbage rejected" do
      assert {:error, %Calendrical.DateTimeParseError{}} =
               Calendrical.DateTime.parse("not a datetime", locale: :en)
    end

    test "date-only input rejected (no glue separator)" do
      assert {:error, _} = Calendrical.DateTime.parse("May 16, 2026", locale: :en)
    end
  end

  describe "parse/2 — extended glue separators" do
    test "bare space splits date and time even when CLDR specifies a longer glue" do
      # CLDR `:en` ships `MMM d, y, h:mm a` as the standard glue
      # — but real-world inputs frequently glue with just a
      # bare space.
      assert {:ok, ~N[2018-01-01 14:44:00]} =
               Calendrical.DateTime.parse("01/01/2018 14:44", locale: :en)
    end

    test "' - ' splits date and time" do
      assert {:ok, ~N[2018-01-01 17:06:00]} =
               Calendrical.DateTime.parse("01/01/2018 - 17:06", locale: :en)
    end
  end

  describe "parse/2 — as: :map" do
    test "locale-glue datetime merges date and time fields" do
      assert {:ok,
              %{
                calendar: Calendar.ISO,
                year: 2026,
                month: 5,
                day: 16,
                hour: 14,
                minute: 30
              }} =
               Calendrical.DateTime.parse("May 16, 2026, 2:30 PM",
                 locale: :en,
                 as: :map
               )
    end

    test "partial date + time omits year" do
      assert {:ok, %{calendar: Calendar.ISO, month: 5, day: 5, hour: 11, minute: 30}} =
               Calendrical.DateTime.parse("May 5, 11:30 AM", locale: :en, as: :map)
    end

    test "ISO naive datetime returns full map" do
      assert {:ok,
              %{
                calendar: Calendar.ISO,
                year: 2026,
                month: 5,
                day: 16,
                hour: 14,
                minute: 30,
                second: 0
              }} =
               Calendrical.DateTime.parse("2026-05-16T14:30:00", locale: :en, as: :map)
    end

    test "ISO datetime with Z includes :time_zone" do
      {:ok, map} =
        Calendrical.DateTime.parse("2026-05-16T14:30:00Z", locale: :en, as: :map)

      assert map.year == 2026
      assert map.hour == 14
      assert map.time_zone == "Etc/UTC"
    end
  end
end
