defmodule Calendrical.Range do
  defmodule Feb do
    use Calendrical.Calendar.Shifted, year_begins: {2, 1}
  end

  defmodule Jan do
    use Calendrical.Calendar.Shifted, year_begins: {1, 1}
  end

  def daterange_periods(calendar \\ Calendrical.Range.Feb) do
    {:ok, today} = Date.convert(Date.utc_today(), calendar)
    this_week = Calendrical.Interval.week(today)
    this_month = Calendrical.Interval.month(today)
    this_year = Calendrical.Interval.year(today)
    last_week_day = Calendrical.previous(today, :week)
    last_month_day = Calendrical.previous(today, :month)
    last_year_day = Calendrical.previous(today, :year)
    last_week = Calendrical.Interval.week(last_week_day)
    last_month = Calendrical.Interval.month(last_month_day)
    last_year = Calendrical.Interval.year(last_year_day)

    %{
      "This week" => [this_week.first, this_week.last],
      "Last week" => [last_week.first, last_week.last],
      "This month" => [this_month.first, this_month.last],
      "Last month" => [last_month.first, last_month.last],
      "This year" => [this_year.first, this_year.last],
      "Last year" => [last_year.first, last_year.last]
    }
  end
end
