defmodule Calendrical.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :calendrical,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Calendrical",
      description: description(),
      dialyzer: [
        plt_add_apps: ~w(inets json mix calendar_interval)a
      ],
      compilers: Mix.compilers()
    ]
  end

  defp description do
    """
    Localized month- and week-based calendars and calendar functions
    based upon CLDR data via Localize.
    """
  end

  def application do
    [
      mod: {
        Calendrical.Application,
        [
          strategy: :one_for_one,
          name: Calendrical.Supervisor
        ]
      },
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:localize, path: "../localize"},
      {:calendar_interval, "~> 0.2", optional: true},
      {:ex_doc, "~> 0.21", optional: true, runtime: false},
      {:dialyxir, "~> 1.0", optional: true, only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "bench"]
  defp elixirc_paths(_), do: ["lib"]
end
