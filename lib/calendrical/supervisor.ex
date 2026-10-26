defmodule Calendrical.Supervisor do
  @moduledoc """
  The `:calendrical` runtime supervisor.

  Owns the processes Calendrical needs at runtime and registers
  Calendrical with Localize as the provider of its calendars:

  * `Calendrical.YearCache` owns the table in which the calendars
    reckoned by astronomy keep what they work out about a year.

  * `Calendrical.Compiler` creates the calendars made at runtime, such
    as a territory's reform calendar or a calendar made with
    `Calendrical.new/3`, one at a time.

  This supervisor is started when the `:calendrical` application starts,
  so most applications need do nothing. An application that prefers to
  start Calendrical alongside its own processes can turn that off and
  add this supervisor to its own supervision tree instead.

  ## Supervising Calendrical yourself

  Mark the dependency `runtime: false` in `mix.exs`, so that the
  `:calendrical` application is not started:

      # mix.exs
      def deps do
        [
          {:calendrical, "~> 2.0", runtime: false}
        ]
      end

  Then add the supervisor to the application's tree, after
  `Localize.Supervisor` when Localize is supervised the same way:

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          MyApp.Repo,
          Calendrical.Supervisor,
          MyAppWeb.Endpoint
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end

  Calendrical's own dependencies are then not started either, and its
  calendars need two of them: Localize, and Astro, whose application
  loads the JPL ephemeris the calendars reckoned by astronomy use.
  The [supervision guide](supervision.html) describes how to start
  them, and what a release needs.

  """

  @doc """
  Starts the Calendrical supervisor.

  Starts `Calendrical.YearCache` and `Calendrical.Compiler`, then
  registers `Calendrical` as Localize's calendar provider, which
  `Localize.Calendar.register_provider/1` describes. Registering again
  is harmless. The supervisor is registered as `Calendrical.Supervisor`.

  ### Arguments

  * `options` is a keyword list.

  ### Options

  * There are none. `options` is accepted so that
    `{Calendrical.Supervisor, []}` can be listed as a child.

  ### Returns

  * `{:ok, pid}` on success.

  * `{:error, reason}` if the supervisor or a child could not be
    started.

  ### Examples

  Calendrical starts this supervisor itself. Start it only when the
  `:calendrical` application is not started:

  ```elixir
  children = [
    {Calendrical.Supervisor, []}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
  ```

  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options \\ []) when is_list(options) do
    children = [
      Calendrical.YearCache,
      Calendrical.Compiler
    ]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__) do
      after_start()
      {:ok, pid}
    end
  end

  @doc """
  Returns the specification to start `Calendrical.Supervisor` under
  another supervisor.

  Lets an application list `Calendrical.Supervisor`, or
  `{Calendrical.Supervisor, []}`, among its own children.

  ### Arguments

  * `options` is a keyword list passed to `start_link/1`.

  ### Options

  * There are none. See `start_link/1`.

  ### Returns

  * A `t:Supervisor.child_spec/0` map.

  ### Examples

      iex> Calendrical.Supervisor.child_spec([])
      %{
        id: Calendrical.Supervisor,
        start: {Calendrical.Supervisor, :start_link, [[]]},
        type: :supervisor
      }

  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(options \\ []) when is_list(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      type: :supervisor
    }
  end

  # A CLDR calendar type names no calendar module of its own, and Localize
  # ships `Calendar.ISO` alone, so a value in that calendar has no family to
  # ask for the calendar a locale's `-u-ca-` names. Registering answers for
  # it: `Calendrical.calendar_from_cldr_calendar_type/1` maps the type to the
  # calendar that keeps it. Done here, not in the application, so that it is
  # done however the supervisor is started.
  defp after_start do
    Localize.Calendar.register_provider(Calendrical)
  end
end
