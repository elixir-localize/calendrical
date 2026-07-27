defmodule Calendrical.EraTest do
  @moduledoc """
  Regression tests for `Calendrical.Era` and the era behavior of
  the calendars that delegate to it.

  These anchors pin the corrected CLDR era semantics: calendars
  that number years from their primary era return the calendar
  year as the year of era; "before" eras (BCE, before ROC, before
  Hijra) count backwards from year zero; the Japanese calendar
  selects the era from the date and counts years from each era's
  first Gregorian year.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Era

  defp iso_days(date), do: Date.to_gregorian_days(date)

  describe "year_of_era/3 for epoch-numbered calendars" do
    test "Persian year equals its year of era" do
      assert Calendrical.Persian.year_of_era(1405, 1, 1) == {1405, 0}
      assert Calendrical.Persian.year_of_era(1405) == {1405, 0}
    end

    test "Buddhist year equals its year of era" do
      assert Calendrical.Buddhist.year_of_era(2569, 1, 1) == {2569, 0}
    end

    test "Hebrew year equals its year of era" do
      assert Calendrical.Hebrew.year_of_era(5786, 1, 1) == {5786, 0}
    end

    test "Chinese year equals its year of era" do
      assert Calendrical.Chinese.year_of_era(4663, 1, 1) == {4663, 0}
    end

    test "Korean (dangi) year equals its year of era" do
      assert Calendrical.Korean.year_of_era(4359, 1, 1) == {4359, 0}
    end

    test "Indian year equals its year of era" do
      assert Calendrical.Indian.year_of_era(1947, 1, 1) == {1947, 0}
    end
  end

  describe "year_of_era/3 for calendars with a backwards before-era" do
    test "Gregorian CE and BCE" do
      assert Calendrical.Gregorian.year_of_era(2026, 1, 1) == {2026, 1}
      assert Calendrical.Gregorian.year_of_era(-100, 1, 1) == {101, 0}
    end

    test "ROC and before-ROC count from 1912" do
      assert Calendrical.Roc.year_of_era(115, 1, 1) == {115, 1}
      # ROC year 0 is 1911 CE, the first year before the republic.
      assert Era.year_of_era(:roc, iso_days(~D[1911-06-01]), 0) == {1, 0}
      assert Era.year_of_era(:roc, iso_days(~D[1910-06-01]), -1) == {2, 0}
    end

    test "Islamic year zero and below are in the before-Hijra era" do
      assert Era.year_of_era(:islamic_civil, 0, 1447) == {1447, 0}
      assert Era.year_of_era(:islamic_civil, 0, 0) == {1, 1}
      assert Era.year_of_era(:islamic_civil, 0, -1) == {2, 1}
    end
  end

  describe "year_of_era/3 for the Japanese calendar" do
    test "era changes on the exact boundary date" do
      assert Calendrical.Japanese.year_of_era(2019, 5, 1) == {1, 236}
      assert Calendrical.Japanese.year_of_era(2019, 4, 30) == {31, 235}
    end

    test "Reiwa year counts from its first Gregorian year" do
      assert Calendrical.Japanese.year_of_era(2026, 1, 1) == {8, 236}
    end
  end

  describe "year_of_era/3 for the lunisolar Japanese calendar" do
    test "modern dates carry the current era" do
      date = Date.convert!(~D[2026-07-05], Calendrical.LunarJapanese)
      assert Calendrical.LunarJapanese.year_of_era(date.year, date.month, date.day) == {8, 236}
      assert Calendrical.LunarJapanese.calendar_year(date.year, date.month, date.day) == 8
    end

    test "an era begins on its proclamation day, mid-lunar-year" do
      # 安政 (Ansei, era 227) was proclaimed on 嘉永7年11月27日,
      # proleptic Gregorian 1855-01-15. The rest of that lunar year
      # is 安政元年; the day before remains 嘉永7年.
      ansei_day = Date.convert!(~D[1855-01-15], Calendrical.LunarJapanese)
      kaei_day = Date.convert!(~D[1855-01-14], Calendrical.LunarJapanese)

      assert Calendrical.LunarJapanese.year_of_era(ansei_day.year, ansei_day.month, ansei_day.day) ==
               {1, 227}

      assert Calendrical.LunarJapanese.year_of_era(kaei_day.year, kaei_day.month, kaei_day.day) ==
               {7, 226}
    end

    test "the Reiwa transition is exact" do
      reiwa = Date.convert!(~D[2019-05-01], Calendrical.LunarJapanese)
      heisei = Date.convert!(~D[2019-04-30], Calendrical.LunarJapanese)

      assert Calendrical.LunarJapanese.year_of_era(reiwa.year, reiwa.month, reiwa.day) ==
               {1, 236}

      assert Calendrical.LunarJapanese.year_of_era(heisei.year, heisei.month, heisei.day) ==
               {31, 235}
    end

    test "year_of_era/1 uses the first day of the lunar year" do
      assert Calendrical.LunarJapanese.year_of_era(1382) == {8, 236}
    end

    test "era names localize from the Japanese calendar" do
      date = Date.convert!(~D[2026-07-05], Calendrical.LunarJapanese)

      assert Calendrical.localize(date, :era, locale: :en) == "Reiwa"
      assert Calendrical.localize(date, :era, locale: :ja) == "令和"
      assert Calendrical.localize(date, :era, style: :narrow, locale: :en) == "R"

      ansei = Date.convert!(~D[1855-01-15], Calendrical.LunarJapanese)
      assert Calendrical.localize(ansei, :era, locale: :ja) == "安政"
    end

    test "day_of_era counts from the era proclamation day" do
      reiwa_day_one = Date.convert!(~D[2019-05-01], Calendrical.LunarJapanese)

      assert Calendrical.LunarJapanese.day_of_era(
               reiwa_day_one.year,
               reiwa_day_one.month,
               reiwa_day_one.day
             ) == {1, 236}
    end
  end

  describe "day_of_era/2" do
    test "first day of an era is day one" do
      assert Era.day_of_era(:japanese, iso_days(~D[2019-05-01])) == {1, 236}
      assert Era.day_of_era(:gregorian, iso_days(~D[0001-01-01])) == {1, 1}
      assert Era.day_of_era(:roc, iso_days(~D[1912-01-01])) == {1, 1}
    end

    test "days count forward within an era" do
      assert Era.day_of_era(:japanese, iso_days(~D[2019-05-31])) == {31, 236}
    end

    test "a date before all eras raises a clear error" do
      assert_raise ArgumentError, ~r/before all eras/, fn ->
        Era.day_of_era(:chinese, iso_days(~D[-9999-01-01]))
      end
    end
  end

  describe "era_data/1" do
    test "is cached in persistent_term after first access" do
      data = Era.era_data(:persian)
      assert :persistent_term.get({Calendrical.Era, :persian}) == data
      assert Era.era_data(:persian) == data
    end

    test "records are ordered most recent era first" do
      %{records: [first | _rest] = records} = Era.era_data(:japanese)
      assert first.era == 236
      assert length(records) == 237
    end

    test "pre-Meiji Japanese era boundaries are resolved from their lunisolar dates" do
      %{records: records} = Era.era_data(:japanese)

      # Anchors from the japanese_eras validation research: CLDR raw
      # `[Y, M, D]` is a lunisolar passthrough; the boundary must be
      # its proleptic Gregorian equivalent.
      taika = Enum.find(records, &(&1.era == 0))
      assert taika.from == Date.to_gregorian_days(~D[0645-07-20])

      taiho = Enum.find(records, &(&1.era == 4))
      assert taiho.from == Date.to_gregorian_days(~D[0701-05-07])

      kaei = Enum.find(records, &(&1.era == 226))
      assert kaei.from == Date.to_gregorian_days(~D[1848-04-01])

      # CLDR's [1504, 2, 30] records a historical 30th day where the
      # astronomical reconstruction gives the month 29 days; the
      # boundary is the day after the reconstructed month ends.
      eisho = Enum.find(records, &(&1.gregorian_year == 1504))
      assert eisho.from == Date.to_gregorian_days(~D[1504-03-26])

      # Era 115 (建保, CLDR [1213, 12, 6]) starts in lunar year 569,
      # a 383-day leap year that the old floor-based leap-year
      # detection misclassified, forcing a raw-Gregorian fallback.
      # It now resolves astronomically to 1214-01-25.
      kenpo = Enum.find(records, &(&1.era == 115))
      assert kenpo.from == Date.to_gregorian_days(~D[1214-01-25])
    end

    test "Japanese era data builds without any lunisolar fallback warning" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          :persistent_term.erase({Calendrical.Era, :japanese})
          Era.era_data(:japanese)
        end)

      refute log =~ "could not be resolved as a lunisolar date"
    end

    test "Meiji and later Japanese era boundaries are proleptic Gregorian" do
      %{records: records} = Era.era_data(:japanese)

      meiji = Enum.find(records, &(&1.era == 232))
      assert meiji.from == Date.to_gregorian_days(~D[1868-10-23])

      reiwa = Enum.find(records, &(&1.era == 236))
      assert reiwa.from == Date.to_gregorian_days(~D[2019-05-01])
    end

    test "an unknown calendar type raises with the known types listed" do
      assert_raise ArgumentError, ~r/unknown CLDR calendar type/, fn ->
        Era.era_data(:no_such_calendar)
      end
    end
  end
end
