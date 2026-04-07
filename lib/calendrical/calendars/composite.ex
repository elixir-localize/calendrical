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

  The `:base_calendar` option indicates the calendar in use before
  any of the configured transitions. It defaults to
  `Calendrical.Julian`.

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

  When a transition skips dates (for example the British transition
  on 14 September 1752 dropped the eleven days 3 September 1752
  through 13 September 1752), the composite calendar treats those
  dates as **invalid**:

      iex> Calendrical.England.valid_date?(1752, 9, 5)
      false

      iex> Date.shift(~D[1752-09-02 Calendrical.England], day: 1)
      ~D[1752-09-14 Calendrical.England]

  """

  alias Calendrical.Composite.Config

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      require Calendrical.Composite.Compiler

      @options options
      @before_compile Calendrical.Composite.Compiler
    end
  end

  @doc """
  Creates a new composite calendar at runtime.

  ## Arguments

  * `calendar_module` is the module name to be created. This will
    be the name of the new composite calendar if it is successfully
    created.

  * `options` is a keyword list of options. See
    `Calendrical.Composite` for the supported options.

  ## Returns

  * `{:ok, module}` or

  * `{:module_already_exists, calendar_module}`

  ## Examples

      iex> Calendrical.Composite.new(MyApp.Denmark,
      ...>   calendars: [~D[1700-03-01 Calendrical.Gregorian]])
      {:ok, MyApp.Denmark}

  """
  @spec new(module(), Keyword.t()) ::
          {:ok, Calendrical.calendar()} | {:module_already_exists, module()}
  def new(calendar_module, options) when is_atom(calendar_module) and is_list(options) do
    if Code.ensure_loaded?(calendar_module) do
      {:module_already_exists, calendar_module}
    else
      create_calendar(calendar_module, options)
    end
  end

  defp create_calendar(calendar_module, config) do
    with {:ok, config} <- Config.validate_options(config) do
      contents =
        quote do
          use unquote(__MODULE__),
              unquote(Macro.escape(config))
        end

      {:module, module, _, :ok} =
        Module.create(calendar_module, contents, Macro.Env.location(__ENV__))

      {:ok, module}
    end
  end
end
