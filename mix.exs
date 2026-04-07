defmodule Calendrical.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :calendrical,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Calendrical",
      description: description(),
      package: package(),
      docs: docs(),
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

  def package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/elixir-localize/calendrical",
      "Readme" => "https://github.com/elixir-localize/calendrical/blob/v#{@version}/README.md",
      "Changelog" =>
        "https://github.com/elixir-localize/calendrical/blob/v#{@version}/CHANGELOG.md"
    }
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      logo: "logo.png",
      extras:
        [
          "README.md",
          "LICENSE.md",
          "CHANGELOG.md"
        ] ++ Path.wildcard("guides/*.md"),
      formatters: ["html", "markdown"],
      groups_for_modules: groups_for_modules(),
      groups_for_extras: groups_for_extras(),
      skip_undefined_reference_warnings_on:
        [
          "CHANGELOG.md"
        ] ++ Path.wildcard("guides/*.md")
    ]
  end

  def groups_for_modules do
    [
      "Gregorian Month-based Calendars": ~r/^Calendrical\.(Gregorian|ISO|Buddhist|Japanese|Roc)$/,
      "Gregorian Week-based Calendars": ~r/^Calendrical\.(ISOWeek|NRF|)$/,
      "Lunisolar Calendars": ~r/^Calendrical\.(Chinese|Korean|LunarJapanese|Hebrew)$/,
      "Ethiopic Calendars": ~r/^Calendrical\.Ethiopic(\.AmeteAlem)?$/,
      "Islamic Calendars":
        ~r/^Calendrical\.Islamic\.(Civil|Tbla|Observational|Rgsa|UmmAlQura.ReferenceData|UmmAlQura(\.Astronomical)?)$/,
      "Julian Calendars": ~r/^Calendrical\.Julian(\.(Jan1|March1|March25|Sept1|Dec25))?$/,
      "ISO Calendars": ~r/^Calendrical\.(ISO|k)?$/,
      "Ecclesiastical Calendars": ~r/Calendrical.Ecclesiastical/,
      "Other Calendars": ~r/^Calendrical\.(Indian|Persian|Composite|Coptic)$/,
      Behaviours: [Calendrical.Behaviour, Calendrical.Formatter],
      Eras: ~r/^Calendrical.Era/,
      Exceptions: ~r/^Calendrical\.\w+Error$/
    ]
  end

  defp groups_for_extras do
    [
      Guides: [
        "guides/calendar_summary.md",
        "guides/calendar_behaviour.md",
        "guides/migration.md"
      ]
    ]
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
      {:astro, "~> 2.0"},
      {:tz_world, "~> 1.0", optional: true},
      {:tzdata, "~> 1.1", optional: true},
      {:gettext, "~> 1.0"},
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
