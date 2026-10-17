defmodule Calendrical.Test.Calendars do
  defmodule Sunday do
    use Calendrical.Calendar.Weeks,
      pattern: [4, 4, 5],
      year_begins: {:sunday, :on_or_before, {4, 7}}
  end

  defmodule Saturday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:saturday, :on_or_before, {1, 7}}
  end

  defmodule Friday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:friday, :on_or_before, {1, 7}}
  end

  defmodule Thursday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:thursday, :on_or_before, {1, 7}}
  end

  defmodule Wednesday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:wednesday, :on_or_before, {1, 7}}
  end

  defmodule Tuesday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:tuesday, :on_or_before, {1, 7}}
  end

  defmodule Monday do
    use Calendrical.Calendar.Weeks,
      pattern: [5, 4, 4],
      year_begins: {:monday, :on_or_before, {1, 7}}
  end

  defmodule Month.Sunday do
    use Calendrical.Calendar.Shifted, weeks: [first_day: 7, min_days_in_first_week: 1]
  end

  defmodule Month.Friday do
    use Calendrical.Calendar.Shifted, weeks: [first_day: 5, min_days_in_first_week: 1]
  end
end
