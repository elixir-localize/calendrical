defmodule Calendrical.Islamic.Visibility do
  @moduledoc false

  # The month rules of the *observational* Islamic calendars,
  # `Calendrical.Islamic.Observational` (Cairo) and `Calendrical.Islamic.Rgsa`
  # (Mecca): a month begins on the day after the evening its new crescent is
  # first seen. These are `phasis-on-or-before` and `phasis-on-or-after` of
  # Dershowitz & Reingold, *Calendrical Calculations* (4th ed., chapter 14).
  #
  # The astronomy is Astro's: `Astro.first_visible_crescent_on_or_before/4`
  # and `first_visible_crescent_on_or_after/4` find the evening a lunation's
  # crescent is first seen, by the Odeh (2004), Yallop (1997) or Schaefer
  # criterion, counting the categories `:A`, `:B` and `:C` as seen. Odeh is
  # used by default, the most modern empirical fit and the basis for several
  # national Islamic calendar committees. A day here is the day after its
  # evening, as the Islamic day begins at sunset.

  @default_method :odeh

  # The fewest days a month has: the crescent is first seen 29 or 30 days
  # after it was last first seen.
  @shortest_month 29

  # The months a day's month is looked for in, from the one its distance
  # from the epoch gives, which is the month or one beside it.
  @month_walk_limit 4

  @typedoc """
  A crescent-visibility criterion: the Odeh (2004), Yallop (1997)
  or Schaefer empirical model.

  """
  @type method :: :odeh | :schaefer | :yallop

  @doc """
  Returns the ISO day number of the most recent date on or before
  `iso_days` on the eve of which the crescent moon was first visible
  at `location`.

  This is the *first day of the lunar month* containing `iso_days`.
  Raises the exception `find_phasis_on_or_before/3` would return.

  """
  @spec phasis_on_or_before(integer(), Geo.PointZ.t(), method()) :: integer()
  def phasis_on_or_before(iso_days, location, method \\ @default_method) do
    case find_phasis_on_or_before(iso_days, location, method) do
      {:ok, phasis} -> phasis
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Returns the first day of the lunar month containing `iso_days`, as
  `{:ok, iso_days}`, or `{:error, exception}` where Astro finds no first
  sighting: a day more than 50,000 years from J2000, or a crescent not
  seen within 30 evenings of its new moon.

  """
  @spec find_phasis_on_or_before(integer(), Geo.PointZ.t(), method()) ::
          {:ok, integer()} | {:error, Exception.t()}
  def find_phasis_on_or_before(iso_days, location, method \\ @default_method) do
    location
    |> Astro.first_visible_crescent_on_or_before(eve_of(iso_days), method)
    |> day_after_evening(iso_days)
  end

  @doc """
  Returns the ISO day number of the next date on or after `iso_days`
  on the eve of which the crescent moon first becomes visible at
  `location`.

  This is the first day of the next lunar month, or `iso_days` itself
  if it is the first day of a month. Raises the exception
  `find_phasis_on_or_before/3` would return.

  """
  @spec phasis_on_or_after(integer(), Geo.PointZ.t(), method()) :: integer()
  def phasis_on_or_after(iso_days, location, method \\ @default_method) do
    result =
      location
      |> Astro.first_visible_crescent_on_or_after(eve_of(iso_days), method)
      |> day_after_evening(iso_days)

    case result do
      {:ok, phasis} -> phasis
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Returns whether the crescent moon was theoretically visible at
  `location` on the eve of `iso_days`, using `method` (`:odeh`,
  `:yallop`, or `:schaefer`): an evening with no sunset has no
  sighting.

  """
  @spec visible_crescent?(integer(), Geo.PointZ.t(), method()) :: boolean()
  def visible_crescent?(iso_days, location, method \\ @default_method) do
    case Astro.new_visible_crescent(location, eve_of(iso_days), method) do
      {:ok, visibility} -> visibility in [:A, :B, :C]
      {:error, :no_sunset} -> false
    end
  end

  @doc false
  # The first day of the month `iso_days` is in, `{:ok, iso_days}`, read
  # from the months' first days: `first_day_of.(elapsed_months)` answers
  # `{:ok, first_day}` or an error, as a calendar's kept month starts do.
  # The search starts at `elapsed_months`, the month a day's distance from
  # the epoch gives, and steps to the month the day is in. `:error` where
  # it does not settle or a month's first day is not found, and the caller
  # then seeks the crescent from the day itself. A month has 29 days at
  # least, from one first sighting to the next, so a day fewer than 29 days
  # after its month's first day is in it, and the next month's first day is
  # worked out only for the days after.
  @spec month_start_on_or_before(integer(), integer(), (integer() -> {:ok, integer()} | term())) ::
          {:ok, integer()} | :error
  def month_start_on_or_before(iso_days, elapsed_months, first_day_of) do
    settle_month(iso_days, elapsed_months, first_day_of, @month_walk_limit)
  end

  defp settle_month(_iso_days, _elapsed_months, _first_day_of, 0), do: :error

  defp settle_month(iso_days, elapsed_months, first_day_of, limit) do
    case first_day_of.(elapsed_months) do
      {:ok, first_day} when iso_days < first_day ->
        settle_month(iso_days, elapsed_months - 1, first_day_of, limit - 1)

      {:ok, first_day} when iso_days - first_day < @shortest_month ->
        {:ok, first_day}

      {:ok, first_day} ->
        in_month_or_after(iso_days, elapsed_months, first_day, first_day_of, limit)

      _not_found ->
        :error
    end
  end

  # A day a month or more after its month's first day is in that month only
  # if the next month has not begun.
  defp in_month_or_after(iso_days, elapsed_months, first_day, first_day_of, limit) do
    case first_day_of.(elapsed_months + 1) do
      {:ok, next_first_day} when iso_days >= next_first_day ->
        settle_month(iso_days, elapsed_months + 1, first_day_of, limit - 1)

      {:ok, _next_first_day} ->
        {:ok, first_day}

      _not_found ->
        :error
    end
  end

  # The evening before `iso_days`, when its Islamic day begins.
  defp eve_of(iso_days) do
    Date.from_gregorian_days(iso_days - 1)
  end

  # A month begins the day after the evening its crescent is first seen.
  defp day_after_evening({:ok, evening}, _iso_days) do
    {:ok, Date.to_gregorian_days(evening) + 1}
  end

  defp day_after_evening({:error, reason}, iso_days) do
    {:error, Calendrical.Base.Astro.error(reason, __MODULE__, Date.from_gregorian_days(iso_days))}
  end
end
