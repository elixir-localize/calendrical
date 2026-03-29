defmodule Calendrical.Test.Calendars do
  defmodule Sunday do
    use Calendrical.Base.Week,
      day_of_week: 7,
      month_of_year: 4,
      weeks_in_month: [4, 4, 5],
      min_days_in_first_week: 7
  end

  defmodule Saturday do
    use Calendrical.Base.Week,
      day_of_week: 6,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Friday do
    use Calendrical.Base.Week,
      day_of_week: 5,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Thursday do
    use Calendrical.Base.Week,
      day_of_week: 4,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Wednesday do
    use Calendrical.Base.Week,
      day_of_week: 3,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Tuesday do
    use Calendrical.Base.Week,
      day_of_week: 2,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Monday do
    use Calendrical.Base.Week,
      day_of_week: 1,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4],
      min_days_in_first_week: 7
  end

  defmodule Month.Sunday do
    use Calendrical.Base.Month,
      day_of_week: 7,
      min_days_in_first_week: 1
  end

  defmodule Month.Friday do
    use Calendrical.Base.Month,
      day_of_week: 5,
      min_days_in_first_week: 1
  end
end
