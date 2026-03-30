defmodule Calendrical.Formatter.HTML.Week do
  @moduledoc false

  @behaviour Calendrical.Formatter

  alias Calendrical.Formatter
  alias Calendrical.Formatter.HTML.Basic
  alias Calendrical.Formatter.Options

  @week_class "week"
  @week_prefix "W"

  @impl true
  defdelegate format_year(formatted_months, year, options), to: Formatter.HTML.Basic

  @impl true
  defdelegate format_day(date, year, month, options), to: Formatter.HTML.Basic

  @impl true
  def format_month(formatted_weeks, year, month, options) do
    %Options{caption: caption, id: id, class: class} = options
    caption = caption || Basic.caption(year, month, options)
    day_names = [Basic.day_html(" ", nil) | Basic.day_names(options)]
    Basic.month_html(caption, id, class, day_names, formatted_weeks)
  end

  @impl true
  def format_week(formatted_days, _year, _month, {_, week_number}, options) do
    week_indicator = week_indicator(week_number, options)
    Basic.week_html([week_indicator | formatted_days])
  end

  defp week_indicator(week_number, options) do
    %Options{locale: locale, number_system: number_system} = options

    week_number =
      week_number
      |> Localize.Number.to_string!(locale: locale, number_system: number_system)
      |> lpad

    Basic.day_html(@week_prefix <> week_number, @week_class)
  end

  defp lpad(<<x::bytes-1>>), do: "0" <> x
  defp lpad(x), do: x
end
