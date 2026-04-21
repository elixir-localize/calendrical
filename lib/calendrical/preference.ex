defmodule Calendrical.Preference do
  @moduledoc """
  Resolves the preferred Calendrical calendar module for a CLDR locale or an
  ISO 3166 territory.

  CLDR ships preference rankings that say, for any given territory, which
  calendar systems are most appropriate to use. This module turns those
  rankings into actual Elixir module names by walking the preference list and
  returning the first calendar whose Calendrical implementation is loaded in
  the current build.

  The two main entry points are:

  * `calendar_from_territory/1` — given an ISO 3166 territory code, return the
    preferred calendar module.

  * `calendar_from_locale/1` — given a CLDR locale, return the preferred
    calendar module. Honours the `-u-ca-` BCP 47 calendar extension and the
    `-u-fw-` first-day-of-week extension when present.

  In every case, if no calendar in the preference list is available, the
  module falls back to `Calendrical.Gregorian` (the default calendar), which
  is always present.

  ## Optional calendar packages

  Some calendar implementations only ship if their dependencies are loaded —
  for example, the lunisolar calendars require `Astro`. The runtime
  `Code.ensure_loaded?/1` checks in this module exist precisely so that the
  preference resolver gracefully degrades when an optional calendar is not
  available in the current build.

  """

  alias Localize.LanguageTag

  # The calendar_from_locale/1 function clauses use pattern matching on
  # %LanguageTag{locale: %{calendar: nil}} which narrows the struct type
  # beyond what Localize.Territory.territory_from_locale/1's spec expects.
  # This is safe because the function accepts any LanguageTag struct.
  @dialyzer {:nowarn_function, calendar_from_locale: 1}

  @base_calendar Calendrical
  @territory_preferences Localize.SupplementalData.calendar_preferences()

  @days [1, 2, 3, 4, 5, 6, 7]
  @day_codes [:mon, :tue, :wed, :thu, :fri, :sat, :sun]
  @first_day Enum.zip([@day_codes, @days]) |> Map.new()

  @doc false
  def territory_preferences do
    @territory_preferences
  end

  @doc false
  def preferences_for_territory(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      territory_preferences = territory_preferences()
      {:ok, default_territory} = Localize.Territory.territory_from_locale(Localize.get_locale())
      the_world = Localize.Territory.the_world()

      preferences =
        Map.get(territory_preferences, territory) ||
          Map.get(territory_preferences, default_territory) ||
          Map.get(territory_preferences, the_world)

      {:ok, preferences}
    end
  end

  @doc """
  Returns the Calendrical calendar module preferred for the given territory.

  Walks the CLDR territory preference list and returns the first calendar
  whose Calendrical implementation is loaded in the current build. If no
  preferred calendar is loaded, falls back to `Calendrical.Gregorian`.

  ### Arguments

  * `territory` is any valid ISO 3166 alpha-2 code as a `t:String.t/0` or an
    upcased `t:atom/0` (e.g. `:US`, `:IR`, `:JP`).

  ### Returns

  * `{:ok, calendar_module}` on success.

  * `{:error, exception}` if the territory is unknown.

  ### Examples

      iex> Calendrical.Preference.calendar_from_territory(:US)
      {:ok, Calendrical.US}

      iex> {:error, %Localize.UnknownTerritoryError{}} =
      ...>   Calendrical.Preference.calendar_from_territory(:YY)

  ### Notes

  The overwhelming majority of territories have `:gregorian` as their first
  preferred calendar, so `Calendrical.Gregorian` is returned for most
  territories.

  Returning any other calendar module requires both that another calendar is
  preferred over `:gregorian` for the territory, and that the corresponding
  Calendrical implementation is loaded. For example, Iran (`:IR`) prefers the
  `:persian` calendar, so `Calendrical.Persian` is returned (the Persian
  calendar is built into Calendrical and always available).

  """
  def calendar_from_territory(territory) when is_atom(territory) do
    with {:ok, preferences} <- preferences_for_territory(territory),
         {:ok, calendar_module} <- find_calendar(preferences) do
      if calendar_module == Calendrical.default_calendar() do
        Calendrical.calendar_for_territory(territory)
      else
        {:ok, calendar_module}
      end
    end
  end

  def calendar_from_territory(territory, calendar) when is_atom(territory) do
    with {:ok, preferences} <- preferences_for_territory(territory),
         {:ok, calendar_module} <- find_calendar(preferences, calendar) do
      if calendar_module == Calendrical.default_calendar() do
        Calendrical.calendar_for_territory(territory)
      else
        {:ok, calendar_module}
      end
    end
  end

  @deprecated "Use calendar_from_territory/1"
  defdelegate calendar_for_territory(territory), to: __MODULE__, as: :calendar_from_territory

  defp find_calendar(preferences) do
    error = {:error, Calendrical.unknown_calendar_error(preferences)}

    Enum.reduce_while(preferences, error, fn calendar, acc ->
      module = calendar_module(calendar)

      if Code.ensure_loaded?(module) do
        {:halt, {:ok, module}}
      else
        {:cont, acc}
      end
    end)
  end

  defp find_calendar(preferences, calendar) do
    if preferred = Enum.find(preferences, &(&1 == calendar)) do
      find_calendar([preferred])
    else
      find_calendar(preferences)
    end
  end

  @doc """
  Returns the Calendrical calendar module preferred for the given locale.

  Honours the BCP 47 `-u-ca-` calendar extension and the `-u-fw-` first-day-
  of-week extension when present in the locale identifier. If no calendar
  extension is supplied, falls back to the territory preference list (see
  `calendar_from_territory/1`).

  ### Arguments

  * `locale` is a locale identifier atom, string, or a
    `t:Localize.LanguageTag.t/0`. The default is `Localize.get_locale/0`.

  ### Returns

  * `{:ok, calendar_module}` on success.

  * `{:error, exception}` if the locale is invalid.

  ### Examples

      iex> Calendrical.Preference.calendar_from_locale(:"en-GB")
      {:ok, Calendrical.GB}

      iex> Calendrical.Preference.calendar_from_locale("en-GB-u-ca-gregory")
      {:ok, Calendrical.GB}

      iex> Calendrical.Preference.calendar_from_locale(:en)
      {:ok, Calendrical.US}

      iex> Calendrical.Preference.calendar_from_locale("en-u-ca-iso8601")
      {:ok, Calendrical.US}

      iex> Calendrical.Preference.calendar_from_locale("en-u-fw-mon")
      {:ok, Calendrical.US}

      iex> Calendrical.Preference.calendar_from_locale(:"fa-IR")
      {:ok, Calendrical.Persian}

      iex> Calendrical.Preference.calendar_from_locale("fa-IR-u-ca-gregory")
      {:ok, Calendrical.Persian}

  """
  def calendar_from_locale(locale \\ Localize.get_locale())

  # If no calendar is specified but the first day of the week is Monday then
  # the behaviour is the same as the gregorian calendar. This can be useful
  # to override the behaviour of territories where the week is defined.
  # to start on a Sunday.

  def calendar_from_locale(%LanguageTag{locale: %{calendar: nil, fw: :mon}}) do
    {:ok, Calendrical.Gregorian}
  end

  def calendar_from_locale(%LanguageTag{locale: %{calendar: nil, fw: first_day}})
      when first_day in @day_codes do
    {:ok, day} = Map.fetch(@first_day, first_day)
    module = first_day |> Atom.to_string() |> String.capitalize() |> String.to_atom()
    calendar_module = Module.concat([@base_calendar, Gregorian, module])
    Calendrical.new(calendar_module, :month, day_of_week: day)
  end

  def calendar_from_locale(%LanguageTag{locale: %{calendar: nil}} = locale) do
    with {:ok, territory} <- territory_from(locale) do
      calendar_from_territory(territory)
    end
  end

  def calendar_from_locale(%LanguageTag{locale: %{calendar: calendar}} = locale) do
    calendar_module = Map.get(calendar_modules(), calendar)

    if calendar_module && Code.ensure_loaded?(calendar_module) do
      {:ok, calendar_module}
    else
      with {:ok, territory} <- territory_from(locale) do
        calendar_from_territory(territory, calendar)
      end
    end
  end

  def calendar_from_locale(%LanguageTag{} = locale) do
    with {:ok, territory} <- Localize.Territory.territory_from_locale(locale) do
      calendar_from_territory(territory)
    end
  end

  def calendar_from_locale(locale) when is_binary(locale) or is_atom(locale) do
    with {:ok, locale} <- Localize.validate_locale(locale) do
      calendar_from_locale(locale)
    end
  end

  def calendar_from_locale(other) do
    {:error, Localize.InvalidLocaleError.exception(locale_id: other)}
  end

  @dialyzer {:nowarn_function, territory_from: 1}
  defp territory_from(%LanguageTag{} = locale) do
    Localize.Territory.territory_from_locale(locale)
  end

  @deprecated "Use calendar_from_locale/1"
  defdelegate calendar_for_locale(locale), to: __MODULE__, as: :calendar_from_locale

  @known_calendars Localize.known_calendars()

  # CLDR calendar types whose Calendrical module name is not a direct
  # CamelCase of the type atom. Mostly nested modules (Islamic variants,
  # Ethiopic.AmeteAlem) and the Korean lunisolar calendar which uses the
  # `:dangi` CLDR type.
  @calendar_module_overrides %{
    islamic: Calendrical.Islamic.Observational,
    islamic_civil: Calendrical.Islamic.Civil,
    islamic_rgsa: Calendrical.Islamic.Rgsa,
    islamic_tbla: Calendrical.Islamic.Tbla,
    islamic_umalqura: Calendrical.Islamic.UmmAlQura,
    ethiopic_amete_alem: Calendrical.Ethiopic.AmeteAlem,
    dangi: Calendrical.Korean
  }

  @calendar_modules @known_calendars
                    |> Enum.map(fn c ->
                      {c,
                       Module.concat(@base_calendar, c |> Atom.to_string() |> Macro.camelize())}
                    end)
                    |> Map.new()
                    |> Map.merge(@calendar_module_overrides)
                    |> Map.put(:iso8601, Calendrical.ISOWeek)

  @doc false
  def calendar_modules do
    @calendar_modules
  end

  @doc false
  def calendar_module(calendar) when calendar in @known_calendars do
    Map.fetch!(calendar_modules(), calendar)
  end

  def calendar_module(:iso8601) do
    Calendrical.ISOWeek
  end

  def calendar_module(other) do
    {:error, Calendrical.unknown_calendar_error(other)}
  end

  @doc false
  def calendar_from_name(name) do
    calendar_module = calendar_module(name)

    if Code.ensure_loaded?(calendar_module) do
      calendar_module
    else
      nil
    end
  end
end
