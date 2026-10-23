defmodule Calendrical.Test.CompositeChanges do
  @moduledoc false

  # A composite calendar's changes of calendar as `{iso_days, year, month,
  # day, calendar}`, built from its public `info().members`: the base
  # calendar first, listed by 1 January -9999 with no ISO day, then each
  # calendar that takes effect with the date it is written on in that
  # calendar.

  def changes(composite) do
    Enum.map(composite.info().members, &change/1)
  end

  defp change({nil, calendar}), do: {nil, -9999, 1, 1, calendar}

  defp change({iso_days, calendar}) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    {iso_days, year, month, day, calendar}
  end
end
