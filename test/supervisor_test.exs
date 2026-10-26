defmodule Calendrical.SupervisorTest do
  # `Calendrical.Supervisor` owns Calendrical's processes, whether the
  # `:calendrical` application starts it or an application lists it in its
  # own tree. Not async: it stops one of those processes.
  use ExUnit.Case, async: false

  test "the application's supervisor is Calendrical.Supervisor, with its processes" do
    supervisor = Process.whereis(Calendrical.Supervisor)
    assert :application.get_supervisor(:calendrical) == {:ok, supervisor}

    assert Calendrical.Supervisor
           |> Supervisor.which_children()
           |> Enum.map(&elem(&1, 0))
           |> Enum.sort() == [Calendrical.Compiler, Calendrical.YearCache]
  end

  test "Calendrical is Localize's calendar provider" do
    assert Localize.Calendar.calendar_provider() == Calendrical
  end

  test "a process that stops is restarted, and the cache works again" do
    cache = Process.whereis(Calendrical.YearCache)
    reference = Process.monitor(cache)
    Process.exit(cache, :kill)
    assert_receive {:DOWN, ^reference, :process, ^cache, :killed}

    restarted = wait_for(Calendrical.YearCache, cache)
    assert restarted != cache
    assert Calendrical.YearCache.fetch({__MODULE__, :restarted}, fn -> :kept end) == :kept
    assert Calendrical.YearCache.fetch({__MODULE__, :restarted}, fn -> :again end) == :kept

    assert Date.convert(~D[2024-06-01], Calendrical.Persian) ==
             {:ok, ~D[1403-03-12 Calendrical.Persian]}
  end

  # The process registered as `name` once it is not `old`.
  defp wait_for(name, old, attempts \\ 100) do
    case Process.whereis(name) do
      pid when is_pid(pid) and pid != old ->
        pid

      _not_yet when attempts > 0 ->
        Process.sleep(10)
        wait_for(name, old, attempts - 1)
    end
  end
end
