defmodule Calendrical.Composite do
  @moduledoc """
  A composite calendar uses one base calendar before a specified
  transition date and a different calendar after, optionally chaining
  multiple transitions to model a sequence of historical calendar
  reforms.

  The canonical example is the European transition from the Julian to
  the Gregorian calendar between the 16th and 20th centuries, where
  the calendar in use literally changed on a known date and a window
  of "missing" days appeared in the historical record.

  ## Configuration

  A composite calendar is built by `use`ing this module with a
  `:calendars` option listing the *first* day on which a new calendar
  takes effect. Each entry must be a `Date` literal expressed in the
  calendar that takes effect on that day.

  ```elixir
  defmodule MyApp.England do
    use Calendrical.Composite,
      calendars: [
        ~D[1752-09-14 Calendrical.Gregorian]
      ],
      base_calendar: Calendrical.Julian
  end
  ```

  The `:base_calendar` option indicates the calendar in use before any of the configured transitions. It defaults to `Calendrical.Julian`, and it has no first day: every day before the first transition is a date of it.

  ## Julian to Gregorian transition

  One of the principal uses of this calendar is to define a calendar
  that reflects the historical Julian-to-Gregorian transition for
  individual countries.

  Applicable primarily to western European countries and their
  colonies, the transition occurred between the 16th and 20th
  centuries. A strong reference is the [Perpetual
  Calendar](https://norbyhus.dk/calendar.php) site maintained by
  [Toke Nørby](mailto:Toke.Norby@Norbyhus.dk). [Wikipedia's *Adoption
  of the Gregorian
  calendar*](https://en.wikipedia.org/wiki/Adoption_of_the_Gregorian_calendar)
  page is also useful.

  ## Multiple compositions

  A more complex example chains more than one calendar. For example,
  Egypt used the [Coptic
  calendar](https://en.wikipedia.org/wiki/Coptic_calendar) from 238
  BCE until Rome introduced the Julian calendar in approximately 30
  BCE. The Gregorian calendar was then introduced in 1875. We can
  approximate this with:

  ```elixir
  defmodule MyApp.Egypt do
    use Calendrical.Composite,
      calendars: [
        ~D[-0045-01-01 Calendrical.Julian],
        ~D[1875-09-01 Calendrical.Gregorian]
      ],
      base_calendar: Calendrical.Coptic
  end
  ```

  ## Missing days

  When a transition skips dates (for example the Swedish transition
  in 1753 dropped the eleven days 18 February 1753 through
  28 February 1753), the composite calendar treats those dates as
  **invalid**:

      iex> Calendrical.Reform.Sweden.valid_date?(1753, 2, 20)
      false

      iex> Date.shift(~D[1753-02-17 Calendrical.Reform.Sweden], day: 1)
      ~D[1753-03-01 Calendrical.Reform.Sweden]

  A month a transition cuts short counts only the days that remain, and
  a year runs from whichever day it begins on, so a year that changes
  its first day is shorter or longer than usual:

      iex> Calendrical.Reform.Sweden.days_in_month(1753, 2)
      17

      iex> Calendrical.Reform.England.days_in_year(1751)
      282

  ## Years that begin on another day

  A calendar need not begin its years on 1 January: `Calendrical.Julian.March25` begins them on 25 March and `Calendrical.Julian.Sept1` on 1 September, and its year then holds months that come before the month it begins in.

  A date's year, month and day are read in the calendar they fall in among the transitions, taken in order: the calendar of the last transition they are not before. Where that calendar has no day of the date's year, they are read in the calendar that has. A year reckoned from 1 September that takes effect on 1 September 1492 begins its year 1493 on that day, and the January to August that follow are dates of that year, although they come before September in the order of the months:

      iex> {:ok, muscovy} =
      ...>   Calendrical.Composite.new(MyApp.Muscovy,
      ...>     calendars: [~D[1493-09-01 Calendrical.Julian.Sept1]]
      ...>   )
      iex> Date.new!(1493, 1, 15, muscovy) |> Date.convert!(Calendrical.Julian)
      ~D[1493-01-15 Calendrical.Julian]

  A change to a year that begins later — England's move to Lady Day, 25 March, in 1155 — numbers the days from 1 January to 24 March of the following year with the year that already named the same days a year earlier. Those labels name the earlier days, and the later ones have no label of their own; historians write them with both years ("10 March 1155/6"). A leap day among them has none either: 29 February 1156 would be 29 February 1155, a day the February those labels name does not have.

      iex> Calendrical.Reform.England.valid_date?(1155, 2, 29)
      false

  A change from a year that begins before 1 January to the January year does the same from the other side. A year reckoned from 1 September or 25 December takes the number of the January year it ends in, so where it gives way on 1 January, as Russia's September year did in 1700, its last months already carry the number the new year keeps: those labels name the later days, and September to December 1699 have none of their own.

  ## Arithmetic across a transition

  Years, quarters and months are added in the calendar in effect on the date, a year being as many months as that calendar counts. When the result falls under another calendar the months are counted on through each calendar's own months, from January however a year-start style numbers its years, and a day the resulting month does not have becomes the month's next day that exists, or its last day:

      iex> Date.shift(~D[1752-08-20 Calendrical.Reform.England], month: 1)
      ~D[1752-09-20 Calendrical.Reform.England]

      iex> Date.shift(~D[1752-08-05 Calendrical.Reform.England], month: 1)
      ~D[1752-09-14 Calendrical.Reform.England]

  A change of calendar can begin a month part of the way through it, as England's year 1751 began on 25 March. A month before that day is 25 February, in the year the calendar before it numbered 1750:

      iex> Date.shift(~D[1751-03-25 Calendrical.Reform.England], month: -1)
      ~D[1750-02-25 Calendrical.Reform.England]

  ## Eras

  The era of a date, and its year of the era, are those of the calendar
  in effect on the date. The days of an era are one count through every
  change of calendar the era runs through: from the era's first day, as
  the calendar in effect when it began counts them, or, for an era
  counted back from its last day as the years before the common era
  are, as the calendar in effect when it ended counts them. So the day
  after 2 September 1752 in England is the next day of the common era,
  although the Gregorian calendar begins that era two days after the
  Julian calendar does:

      iex> Calendrical.Reform.England.day_of_era(1752, 9, 2)
      {639798, 1}

      iex> Calendrical.Reform.England.day_of_era(1752, 9, 14)
      {639799, 1}

  An era runs through a change of calendar when the calendars either
  side of it name their eras from the same CLDR calendar and give the
  same era there. Where they do not, as with the Coptic and Julian
  calendars of Egypt above, each calendar's days of its era are its own.

  The Islamic calendars are of that kind: each names its eras from a
  CLDR calendar of its own, so a composite of two of them keeps each
  one's count of the Hijri era. The counts agree but for
  `Calendrical.Islamic.Tbla`, which begins the era a day before the
  others. Where another Islamic calendar follows it a day of the era is
  counted twice, and where it follows another one is left out.

  """

  alias Calendrical.Composite.Config

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      require Calendrical.Composite.Compiler

      @options options
      @before_compile Calendrical.Composite.Compiler
      @before_compile Calendrical.Compiler.DateCheck
    end
  end

  @doc """
  Creates a new composite calendar at runtime.

  ### Arguments

  * `calendar_module` is the module name to be created. This will
    be the name of the new composite calendar if it is successfully
    created.

  * `options` is a keyword list of options. See
    `Calendrical.Composite` for the supported options.

  ### Options

  * `:calendars` (required) is a list of `Date` literals indicating
    the first day on which a new calendar takes effect. Each entry
    must be expressed in the calendar that takes effect on that day.

  * `:base_calendar` is the calendar in use before any of the
    configured transitions. Defaults to `Calendrical.Julian`.

  ### Returns

  * `{:ok, module}` if the calendar is successfully created, or

  * `{:module_already_exists, calendar_module}` if a module with the same name already exists. Of the processes that create the same calendar at the same moment, one creates it and the others are answered this.

  * `{:error, reason}` if the calendar cannot be created, where `reason` is `:no_calendars_configured`, `:must_be_a_list_of_dates`, or the exception raised by `:calendars` that do not make a calendar.

  ### Examples

      iex> Calendrical.Composite.new(MyApp.Denmark,
      ...>   calendars: [~D[1700-03-01 Calendrical.Gregorian]])
      {:ok, MyApp.Denmark}

  """
  @spec new(module(), Keyword.t()) ::
          {:ok, Calendrical.calendar()}
          | {:module_already_exists, module()}
          | {:error, :must_be_a_list_of_dates | :no_calendars_configured | Exception.t()}
  def new(calendar_module, options) when is_atom(calendar_module) and is_list(options) do
    if Code.ensure_loaded?(calendar_module) do
      {:module_already_exists, calendar_module}
    else
      create_calendar(calendar_module, options)
    end
  end

  # The module is created in the `Calendrical.Compiler` server, as every
  # calendar created at runtime is, one at a time: of the processes that
  # create the same calendar at once, one creates it and the others find
  # it loaded.
  defp create_calendar(calendar_module, config) do
    with {:ok, config} <- Config.validate_options(config) do
      contents =
        quote do
          use unquote(__MODULE__),
              unquote(Macro.escape(config))
        end

      Calendrical.Compiler.create_module(
        calendar_module,
        contents,
        Macro.Env.location(__ENV__)
      )
    end
  end
end
