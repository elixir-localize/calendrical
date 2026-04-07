defmodule Calendrical.Islamic.Visibility do
  @moduledoc false

  # Shared crescent-visibility algorithms for the *observational*
  # Islamic calendars defined in `Calendrical.Islamic.Observational`
  # (Cairo) and `Calendrical.Islamic.Rgsa` (Mecca).
  #
  # The algorithms here are translations of `phasis-on-or-before` and
  # `phasis-on-or-after` from Dershowitz & Reingold, *Calendrical
  # Calculations* (4th ed., chapter 14), but the underlying
  # `visible_crescent?/2` predicate is delegated to the new-crescent
  # visibility models implemented by the `Astro` library
  # (`Astro.new_visible_crescent/3`) rather than to Reingold's
  # `shaukat-criterion`.
  #
  # The Astro library implements three visibility criteria — Yallop
  # (1997), Odeh (2006), and Schaefer (1988/2000) — and returns one
  # of `:A`, `:B`, `:C`, `:D`, `:E` indicating the strength of the
  # prediction. We treat `:A`/`:B`/`:C` as "visible" (the crescent is
  # at least theoretically observable, possibly with optical aid) and
  # `:D`/`:E` as "not visible". Odeh is used by default because it is
  # the most modern empirical fit and is the basis for several
  # national Islamic calendar committees.

  @default_method :odeh

  @doc """
  Returns the ISO day number of the most recent date on or before
  `iso_days` on the eve of which the crescent moon was first visible
  at `location`.

  This is the *first day of the lunar month* containing `iso_days`.
  """
  @spec phasis_on_or_before(integer(), Geo.PointZ.t(), atom()) :: integer()
  def phasis_on_or_before(iso_days, location, method \\ @default_method) do
    moon_iso = prior_new_moon_iso_days(iso_days)
    age = iso_days - moon_iso

    tau =
      if age <= 3 and not visible_crescent?(iso_days, location, method) do
        # Eve of the input date is so soon after the new moon that no
        # crescent could be visible yet — the lunar month containing
        # this date must have started ~30 days earlier.
        moon_iso - 30
      else
        moon_iso
      end

    next_visible_crescent(tau, location, method)
  end

  @doc """
  Returns the ISO day number of the next date on or after `iso_days`
  on the eve of which the crescent moon first becomes visible at
  `location`.

  This is the *first day of the next lunar month* if `iso_days` is
  itself the first day of a month, or the first day of the lunar
  month containing `iso_days + 30` otherwise.
  """
  @spec phasis_on_or_after(integer(), Geo.PointZ.t(), atom()) :: integer()
  def phasis_on_or_after(iso_days, location, method \\ @default_method) do
    moon_iso = prior_new_moon_iso_days(iso_days)
    age = iso_days - moon_iso

    tau =
      if age >= 4 or visible_crescent?(iso_days - 1, location, method) do
        # Either the date is well past the prior new moon (so the
        # current month's first visibility is already past) or the
        # crescent was already visible the day before — either way,
        # we want the *next* lunar month, ~29 days after the prior
        # new moon.
        moon_iso + 29
      else
        iso_days
      end

    next_visible_crescent(tau, location, method)
  end

  @doc """
  Returns whether the crescent moon was theoretically visible at
  `location` on the eve of `iso_days`, using `method` (`:odeh`,
  `:yallop`, or `:schaefer`).

  """
  @spec visible_crescent?(integer(), Geo.PointZ.t(), atom()) :: boolean()
  def visible_crescent?(iso_days, location, method \\ @default_method) do
    date = Date.from_gregorian_days(iso_days)

    case Astro.new_visible_crescent(location, date, method) do
      {:ok, v} when v in [:A, :B, :C] -> true
      _ -> false
    end
  end

  # Walk forward day by day from `iso_days` until the crescent is
  # visible. The search is bounded so that a missing-data condition
  # cannot loop forever — under any reasonable visibility model the
  # crescent must be visible within ~5 days of the new moon.
  defp next_visible_crescent(iso_days, location, method, fuel \\ 60)

  defp next_visible_crescent(_iso_days, _location, _method, 0),
    do: raise("Calendrical.Islamic.Visibility: no visible crescent found within bounded search")

  defp next_visible_crescent(iso_days, location, method, fuel) do
    if visible_crescent?(iso_days, location, method) do
      iso_days
    else
      next_visible_crescent(iso_days + 1, location, method, fuel - 1)
    end
  end

  # Floor of the ISO day on which the most recent geocentric new moon
  # falls (in UTC). The Astro library returns a UTC `DateTime`; we
  # take the calendar date of that instant.
  defp prior_new_moon_iso_days(iso_days) do
    date = Date.from_gregorian_days(iso_days)
    {:ok, datetime} = Astro.date_time_new_moon_before(date)

    datetime
    |> DateTime.to_date()
    |> Date.to_gregorian_days()
  end
end
