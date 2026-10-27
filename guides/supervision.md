# Supervision

Calendrical runs two processes, both under `Calendrical.Supervisor`:

* `Calendrical.YearCache` owns the table in which the calendars reckoned by astronomy (the Persian, lunisolar and observational Islamic calendars) keep what they work out about a year.

* `Calendrical.Compiler` creates the calendars made at runtime, such as a territory's reform calendar or a calendar made with `Calendrical.new/3`, one at a time.

Once they are running, the supervisor registers Calendrical with Localize as the provider of its calendars, so that a locale's `-u-ca-` extension names a Calendrical calendar.

By default this supervisor is started when the `:calendrical` application starts, and there is nothing to do. This guide is for an application that prefers to start Calendrical in its own supervision tree, as Localize allows too, typically to control the order in which it starts relative to the application's own processes.

## The default: started with the application

```elixir
def deps do
  [
    {:calendrical, "~> 2.2"}
  ]
end
```

The `:calendrical` application starts at boot, after Localize and Astro, which it depends on, and `Calendrical.Supervisor` is its supervisor.

## Supervising Calendrical yourself

Mark the dependency `runtime: false`, so that Mix compiles Calendrical but does not start it:

```elixir
def deps do
  [
    {:calendrical, "~> 2.2", runtime: false}
  ]
end
```

Then add `Calendrical.Supervisor` to the application's children. `{Calendrical.Supervisor, []}` is the same; there are no options.

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      Localize.Supervisor,
      Astro.Supervisor,
      Calendrical.Supervisor,
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

### Calendrical's own dependencies

With Calendrical not started, neither are the applications it depends on, and its calendars need two of them:

* **Localize** formats, parses and localizes dates. Start it with `Localize.Supervisor`, as above, or depend on `:localize` directly so its application starts. Its [supervision guide](https://hexdocs.pm/localize/supervision.html) describes the first.

* **Astro** loads the JPL ephemeris that the calendars reckoned by astronomy compute from. List `Astro.Supervisor` before `Calendrical.Supervisor`, as above, to start it yourself. Otherwise `Calendrical.Supervisor` starts the `:astro` application as it starts, when neither that application nor `Astro.Supervisor` is running, and returns `{:error, {:astro_not_started, reason}}` if it cannot, as when the ephemeris cannot be found.

### Ordering

List `Calendrical.Supervisor` before any process that uses a calendar as it starts, and `Astro.Supervisor`, when you list it, before `Calendrical.Supervisor`. Starting Calendrical needs nothing from Localize, but using the calendars does, so list `Localize.Supervisor` before the processes that use them.

### Releases

A dependency marked `runtime: false` is left out of a release unless the release names it. Name Calendrical to be loaded, which loads its dependencies with it:

```elixir
def project do
  [
    app: :my_app,
    releases: [
      my_app: [applications: [calendrical: :load]]
    ]
  ]
end
```

### What happens when a process stops

`Calendrical.Supervisor` restarts a process that stops, each on its own. A restarted `Calendrical.YearCache` starts with an empty table, so the calendars work out each year again the first time they are asked about it. Their answers are the same.

### Checking

Once the application is started, `Calendrical.Supervisor` is among its children, with Calendrical's processes below it:

```elixir
iex> MyApp.Supervisor |> Supervisor.which_children() |> Enum.map(&elem(&1, 0))
[MyAppWeb.Endpoint, Calendrical.Supervisor, Astro.Supervisor, Localize.Supervisor, MyApp.Repo]

iex> Calendrical.Supervisor |> Supervisor.which_children() |> Enum.map(&elem(&1, 0))
[Calendrical.Compiler, Calendrical.YearCache]
```

Starting `Calendrical.Supervisor` while the `:calendrical` application also runs fails with `{:already_started, pid}`, as the supervisor is registered under its name: use one or the other.

## Which to choose

Starting with the application is right for almost every project. Supervising Calendrical yourself is right when it must start in a particular order relative to the application's own processes. Calendrical behaves the same either way: the same processes, the same cache and the same calendars.
