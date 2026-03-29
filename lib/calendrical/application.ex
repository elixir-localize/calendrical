defmodule Calendrical.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Calendrical.Compiler
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
