defmodule Calendrical.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # A CLDR calendar type names no calendar module of its own, and Localize
    # ships `Calendar.ISO` alone, so a value in that calendar has no family to
    # ask for the calendar a locale's `-u-ca-` names. Registering here answers
    # for it: `Calendrical.calendar_from_cldr_calendar_type/1` maps the type to
    # the calendar that keeps it.
    Localize.Calendar.register_provider(Calendrical)

    children = [
      Calendrical.Compiler
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
