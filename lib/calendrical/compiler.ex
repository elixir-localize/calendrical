defmodule Calendrical.Compiler do
  @moduledoc false

  use GenServer
  alias Calendrical.Config

  # Creating a calendar macro-expands the full month/week compiler
  # quote block, which can take well over the 5-second GenServer
  # default on a cold or loaded system.
  @compile_timeout :timer.seconds(30)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def create_calendar(calendar_module, calendar_type, config) do
    config = Keyword.put(config, :calendar, calendar_module)
    structured_config = Config.extract_options(config)

    with {:ok, config} <- Config.validate_config(structured_config, calendar_type) do
      calendar_type =
        calendar_type
        |> to_string
        |> String.capitalize()

      config =
        config
        |> Map.from_struct()
        |> Map.to_list()

      contents =
        quote do
          use unquote(Module.concat(Calendrical.Base, calendar_type)),
              unquote(Macro.escape(config))
        end

      GenServer.call(
        __MODULE__,
        {:compile, calendar_module, contents, Macro.Env.location(__ENV__)},
        @compile_timeout
      )
    end
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  # Module creation is serialized through this server, and the
  # loaded check is repeated here, so concurrent creation of the
  # same calendar is race-free: the first caller compiles it and
  # later callers take the already-loaded branch. A compilation
  # failure is reported to the caller instead of crashing the
  # server (which would also kill every queued caller).
  @impl true
  def handle_call({:compile, module, contents, env}, _from, state) do
    if Code.ensure_loaded?(module) do
      {:reply, {:ok, module}, state}
    else
      try do
        {:module, ^module, _binary, :ok} = Module.create(module, contents, env)
        {:reply, {:ok, module}, state}
      rescue
        error -> {:reply, {:error, error}, state}
      end
    end
  end
end
