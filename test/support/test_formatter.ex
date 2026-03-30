defmodule Calendrical.Test.Formatter do
  @behaviour Calendrical.Formatter

  @impl true
  def format_year(formatted_months, year, options) do
    %{year: year, months: formatted_months, options: options}
  end

  @impl true
  def format_month(formatted_weeks, year, month, options) do
    %{year: year, month: month, weeks: formatted_weeks, options: options}
  end

  @impl true
  def format_week(formatted_days, year, month, {_, week_number}, options) do
    %{year: year, month: month, days: formatted_days, week_number: week_number, options: options}
  end

  @impl true
  def format_day(date, _year, _month, _options) do
    date
  end
end
