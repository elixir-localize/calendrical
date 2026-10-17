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
  #   numbers, `{number, :leap}` for a leap month, as
  #   `Calendrical.Month.traditional_month/3` names them.

  @doc false
  def own_date(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day),
      do: {:ok, {year, month, day}},
      else: {:error, :invalid_date}
  end

  @doc false
  def lunisolar_written_date(calendar, year, month, day) do
    {year, Calendrical.Month.traditional_month(calendar, year, month), day}
  end

  @doc false
  def date_from_lunisolar_written_date(calendar, year, lunar_month, day) do
    case Calendrical.Month.month_from_traditional(calendar, year, lunar_month) do
      {:error, _no_such_month} -> {:error, :invalid_date}
      month -> own_date(calendar, year, month, day)
    end
  end
end
