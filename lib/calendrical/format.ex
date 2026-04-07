defmodule Calendrical.Format do
  @moduledoc """
  Renders Calendrical calendars as years, months, weeks, and days using a
  pluggable formatter.

  `Calendrical.Format` walks a calendar at year, month, or week granularity and
  delegates the actual rendering to a formatter module that implements the
  `Calendrical.Formatter` behaviour. The library ships with HTML and Markdown
  formatters; the default formatter is returned by `default_formatter_module/0`.

  Custom formatters can be added by implementing the `Calendrical.Formatter`
  behaviour (`format_year/3`, `format_month/4`, `format_week/5`, and
  `format_day/4`).

  All entry points (`year/2`, `month/3`) accept a keyword list of options.

  """

  alias Calendrical.Formatter.Options

  @default_format_module Calendrical.Formatter.HTML.Basic

  @doc """
  Returns the default formatter module used when no `:formatter` option is
  given to `year/2` or `month/3`.

  ### Returns

  * The module name of the default HTML formatter.

  ### Examples

      iex> Calendrical.Format.default_formatter_module()
      Calendrical.Formatter.HTML.Basic

  """
  def default_formatter_module do
    @default_format_module
  end

  @default_calendar_css_class "cldr_calendar"

  @doc """
  Returns the default CSS class used by the HTML formatters when wrapping a
  calendar in a container element.

  ### Returns

  * A string. Currently `"cldr_calendar"`.

  ### Examples

      iex> Calendrical.Format.default_calendar_css_class()
      "cldr_calendar"

  """
  def default_calendar_css_class do
    @default_calendar_css_class
  end

  @doc """
  Returns `true` if the given module appears to implement the
  `Calendrical.Formatter` behaviour.

  The check is a runtime duck-typing check: the module is loaded and inspected
  for an exported `format_year/3` function.

  ### Arguments

  * `formatter` is a module name.

  ### Returns

  * `true` if the module exports `format_year/3`, otherwise `false`.

  ### Examples

      iex> Calendrical.Format.formatter_module?(Calendrical.Formatter.HTML.Basic)
      true

      iex> Calendrical.Format.formatter_module?(String)
      false

  """
  def formatter_module?(formatter) do
    Code.ensure_loaded?(formatter) && function_exported?(formatter, :format_year, 3)
  end

  @doc """
  Formats one calendar year using the configured formatter.

  ### Arguments

  * `year` is the year of the calendar to be formatted.

  * `options` is a keyword list of options.

  ### Options

  * `:calendar` is the Calendrical calendar module to format. Defaults to
    `Calendrical.Gregorian`.

  * `:formatter` is the formatter module. Defaults to the value of
    `default_formatter_module/0`.

  * `:locale` is a locale identifier atom, string, or a
    `t:Localize.LanguageTag.t/0`. The default is `Localize.get_locale/0`.

  * Any additional formatter-specific options are passed through to the
    formatter callbacks.

  ### Returns

  * The value returned by the `format_year/3` callback of the configured
    formatter.

  ### Examples

      => Calendrical.Format.year(2019)

      => Calendrical.Format.year(2019, formatter: Calendrical.Formatter.Markdown)

      => Calendrical.Format.year(2019, formatter: Calendrical.Formatter.Markdown, locale: "fr")

  """
  @spec year(Calendar.year(), Keyword.t() | map()) :: any()

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
  Formats one calendar month using the configured formatter.

  ### Arguments

  * `year` is the year of the calendar to be formatted.

  * `month` is the month of the calendar to be formatted.

  * `options` is a keyword list of options.

  ### Options

  * `:calendar` is the Calendrical calendar module to format. Defaults to
    `Calendrical.Gregorian`.

  * `:formatter` is the formatter module. Defaults to the value of
    `default_formatter_module/0`.

  * `:locale` is a locale identifier atom, string, or a
    `t:Localize.LanguageTag.t/0`. The default is `Localize.get_locale/0`.

  * Any additional formatter-specific options are passed through to the
    formatter callbacks.

  ### Returns

  * The value returned by the `format_month/4` callback of the configured
    formatter.

  ### Examples

      => Calendrical.Format.month(2019, 4)

      => Calendrical.Format.month(2019, 4)

      => Calendrical.Format.month(2019, 4, formatter: Calendrical.Formatter.Markdown, locale: "fr")

  """
  @spec month(Calendar.year(), Calendar.month(), Keyword.t() | map()) :: any()

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

  @doc false
  def invalid_formatter_error(formatter) do
    Calendrical.Formatter.UnknownFormatterError.exception(formatter: formatter)
  end

  @doc false
  def invalid_date_error(date) do
    Calendrical.Formatter.InvalidDateError.exception(date: date)
  end
end
