defmodule Calendrical.Formatter do
  @moduledoc """
  Calendar formatter behaviour.

  This behaviour defines a set of
  callbacks that are invoked during
  the formatting of a calendar.

  At each point in the formatting
  process the callbacks are invoked
  from the "inside out".  That is,
  `format_day/4` is invoked for each
  day of the week, then `format_week/5`
  is called, then `format_month/4`
  and finally `format_year/3` is
  called if required.

  """

  @doc """
  Returns the formatted calendar for a year

  ## Arguments

  * `formatted_months` is the result
    returned by `format_month/4`

  * `year` is the year for which
    the calendar is requested

  * `month` is the month for which
    the calendar is requested

  * `options` is a keyword list of formatter options.

  ## Returns

  * An arbitrary result as required.

  """
  @callback format_year(
              formatted_months :: String.t(),
              year :: Calendar.year(),
              options :: map()
            ) :: any()

  @doc """
  Returns the formatted calendar for a month

  ## Arguments

  * `formatted_weeks` is the result
    returned by `format_week/5`

  * `year` is the year for which
    the calendar is requested

  * `month` is the month for which
    the calendar is requested

  * `options` is a keyword list of formatter options.

  ## Returns

  * An arbitrary result as required which is either
    returned if called by `Calendrical.Format.month/3`
    or passed to `format_year/3` if not.

  """
  @callback format_month(
              formatted_weeks :: String.t(),
              year :: Calendar.year(),
              month :: Calendar.month(),
              options :: map()
            ) :: any()

  @doc """
  Returns the formatted calendar for a week

  ## Arguments

  * `formatted_days` is the result
    returned by `format_day/4`

  * `year` is the year for which
    the calendar is requested

  * `month` is the month for which
    the calendar is requested

  * `week_number` is a 2-tuple of the
    form `{year, week_number}` that represents
    the week of year for week to be formatted

  * `options` is a keyword list of formatter options.

  ## Returns

  * An arbitrary result as required which is
    passed to `format_month/4`

  """
  @callback format_week(
              formatted_days :: String.t(),
              year :: Calendar.year(),
              month :: Calendar.month(),
              week_number :: {Calendar.year(), pos_integer},
              options :: map()
            ) :: any()

  @doc """
  Returns the formatted calendar for a day

  ## Arguments

  * `formatted_months` is the result
    returned by `format_month/4`

  * `year` is the year for which
    the calendar is requested

  * `month` is the month for which
    the calendar is requested

  * `options` is a keyword list of formatter options.

  ## Returns

  * An arbitrary result as required which
    is passed to `format_week/5`

  """
  @callback format_day(
              date :: Date.t(),
              year :: Calendar.year(),
              month :: Calendar.month(),
              options :: map()
            ) :: any()
end
