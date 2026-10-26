defmodule Calendrical.Application do
  @moduledoc false

  use Application

  # The application starts `Calendrical.Supervisor`, which owns every
  # process Calendrical runs and does its one-time work, so an application
  # that starts that supervisor in its own tree runs Calendrical the same.
  @impl true
  def start(_type, _args) do
    Calendrical.Supervisor.start_link([])
  end
end
