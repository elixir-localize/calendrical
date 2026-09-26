defmodule Calendrical.ParseShimsTest do
  use ExUnit.Case, async: true

  # Calendrical's parse functions delegate to Localize, which owns the
  # parsers and tests them. These checks cover only what the shims add:
  # each reaches its Localize function, a Calendrical calendar module
  # passes through, a named zone resolves through `Calendrical.TimeZone`,
  # and bad input is an error rather than a raise.

  doctest Calendrical.Date
  doctest Calendrical.DateTime
  doctest Calendrical.Time

  @parse_functions [
    {&Calendrical.Date.parse/2, &Localize.Date.parse/2, "May 23, 2026"},
    {&Calendrical.Date.parse_range/2, &Localize.Interval.parse/2, "May 5 – 10, 2026"},
    {&Calendrical.Time.parse/2, &Localize.Time.parse/2, "10:30 PM"},
    {&Calendrical.DateTime.parse/2, &Localize.DateTime.parse/2, "May 23, 2026, 10:30 PM"},
    {&Calendrical.parse/2, &Localize.DateTime.Parser.parse/2, "May 23, 2026"}
  ]

  test "each parse function returns what its Localize function returns" do
    for {calendrical_parse, localize_parse, input} <- @parse_functions, as <- [:struct, :map] do
      assert calendrical_parse.(input, locale: :en, as: as) ==
               localize_parse.(input, locale: :en, as: as)
    end
  end

  test "a Calendrical calendar module is read and returned" do
    assert Calendrical.Date.parse("15 Nisan 5785", locale: :en, calendar: Calendrical.Hebrew) ==
             {:ok, ~D[5785-07-15 Calendrical.Hebrew]}
  end

  test "a named zone resolves through Calendrical.TimeZone" do
    assert {:ok, %DateTime{time_zone: "America/New_York", zone_abbr: "EDT"}} =
             Calendrical.DateTime.parse("May 23, 2026, 2:30 PM America/New_York", locale: :en)
  end

  test "input that is not a string is an error, not a raise" do
    for {calendrical_parse, _localize_parse, _input} <- @parse_functions do
      assert {:error, %Localize.InvalidValueError{}} = calendrical_parse.(123, [])
    end
  end
end
