defmodule Calendrical.Compiler do
  @moduledoc false

  use GenServer

  # Creating a calendar macro-expands the full month, week or composite
  # compiler quote block, which can take well over the 5-second
  # GenServer default on a cold or loaded system.
  @compile_timeout :timer.seconds(30)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def create_calendar(calendar_module, calendar_type, options)
      when calendar_type in [:month, :week] do
    maker =
      if calendar_type == :month,
        do: Calendrical.Calendar.Shifted,
        else: Calendrical.Calendar.Weeks

    contents =
      quote do
        use unquote(maker), unquote(Macro.escape(options))
      end

    create_module(calendar_module, contents, Macro.Env.location(__ENV__))
  end

  # Creates `module` from its quoted `contents`, in this server. Returns
  # `{:ok, module}` when it is created, and when it is loaded already, as
  # it is for the later of two callers creating the same module at once,
  # and `{:error, exception}` when it does not compile.
  def create_module(module, contents, env) do
    GenServer.call(__MODULE__, {:compile, module, contents, env}, @compile_timeout)
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
        {:module, ^module, _binary, _last} = Module.create(module, contents, env)
        {:reply, {:ok, module}, state}
      rescue
        error -> {:reply, {:error, error}, state}
      end
    end
  end
end
