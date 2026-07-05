defmodule Calendrical.FormatterTest do
  @moduledoc """
  Rendering tests for the built-in formatters: `HTML.Basic`,
  `HTML.Week`, and `Markdown`.

  These assert the structure of the rendered output — well-formed
  captions, day-name headers, weekday/weekend classes — rather than
  byte-exact documents, so cosmetic template changes don't break
  them but structural regressions do.

  """

  use ExUnit.Case, async: true

  describe "Calendrical.Formatter.HTML.Basic" do
    test "renders a month as an HTML table with a closed caption" do
      html =
        Calendrical.Format.month(2026, 7,
          formatter: Calendrical.Formatter.HTML.Basic,
          calendar: Calendrical.Gregorian
        )
        |> to_string()

      assert html =~ ~s(<table class="cldr_calendar">)
      assert html =~ "<caption>July 2026</caption>"
      assert html =~ "Mon"
      assert html =~ ~s(day_name, weekday)
      assert html =~ ~s(day_name, weekend)
      refute html =~ "</caption\n"
    end

    test "renders an explicit caption and id" do
      html =
        Calendrical.Format.month(2026, 7,
          formatter: Calendrical.Formatter.HTML.Basic,
          calendar: Calendrical.Gregorian,
          caption: "My Caption",
          id: "cal"
        )
        |> to_string()

      assert html =~ "<caption>My Caption</caption>"
      assert html =~ ~s( id="cal")
    end

    test "renders a full year with twelve month tables" do
      html =
        Calendrical.Format.year(2026,
          formatter: Calendrical.Formatter.HTML.Basic,
          calendar: Calendrical.Gregorian
        )
        |> to_string()

      assert length(String.split(html, "<caption>")) == 13
      assert html =~ "January 2026"
      assert html =~ "December 2026"
    end
  end

  describe "Calendrical.Formatter.HTML.Week" do
    test "renders a week-calendar month with week-number rows" do
      html =
        Calendrical.Format.month(2026, 7,
          formatter: Calendrical.Formatter.HTML.Week,
          calendar: Calendrical.NRF
        )
        |> to_string()

      assert html =~ ~s(<table class="cldr_calendar">)
      assert html =~ "</caption>"
      assert html =~ ~s(day_name)
    end
  end

  describe "Calendrical.Formatter.Markdown" do
    test "renders a month as a markdown table with a heading" do
      markdown =
        Calendrical.Format.month(2026, 7,
          formatter: Calendrical.Formatter.Markdown,
          calendar: Calendrical.Gregorian
        )
        |> to_string()

      assert markdown =~ "### July 2026"
      assert markdown =~ "Mon | Tue | Wed | Thu | Fri | Sat | Sun"

      # Days inside the month are bold; leading/trailing days are not.
      assert markdown =~ "**1**"
      assert markdown =~ "**31**"
    end

    test "renders a year of markdown months" do
      markdown =
        Calendrical.Format.year(2026,
          formatter: Calendrical.Formatter.Markdown,
          calendar: Calendrical.Gregorian
        )
        |> to_string()

      assert markdown =~ "### January 2026"
      assert markdown =~ "### December 2026"
    end
  end

  describe "Calendrical.Format helpers" do
    test "formatter_module?/1 recognises the built-in formatters" do
      assert Calendrical.Format.formatter_module?(Calendrical.Formatter.HTML.Basic)
      assert Calendrical.Format.formatter_module?(Calendrical.Formatter.HTML.Week)
      assert Calendrical.Format.formatter_module?(Calendrical.Formatter.Markdown)
      refute Calendrical.Format.formatter_module?(NotAFormatter)
    end

    test "an invalid formatter returns an error" do
      assert {:error, %Calendrical.Formatter.UnknownFormatterError{}} =
               Calendrical.Format.month(2026, 7, formatter: NotAFormatter)
    end
  end
end
