defmodule Calendrical.Base.Egyptian do
  @moduledoc false

  # Shared implementation of the 13-month Egyptian-derived calendar
  # structure used by `Calendrical.Coptic` and `Calendrical.Ethiopic`.
  #
  # Both calendars have twelve 30-day months followed by an epagomenal
  # thirteenth month of 5 days (6 in a leap year) and share the
  # `mod(year, 4) == 3` leap-year rule. They differ only in epoch
  # (Coptic: 29 August 284 CE Julian; Ethiopic: 29 August 8 CE Julian),
  # CLDR calendar type, and era naming, so every epoch-dependent
  # function here takes the calendar's epoch (in ISO days) as its last
  # argument. Public documentation, specs, and examples remain on the
  # calendar modules; these functions are internal.

  import Localize.Utils.Math, only: [amod: 2, mod: 2]

  @months_with_30_days 1..12
  @days_in_week 7
  @epoch_day_of_week 6
  @last_day_of_week 5

  def valid_date?(_year, month, day) when month in @months_with_30_days and day in 1..30 do
    true
  end

  def valid_date?(year, 13, 6) do
    leap_year?(year)
  end

  def valid_date?(_year, 13, day) when day in 1..5 do
    true
  end

  def valid_date?(_year, _month, _day) do
    false
  end

  def year_of_era(year) when year > 0, do: {year, 1}
  def year_of_era(year) when year < 0, do: {abs(year), 0}

  def related_gregorian_year(year, month, day, epoch) do
    {gregorian_year, _, _} =
      date_to_iso_days(year, month, day, epoch)
      |> Calendar.ISO.date_from_iso_days()

    gregorian_year
  end

  def day_of_era(year, month, day, epoch) do
    {_, era} = year_of_era(year)
    days = date_to_iso_days(year, month, day, epoch)

    # Day one of the era is the epoch; the pre-era counts backwards
    # from the day before it.
    if era == 1 do
      {days - epoch + 1, era}
    else
      {epoch - days, era}
    end
  end

  def day_of_week(year, month, day, :default, epoch) do
    days = date_to_iso_days(year, month, day, epoch)
    days_after_saturday = rem(days, 7)
    day = amod(days_after_saturday + @epoch_day_of_week, @days_in_week)

    {day, @epoch_day_of_week, @last_day_of_week}
  end

  # An explicit `starting_on` weekday renumbers the week relative to
  # that start (the ISO convention), while `:default` keeps the
  # calendar's native Saturday-start numbering above.
  def day_of_week(year, month, day, starting_on, epoch) do
    weekday = Calendrical.iso_days_to_day_of_week(date_to_iso_days(year, month, day, epoch))
    {Integer.mod(weekday - weekday_number(starting_on), 7) + 1, 1, 7}
  end

  defp weekday_number(:monday), do: 1
  defp weekday_number(:tuesday), do: 2
  defp weekday_number(:wednesday), do: 3
  defp weekday_number(:thursday), do: 4
  defp weekday_number(:friday), do: 5
  defp weekday_number(:saturday), do: 6
  defp weekday_number(:sunday), do: 7

  def days_in_month(year, 13) do
    if leap_year?(year), do: 6, else: 5
  end

  def days_in_month(_year, month) when month in @months_with_30_days do
    30
  end

  def days_in_year(year) do
    if leap_year?(year), do: 366, else: 365
  end

  def leap_year?(year) do
    mod(year, 4) == 3
  end

  def date_to_iso_days(year, month, day, epoch) do
    (epoch - 1 + 365 * (year - 1) + :math.floor(year / 4) + 30 * (month - 1) + day)
    |> trunc()
  end

  def date_from_iso_days(iso_days, epoch) do
    year = trunc(:math.floor((4 * (iso_days - epoch) + 1463) / 1461))
    month = trunc(:math.floor((iso_days - date_to_iso_days(year, 1, 1, epoch)) / 30)) + 1
    day = iso_days + 1 - date_to_iso_days(year, month, 1, epoch)

    {year, month, day}
  end
end
