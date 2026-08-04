defmodule Calendrical.Reform do
  @moduledoc """
  Per-territory Julian-to-Gregorian reform calendars.

  Different territories adopted the Gregorian calendar on different dates,
  ranging from the Catholic states in October 1582 to Greece in 1924. A
  historical date is only unambiguous once the territory it belongs to is known.

  This module embeds a table of reform dates keyed by ISO 3166 territory code
  and provides a factory, `calendar_for/1`, that returns a
  `Calendrical.Composite` calendar splicing the Julian calendar before the
  reform and the proleptic Gregorian calendar on and after it (e.g.
  `Calendrical.Reform.GB`), derived automatically from the reform date.

  The factory accepts a territory code (`:GB`) or a `t:Localize.LanguageTag.t/0`,
  from which the territory is derived. The complete table is available from
  `reforms/0`, so callers can inspect exactly how each calendar is generated.

  The reform dates are those shipped by the Unix `ncal(1)` utility (from
  FreeBSD's `usr.bin/ncal/ncal.c`). They record a single Julian-to-Gregorian
  cutover per territory and are, in several cases, a simplification. Treat the
  table as a reasonable default and override it with a hand-written composite
  when a territory needs finer detail.

  ## Accuracy and regional variation

  For far more detailed, source-referenced accounts of when each country and
  region adopted the Gregorian calendar, see Giuseppe Giudice's
  [The adoption of the Gregorian calendar](https://web.archive.org/web/20130315080715/http://dpgi.unina.it/giudice/calendar/Adoption.html)
  (drawing on the *Explanatory Supplement to the Astronomical Ephemeris*,
  Ginzel, Schram and Cappelli) and Claus Tøndering's
  [Calendar FAQ](https://www.tondering.dk/claus/cal/gregorian.php). The `ncal`
  dates agree with both for the territories that had a single national cutover —
  the United Kingdom, France, Italy, Spain, Denmark, Russia, Bulgaria and
  roughly a dozen others.

  Where the `ncal` date is only representative, note:

  * **Politically fragmented territories** adopted the calendar over more than a
    century, by state, canton or province. `Calendrical.Reform.DE` uses the
    Protestant 1700 date, but the Catholic German states changed in 1583–1584;
    `Calendrical.Reform.NL` uses an early Catholic-south 1582 date, though most
    Dutch provinces changed in 1700–1701; `Calendrical.Reform.CH` (1655) matches
    no single major Swiss canton, which ranged from 1584 (Catholic) to 1701
    (Protestant) and later. `AT`, `BE` and `SI` are similar (`SI`'s 1919 is the
    Yugoslav-union date; Slovenia proper was Gregorian from 1583).

  * **`Calendrical.Reform.JP` (Japan) is a poor fit for this model.** Both
    references give Japan's adoption as 1 January 1873, and Japan was never on
    the Julian calendar (it used a lunisolar calendar beforehand), so a
    Julian-to-Gregorian splice does not describe its history. The `ncal` 1918
    date is retained only for parity with the source table; see
    `Calendrical.Reform.Japan` for the correct lunisolar-to-Gregorian model.

  * **`Calendrical.Reform.GR` (Greece)** uses `ncal`'s 1924 date, which is the
    Orthodox church (Revised Julian) reckoning; the Greek *civil* calendar
    changed a year earlier, 16 February 1923 to 1 March 1923.

  * `US`, `AU` and `CA` use the 1752 British-Empire date.

  In particular, `Calendrical.Reform.SE` uses `ncal`'s simplified single 1753
  cutover for Sweden. Sweden's actual history is more complex — it ran a
  transitional calendar from 1700 to 1712, including the only known
  30 February — and is modelled faithfully by `Calendrical.Reform.Sweden`.

  ## Examples

      iex> Calendrical.Reform.calendar_for(:GB)
      {:ok, Calendrical.Reform.GB}

      iex> :SE in Calendrical.Reform.known_territories()
      true

  """

  @reform_data "./priv/calendar_reforms_by_territory.csv"
  @external_resource @reform_data

  # Territory codes come from our own vendored data file, so building atoms
  # from them at compile time is safe (they become existing atoms).
  [_header | rows] =
    @reform_data
    |> File.read!()
    |> String.split(~r/\r?\n/, trim: true)

  @reforms rows
           |> Enum.map(fn row ->
             [code, country, year, month, day] = String.split(row, ",")

             {String.to_atom(code),
              %{
                country: country,
                last_julian:
                  {String.to_integer(year), String.to_integer(month), String.to_integer(day)}
              }}
           end)
           |> Map.new()

  @known_territories @reforms |> Map.keys() |> Enum.sort()

  @doc """
  Returns the sorted list of ISO 3166 territory codes for which a reform
  calendar is available.

  ### Returns

  * A sorted list of atoms (territory codes).

  ### Examples

      iex> territories = Calendrical.Reform.known_territories()
      iex> :GB in territories and :SE in territories
      true

  """
  @spec known_territories() :: [atom(), ...]
  def known_territories do
    @known_territories
  end

  @doc """
  Returns the full reform table, so callers can see exactly how the reform
  calendars are generated.

  ### Returns

  * A map keyed by ISO 3166 territory code. Each value is a map with the
    `:country` name, the `:last_julian` date (a `Calendrical.Julian` date) and
    the `:first_gregorian` date (a `Calendrical.Gregorian` date) — the day
    following the last Julian day.

  ### Examples

      iex> Calendrical.Reform.reforms()[:GB].first_gregorian
      ~D[1752-09-14 Calendrical.Gregorian]

      iex> Calendrical.Reform.reforms()[:SE].last_julian
      ~D[1753-02-17 Calendrical.Julian]

  """
  @spec reforms() :: %{
          atom() => %{country: String.t(), last_julian: Date.t(), first_gregorian: Date.t()}
        }
  def reforms do
    Map.new(@reforms, fn {territory, %{country: country, last_julian: {year, month, day}}} ->
      last_julian = Date.new!(year, month, day, Calendrical.Julian)

      {territory,
       %{
         country: country,
         last_julian: last_julian,
         first_gregorian: first_gregorian(last_julian)
       }}
    end)
  end

  @doc """
  Returns the Julian-to-Gregorian reform dates for a territory.

  ### Arguments

  * `territory` is an ISO 3166 alpha-2 territory code, as an atom (`:GB`) or a
    string (`"GB"`), or a `t:Localize.LanguageTag.t/0` from which the territory
    is derived via `Localize.Territory.territory_from_locale/1`.

  ### Returns

  * `{:ok, %{last_julian: last, first_gregorian: first}}` where `last` is the
    last Julian date in the territory and `first` is the first Gregorian date.

  * `{:error, :unknown_territory}` if the territory has no reform date.

  ### Examples

      iex> Calendrical.Reform.reform_date(:GB)
      {:ok,
       %{
         last_julian: ~D[1752-09-02 Calendrical.Julian],
         first_gregorian: ~D[1752-09-14 Calendrical.Gregorian]
       }}

      iex> Calendrical.Reform.reform_date(:XX)
      {:error, :unknown_territory}

  """
  @spec reform_date(atom() | String.t() | Localize.LanguageTag.t()) ::
          {:ok, %{last_julian: Date.t(), first_gregorian: Date.t()}}
          | {:error, :unknown_territory}
  def reform_date(territory) do
    with {:ok, territory} <- normalize_territory(territory) do
      {year, month, day} = @reforms[territory].last_julian
      last_julian = Date.new!(year, month, day, Calendrical.Julian)

      {:ok,
       %{
         last_julian: last_julian,
         first_gregorian: first_gregorian(last_julian)
       }}
    end
  end

  @doc """
  Returns a Julian-to-Gregorian reform calendar module for the given ISO 3166
  territory code.

  When a territory has a hand-written, historically-detailed calendar, that
  curated module is returned in preference to the `ncal`-derived one. Sweden
  returns `Calendrical.Reform.Sweden` (which models the 1700–1712 transitional
  period and 30 February 1712) and Japan returns `Calendrical.Reform.Japan`
  (a lunisolar-to-Gregorian calendar, since Japan was never on the Julian
  calendar). Every other territory is generated from the reform table.

  The generated calendar module is created on first use and cached as a normal
  Elixir module (e.g. `Calendrical.Reform.GB`). The call is idempotent: later
  calls for the same territory return the same module.

  ### Arguments

  * `territory` is an ISO 3166 alpha-2 territory code, as an atom (`:GB`) or a
    string (`"GB"`), or a `t:Localize.LanguageTag.t/0` from which the territory
    is derived via `Localize.Territory.territory_from_locale/1`.

  ### Returns

  * `{:ok, calendar_module}` where `calendar_module` is a `Calendrical.Composite`
    calendar implementing both the `Calendar` and `Calendrical` behaviours.

  * `{:error, :unknown_territory}` if the territory has no reform date.

  ### Examples

      iex> Calendrical.Reform.calendar_for(:RU)
      {:ok, Calendrical.Reform.RU}

      iex> Calendrical.Reform.calendar_for(:SE)
      {:ok, Calendrical.Reform.Sweden}

      iex> Calendrical.Reform.calendar_for(:JP)
      {:ok, Calendrical.Reform.Japan}

      iex> Calendrical.Reform.calendar_for(:XX)
      {:error, :unknown_territory}

  """
  @spec calendar_for(atom() | String.t() | Localize.LanguageTag.t()) ::
          {:ok, module()} | {:error, :unknown_territory}
  def calendar_for(territory) do
    with {:ok, territory} <- normalize_territory(territory) do
      case Map.fetch(curated_calendars(), territory) do
        {:ok, curated} -> {:ok, curated}
        :error -> generate_calendar(territory)
      end
    end
  end

  # Territories whose history is richer than a single Julian-to-Gregorian
  # cutover are served by a hand-written composite in preference to the
  # `ncal`-derived one.
  defp curated_calendars do
    %{
      SE: Calendrical.Reform.Sweden,
      JP: Calendrical.Reform.Japan
    }
  end

  defp generate_calendar(territory) do
    {year, month, day} = @reforms[territory].last_julian
    last_julian = Date.new!(year, month, day, Calendrical.Julian)

    config = [
      calendars: [first_gregorian(last_julian)],
      base_calendar: Calendrical.Julian
    ]

    Calendrical.Reform
    |> Module.concat(territory)
    |> create_calendar(config)
  end

  defp first_gregorian(last_julian) do
    last_julian
    |> Date.shift(day: 1)
    |> Date.convert!(Calendrical.Gregorian)
  end

  defp create_calendar(module, config) do
    case Calendrical.Composite.new(module, config) do
      {:ok, module} -> {:ok, module}
      {:module_already_exists, module} -> {:ok, module}
      other -> other
    end
  end

  defp normalize_territory(%Localize.LanguageTag{} = locale) do
    # territory_from_locale/1 always resolves a LanguageTag to {:ok, territory},
    # falling back to the default locale's territory when none is present.
    case Localize.Territory.territory_from_locale(locale) do
      {:ok, territory} -> normalize_territory(territory)
    end
  end

  defp normalize_territory(territory) when is_atom(territory) do
    if territory in @known_territories do
      {:ok, territory}
    else
      {:error, :unknown_territory}
    end
  end

  defp normalize_territory(territory) when is_binary(territory) do
    normalize_territory(String.to_existing_atom(String.upcase(territory)))
  rescue
    ArgumentError -> {:error, :unknown_territory}
  end
end
