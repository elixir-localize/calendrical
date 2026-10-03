defmodule Calendrical.CompositeCldrTypeTest do
  @moduledoc """
  A composite calendar names a date's months and days from the CLDR calendar
  of the member in effect on it (`cldr_calendar_type/3`, user, 2026-10-03),
  so `Calendrical.Reform.Japan` writes its lunisolar dates before 1873 as the
  Chinese CLDR calendar names them and its later dates as the Japanese one
  does. Where no date is given its type is the one its members share, and
  otherwise the last member's.

  The oracle is the member calendar itself: a Japan date is written as
  `Calendrical.LunarJapanese` or `Calendrical.Japanese` writes the same day.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan}

  defmodule JapaneseOnly do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[1900-01-01 Calendrical.Japanese]],
      base_calendar: Calendrical.Japanese
  end

  defp written(date, locale) do
    {:ok, string} = Localize.Date.to_string(date, format: :long, locale: locale)
    string
  end

  test "a composite's types" do
    assert Japan.cldr_calendar_type() == :japanese
    assert Japan.cldr_calendar_type(1228, 2, 7) == :chinese
    assert Japan.cldr_calendar_type(1873, 3, 15) == :japanese
    assert England.cldr_calendar_type() == :gregorian
    assert England.cldr_calendar_type(1700, 1, 1) == :gregorian
    assert JapaneseOnly.cldr_calendar_type() == :japanese
  end

  test "Japan's dates are named by the calendar in effect" do
    {:ok, lunar} = Date.convert(~D[1872-03-15], Japan)

    assert written(lunar, :en) == "Second Month 7, 1872(ren-shen)"
    assert written(lunar, :ja) == "壬申年二月七日"
    assert written(~D[1873-03-15 Calendrical.Reform.Japan], :en) == "March 15, 6 Meiji"
    assert written(~D[1873-03-15 Calendrical.Reform.Japan], :ja) == "明治6年3月15日"

    assert Calendrical.localize(lunar, :month, locale: :en, style: :wide) == "Second Month"

    assert Calendrical.localize(~D[1873-03-15 Calendrical.Reform.Japan], :month,
             locale: :en,
             style: :wide
           ) == "March"
  end

  test "a Japan date is written as its member calendar writes the day" do
    days =
      Enum.concat(
        Date.range(~D[1872-01-01], ~D[1872-12-31], 37),
        Date.range(~D[1873-01-01], ~D[1873-12-31], 37)
      )

    for gregorian <- days, locale <- [:en, :ja] do
      {:ok, date} = Date.convert(gregorian, Japan)
      member = Japan.calendar_for_date(date.year, date.month, date.day)
      {:ok, member_date} = Date.convert(gregorian, member)

      assert written(date, locale) == written(member_date, locale),
             "#{gregorian} in #{locale}"
    end
  end

  test "a composite of one Japanese calendar writes its eras" do
    assert written(~D[1873-03-15 Calendrical.CompositeCldrTypeTest.JapaneseOnly], :ja) ==
             "明治6年3月15日"
  end
end
