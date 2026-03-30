defmodule Calendrical.Formatter.HTML.Basic do
  @moduledoc false

  @behaviour Calendrical.Formatter

  alias Calendrical.Formatter.Options

  @weekend_class "weekend"
  @weekday_class "weekday"
  @today_class "today"

  @in_month_class "in_month"
  @outside_month_class "outside_month"

  @day_name_class "day_name"

  @impl true
  def format_year(formatted_months, year, _options) do
    year_html(year, formatted_months)
  end

  @impl true
  def format_month(formatted_weeks, year, month, options) do
    %Options{caption: caption, id: id, class: class} = options

    caption = caption || caption(year, month, options)
    month_html(caption, id, class, day_names(options), formatted_weeks)
  end

  @impl true
  def format_week(formatted_days, _year, _month, _week_number, _options) do
    week_html(formatted_days)
  end

  @impl true
  def format_day(date, year, month, options) do
    format_day(date, year, month, date.calendar.calendar_base, options)
  end

  def format_day(date, _year, month, :month, options) do
    %Options{number_system: number_system, locale: locale} = options

    class = if date.month == month, do: @in_month_class, else: @outside_month_class
    class = class_from_date(class, date, options)

    formatted_day =
      date.day
      |> Localize.Number.to_string!(locale: locale, number_system: number_system)

    day_html(formatted_day, class)
  end

  def format_day(date, _year, _month, :week, options) do
    class = class_from_date(@in_month_class, date, options)
    {:ok, date} = Date.convert(date, Calendrical.Gregorian)
    day_html(date.day, class)
  end

  def caption(year, month, options) do
    %Options{calendar: calendar, number_system: number_system, locale: locale} =
      options

    {:ok, date} = Date.new(year, month, 1, calendar)

    month_name =
      date
      |> Calendrical.localize(:month, format: :wide)

    year_string =
      year
      |> Localize.Number.to_string!(
        locale: locale,
        format: "####",
        number_system: number_system
      )

    month_name <> " " <> year_string
  end

  def day_names(options) do
    %Options{territory: territory, day_names: day_names} = options
    weekdays = Calendrical.weekdays(territory)

    Enum.map(day_names, fn {day, name} ->
      class = day_name_class(day in weekdays, @day_name_class)
      day_html(name, class)
    end)
  end

  defp class_from_date(default, date, options) do
    %Options{today: today} = options

    day_type = day_type(date, options)
    today = if Date.compare(date, today) == :eq, do: @today_class, else: nil

    [default, day_type, today]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp day_type(date, %Options{territory: territory}) do
    if Calendrical.weekend?(date, territory: territory) do
      @weekend_class
    else
      @weekday_class
    end
  end

  defp day_name_class(true, default) do
    "#{default}, #{@weekday_class}"
  end

  defp day_name_class(false, default) do
    "#{default}, #{@weekend_class}"
  end

  require EEx
  EEx.function_from_file(:def, :day_html, "priv/template/day.eex", [:day, :class])
  EEx.function_from_file(:def, :week_html, "priv/template/week.eex", [:days])
  EEx.function_from_file(:def, :year_html, "priv/template/year.eex", [:year, :months])

  EEx.function_from_file(:def, :month_html, "priv/template/month.eex", [
    :caption,
    :id,
    :class,
    :day_names,
    :weeks
  ])
end
