defmodule Calendrical.CompositeParsingCalendarsTest do
  @moduledoc """
  A composite calendar names its member calendars with `parsing_calendars/0`,
  the base calendar first and the rest in the order they take effect, so a
  reader can take a date in each in turn and convert the one it finds.

  It is needed because a composite writes a date with the formats of the
  calendar in effect on it (`cldr_calendar_type/3`): `Calendrical.Reform.Japan`
  writes 1872 as its lunisolar member does, "Mo5 11, 1872", which the formats
  of its own type, the Japanese calendar's, do not read back. Localize asks
  for the members through `Localize.Calendar.parsing_calendars/1`, which unions
  the answer with the calendar's own and holds every module named to being a
  calendar it can use.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}

  defmodule JapaneseOnly do
    @moduledoc false
    use Calendrical.Composite,
      calendars: [~D[1900-01-01 Calendrical.Japanese]],
      base_calendar: Calendrical.Japanese
  end

  test "the members are named base first, then in the order they take effect" do
    assert Japan.parsing_calendars() == [Calendrical.LunarJapanese, Calendrical.Japanese]

    assert England.parsing_calendars() == [
             Calendrical.Julian,
             Calendrical.Julian.March25,
             Calendrical.Julian.Jan1,
             Calendrical.Gregorian
           ]
  end

  # Sweden reverts to the Julian calendar in 1712, so Julian is both the base
  # and a later member. It is named once, in the base's place.
  test "a calendar in effect more than once is named once" do
    assert Sweden.parsing_calendars() == [
             Calendrical.Julian,
             Calendrical.Reform.Sweden.Transitional,
             Calendrical.Gregorian
           ]
  end

  test "a composite whose members are one calendar names just it" do
    assert JapaneseOnly.parsing_calendars() == [Calendrical.Japanese]
  end

  # What naming the members is for: a date written with a member's formats
  # reads back, where the formats of the composite's own CLDR type do not read
  # it. 1850-01-20 falls in a leap month, numbered 13, whose cyclic year is one
  # behind its era year; 1900-03-15 is after the 1873 change and guards the
  # member that was already read.
  test "a date written with a member's formats reads back" do
    for iso <- [~D[1872-06-16], ~D[1850-01-20], ~D[1700-11-05], ~D[1900-03-15]] do
      {:ok, date} = Date.convert(iso, Japan)
      {:ok, text} = Localize.Date.to_string(date, format: :long, locale: "en")

      assert {:ok, ^date} =
               Localize.Date.parse(text, calendar: Japan, format: :long, locale: "en"),
             "#{iso} wrote #{inspect(text)}, which did not read back as #{inspect(date)}"
    end
  end
end
