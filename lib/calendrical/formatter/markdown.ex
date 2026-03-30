defmodule Calendrical.Formatter.Markdown do
  @moduledoc false

  @behaviour Calendrical.Formatter

  alias Calendrical.Formatter.HTML.Basic
  alias Calendrical.Formatter.Options

  @cell_join " | "
  @heading "### "

  @impl true
  def format_year(formatted_months, _year, _options) do
    Enum.join(formatted_months, "\n\n")
  end

  @impl true
  def format_month(formatted_weeks, year, month, options) do
    %Options{caption: caption, calendar: calendar} = options

    caption = @heading <> (caption || Basic.caption(year, month, options))

    days =
      options.day_names
      |> Enum.map(&elem(&1, 1))
      |> Enum.join(@cell_join)

    separator =
      List.duplicate([" :---: "], calendar.days_in_week())
      |> Enum.join(@cell_join)

    Enum.join([caption, "", days, separator, formatted_weeks], "\n")
  end

  @impl true
  def format_week(formatted_days, _year, _month, _week_number, _options) do
    Enum.join(formatted_days, @cell_join) <> "\n"
  end

  @impl true
  def format_day(date, _year, month, options) do
    %Options{number_system: number_system, locale: locale} = options

    day = Localize.Number.to_string!(date.day, locale: locale, number_system: number_system)

    if date.month == month do
      emphasise(day)
    else
      day
    end
  end

  defp emphasise(day) do
    "**" <> day <> "**"
  end
end
