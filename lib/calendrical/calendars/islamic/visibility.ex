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
  Raises `Calendrical.UnsupportedDateRangeError` when the installed
  ephemeris does not cover the search.
  """
  @spec phasis_on_or_before(integer(), Geo.PointZ.t(), method()) :: integer()
  def phasis_on_or_before(iso_days, location, method \\ @default_method) do
    case find_phasis_on_or_before(iso_days, location, method) do
      {:ok, phasis} -> phasis
      {:error, date} -> unsupported!(date)
    end
  end

  @doc """
  Returns the first day of the lunar month containing `iso_days`, as
  `{:ok, iso_days}`, or `{:error, date}` naming a date the installed
  ephemeris does not cover.
  """
  @spec find_phasis_on_or_before(integer(), Geo.PointZ.t(), method()) ::
          {:ok, integer()} | {:error, Date.t()}
  def find_phasis_on_or_before(iso_days, location, method \\ @default_method) do
    with {:ok, moon_iso} <- prior_new_moon_iso_days(iso_days),
         {:ok, tau} <- phasis_search_start(iso_days, moon_iso, location, method) do
      next_visible_crescent(tau, location, method)
    end
  end

  # When the eve of the input date is so soon after the new moon that no
  # crescent could be visible yet, the lunar month containing this date
  # must have started ~30 days earlier.
  defp phasis_search_start(iso_days, moon_iso, location, method) when iso_days - moon_iso <= 3 do
    case crescent_visible(iso_days, location, method) do
      {:ok, true} -> {:ok, moon_iso}
      {:ok, false} -> {:ok, moon_iso - 30}
      {:error, _date} = error -> error
    end
  end

  defp phasis_search_start(_iso_days, moon_iso, _location, _method), do: {:ok, moon_iso}

  @doc """
  Returns the ISO day number of the next date on or after `iso_days`
  on the eve of which the crescent moon first becomes visible at
  `location`.

  This is the *first day of the next lunar month* if `iso_days` is
  itself the first day of a month, or the first day of the lunar
  month containing `iso_days + 30` otherwise. Raises
  `Calendrical.UnsupportedDateRangeError` when the installed ephemeris
  does not cover the search.
  """
  @spec phasis_on_or_after(integer(), Geo.PointZ.t(), method()) :: integer()
  def phasis_on_or_after(iso_days, location, method \\ @default_method) do
    case find_phasis_on_or_after(iso_days, location, method) do
      {:ok, phasis} -> phasis
      {:error, date} -> unsupported!(date)
    end
  end

  defp find_phasis_on_or_after(iso_days, location, method) do
    with {:ok, moon_iso} <- prior_new_moon_iso_days(iso_days),
         {:ok, tau} <- next_phasis_search_start(iso_days, moon_iso, location, method) do
      next_visible_crescent(tau, location, method)
    end
  end

  # Either the date is well past the prior new moon (so the current
  # month's first visibility is already past) or the crescent was already
  # visible the day before — either way, we want the *next* lunar month,
  # ~29 days after the prior new moon.
  defp next_phasis_search_start(iso_days, moon_iso, _location, _method)
       when iso_days - moon_iso >= 4,
       do: {:ok, moon_iso + 29}

  defp next_phasis_search_start(iso_days, moon_iso, location, method) do
    case crescent_visible(iso_days - 1, location, method) do
      {:ok, true} -> {:ok, moon_iso + 29}
      {:ok, false} -> {:ok, iso_days}
      {:error, _date} = error -> error
    end
  end

  @doc """
  Returns whether the crescent moon was theoretically visible at
  `location` on the eve of `iso_days`, using `method` (`:odeh`,
  `:yallop`, or `:schaefer`). Raises
  `Calendrical.UnsupportedDateRangeError` when the installed ephemeris
  does not cover the date.

  """
  @spec visible_crescent?(integer(), Geo.PointZ.t(), method()) :: boolean()
  def visible_crescent?(iso_days, location, method \\ @default_method) do
    case crescent_visible(iso_days, location, method) do
      {:ok, visible?} -> visible?
      {:error, date} -> unsupported!(date)
    end
  end

  # A date the ephemeris does not cover at all is an error rather than
  # "not visible": treating missing data as invisibility would silently
  # walk the crescent search forward and produce wrong month boundaries.
  defp crescent_visible(iso_days, location, method) do
    date = Date.from_gregorian_days(iso_days)

    case Astro.new_visible_crescent(location, date, method) do
      {:ok, visibility} -> {:ok, visibility in [:A, :B, :C]}
      {:error, :not_found} -> {:error, date}
      _no_sighting -> {:ok, false}
    end
  end

  # Walk forward day by day from `iso_days` until the crescent is
  # visible. The search is bounded: under any reasonable visibility
  # model the crescent is visible within ~5 days of the new moon, so a
  # search that runs out is treated as missing data.
  defp next_visible_crescent(iso_days, location, method, fuel \\ 60)

  defp next_visible_crescent(iso_days, _location, _method, 0),
    do: {:error, Date.from_gregorian_days(iso_days)}

  defp next_visible_crescent(iso_days, location, method, fuel) do
    case crescent_visible(iso_days, location, method) do
      {:ok, true} -> {:ok, iso_days}
      {:ok, false} -> next_visible_crescent(iso_days + 1, location, method, fuel - 1)
      {:error, _date} = error -> error
    end
  end

  # The ISO day on which the most recent geocentric new moon falls (in
  # UTC). The Astro library returns a UTC `DateTime`; we take the
  # calendar date of that instant.
  defp prior_new_moon_iso_days(iso_days) do
    date = Date.from_gregorian_days(iso_days)

    case Astro.date_time_new_moon_before(date) do
      {:ok, datetime} -> {:ok, datetime |> DateTime.to_date() |> Date.to_gregorian_days()}
      {:error, _reason} -> {:error, date}
    end
  end

  @spec unsupported!(Date.t()) :: no_return()
  defp unsupported!(date) do
    raise Calendrical.UnsupportedDateRangeError,
      value: date,
      range: "dates covered by the installed JPL ephemeris"
  end
end
