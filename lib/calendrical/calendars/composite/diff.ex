defmodule Calendrical.Composite.Diff do
  @moduledoc false

  # The whole number of years, quarters, months, weeks or days from one date
  # of a composite calendar to another: the inverse of its `plus/6`, the
  # largest count it can add to the earlier date without passing the later,
  # and negative when `to` is before `from`.
  #
  # The day a count reaches is compared as a day, the composite's `reach/5`,
  # and not as the date `plus/6` writes for it: where two stretches of days
  # carry the same dates the later has none of its own, and the date written
  # for one of its days names a day a year before it. And the count is
  # bracketed from the days between the two dates and then halved, not
  # stepped to from the difference of the years' numbers, which a change of
  # calendar can put hundreds of years out: Japan's year after 1228 was 1873.

  # No fewer days than a month has, or a year: a first count that is seldom
  # past the later date.
  @days_in_month 31
  @days_in_year 366

  @doc false
  def diff(calendar, from, to, date_part) do
    from_days = days(calendar, from)
    to_days = days(calendar, to)

    if to_days < from_days,
      do: -count(calendar, to, from_days, from_days - to_days, date_part),
      else: count(calendar, from, to_days, to_days - from_days, date_part)
  end

  defp count(_calendar, _from, _limit, days, :days), do: days

  defp count(calendar, _from, _limit, days, :weeks), do: div(days, calendar.days_in_week())

  defp count(calendar, from, limit, days, :quarters),
    do: div(count(calendar, from, limit, days, :months), 3)

  defp count(calendar, from, limit, days, :months),
    do: largest(calendar, from, limit, :months, div(days, @days_in_month))

  defp count(calendar, from, limit, days, :years),
    do: largest(calendar, from, limit, :years, div(days, @days_in_year))

  # The largest count that does not pass `limit`: bracketed about a first
  # count by steps that double, and then halved. No count at all is never
  # past the limit.
  defp largest(calendar, {year, month, day}, limit, date_part, count) do
    within? = fn count -> calendar.reach(year, month, day, date_part, count) <= limit end

    if within?.(count),
      do: above(within?, count, 1),
      else: below(within?, count, 1)
  end

  defp above(within?, count, step) do
    if within?.(count + step),
      do: above(within?, count + step, step * 2),
      else: between(within?, count, count + step)
  end

  defp below(within?, count, step) do
    lower = max(count - step, 0)

    if within?.(lower),
      do: between(within?, lower, count),
      else: below(within?, lower, step * 2)
  end

  # `low` is within the limit and `high` is past it.
  defp between(_within?, low, high) when high - low <= 1, do: low

  defp between(within?, low, high) do
    middle = div(low + high, 2)

    if within?.(middle),
      do: between(within?, middle, high),
      else: between(within?, low, middle)
  end

  defp days(calendar, {year, month, day}) do
    calendar.date_to_iso_days(year, month, day)
  end
end
