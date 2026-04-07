defmodule Calendrical.Format do
  @moduledoc """
  Formatting functions for calendars

  """

  alias Calendrical.Formatter.Options

  @default_format_module Calendrical.Formatter.HTML.Basic
  def default_formatter_module do
    @default_format_module
  end

  @default_calendar_css_class "cldr_calendar"
  def default_calendar_css_class do
    @default_calendar_css_class
  end

  def formatter_module?(formatter) do
    Code.ensure_loaded?(formatter) && function_exported?(formatter, :format_year, 3)
  end

  @doc """
  Format one calendar year

  ## Arguments

  * `year` is the year of the calendar
    to be formatted

  * `options` is a `Calendrical.Formatter.Options`
    struct or a `Keyword.t` list of options.

  ## Returns

  * The result of the `format_year/3` callback of
    the configured formatter

  ## Examples

      => Calendrical.Format.year(2019)

      => Calendrical.Format.year(2019, formatter: Calendrical.Formatter.Markdown)

      => Calendrical.Format.year(2019, formatter: Calendrical.Formatter.Markdown, locale: "fr"

  """
  @spec year(Calendar.year(), Options.t() | Keyword.t()) :: any()

  def year(year, options \\ [])

  def year(year, options) when is_list(options) do
    with {:ok, options} <- Options.validate_options(options) do
      year(year, options)
    end
  end

  def year(year, %Options{} = options) do
    %Options{calendar: calendar, formatter: formatter} = options
    range = 1..calendar.months_in_year(year)

    year
    |> months(range, options)
    |> formatter.format_year(year, options)
  end

  defp months(year, range, options) do
    for month <- range do
      month(year, month, options)
    end
  end

  @doc """
  Format one calendar year and month

  ## Arguments

  * `year` is the year of the calendar
    to be formatted

  * `month` is the month of the calendar
    to be formatted

  * `options` is a `Calendrical.Formatter.Options`
    struct or a `Keyword.t` list of options.

  ## Returns

  * The result of the `format_month/4` callback of
    the configured formatter

  ## Examples

      => Calendrical.Format.month(2019, 4)

      => Calendrical.Format.month(2019, 4, formatter: Calendrical.Formatter.HTML.Basic)

      => Calendrical.Format.month(2019, 4, formatter: Calendrical.Formatter.Markdown, locale: "fr"

  """
  @spec month(Calendar.year(), Calendar.month(), Options.t() | Keyword.t()) :: any()

  def month(year, month, options \\ [])

  def month(year, month, options) when is_list(options) do
    with {:ok, options} <- Options.validate_options(options) do
      month(year, month, options)
    end
  end

  def month(year, month, %Options{} = options) do
    %Options{calendar: calendar} = options

    with %Date.Range{first: date} <- calendar.month(year, month) do
      month(year, month, date, calendar.calendar_base(), options)
    end
  end

  defp month(year, month, date, :month, options) do
    %Options{formatter: formatter} = options
    range = 0..5

    date
    |> weeks(range, year, month, options)
    |> formatter.format_month(year, month, options)
  end

  defp month(year, _month, date, :week, options) do
    %Options{calendar: calendar, formatter: formatter} = options
    month = Calendrical.month_of_year(date)

    weeks_in_month =
      date.year
      |> calendar.days_in_month(month)
      |> div(calendar.days_in_week())

    range = 0..(weeks_in_month - 1)

    date
    |> weeks(range, year, month, options)
    |> formatter.format_month(year, month, options)
  end

  defp weeks(date, range, year, month, options) do
    for i <- range do
      shifted_date = Date.shift(date, week: i)
      week_range = Calendrical.Interval.week(shifted_date)
      week(week_range, year, month, options)
    end
  end

  defp week(week, year, month, options) do
    %Options{formatter: formatter} = options
    week_number = Calendrical.week_of_year(week.first)

    days(week, year, month, options)
    |> formatter.format_week(year, month, week_number, options)
  end

  defp days(week, year, month, options) do
    %Options{formatter: formatter} = options

    for date <- week do
      formatter.format_day(date, year, month, options)
    end
  end

  def invalid_formatter_error(formatter) do
    Calendrical.Formatter.UnknownFormatterError.exception(formatter: formatter)
  end

  def invalid_date_error(date) do
    Calendrical.Formatter.InvalidDateError.exception(date: date)
  end
end
