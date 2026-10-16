defmodule Calendrical.Base.Written do
  @moduledoc false

  # The written date of a calendar and the date written figures name, for
  # the makers that relabel a date, until each maker supplies the kernel
  # pair itself:
  #
  # * A calendar whose dates are written as its own fields: the fields,
  #   where they are a date (`own_date/4`).
  #
  # * A lunisolar calendar, whose months are written by their traditional
  #   numbers, `{number, :leap}` for a leap month, as `lunar_month_of_year/2`
  #   names them.
  #
  # * A calendar whose dates are written as another calendar's, through its
  #   `cardinal_year/3`, `numeric_month/3`, `cardinal_day/3` and
  #   `date_from_cardinal_date/3`: a fiscal year's months are the Gregorian
  #   months they are, and a Julian year-start variant's the Julian months.

  @doc false
  def own_date(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day),
      do: {:ok, {year, month, day}},
      else: {:error, :invalid_date}
  end

  @doc false
  def lunisolar_written_date(calendar, year, month, day) do
    {year, calendar.lunar_month_of_year(year, month), day}
  end

  @doc false
  def date_from_lunisolar_written_date(calendar, year, lunar_month, day) do
    case calendar.ordinal_month_from_traditional(year, lunar_month) do
      {:ok, month} -> own_date(calendar, year, month, day)
      {:error, _no_such_month} -> {:error, :invalid_date}
    end
  end

  @doc false
  def cardinal_written_date(calendar, year, month, day) do
    {calendar.cardinal_year(year, month, day), calendar.numeric_month(year, month, day),
     calendar.cardinal_day(year, month, day)}
  end

  @doc false
  def date_from_cardinal_written_date(calendar, year, month, day) do
    case calendar.date_from_cardinal_date(year, month, day) do
      {:error, :invalid_date} = error -> error
      {year, month, day} -> {:ok, {year, month, day}}
    end
  end
end
