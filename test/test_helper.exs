Application.put_env(:localize, :default_locale, :en)

# The CLDR 49 locale data is not on the CDN yet. A Localize checkout beside
# this one generates the test locales from the CLDR sources when its own
# tests run, so read them from its cache when it is present.
localize_locales = Path.expand("../../localize/priv/localize/locales", __DIR__)

if File.dir?(localize_locales) do
  Application.put_env(:localize, :locale_cache_dir, localize_locales)
end

# Every territory's reform calendar is a composite compiled at runtime
# through the one `Calendrical.Compiler` server, which compiles one module
# at a time. Building them here, before any test runs, keeps the tests
# that sweep every reform from queueing on the server inside their
# timeout; `Calendrical.Reform.calendar_for/1` then returns the loaded
# module.
for {territory, _reform} <- Calendrical.Reform.reforms() do
  {:ok, _calendar} = Calendrical.Reform.calendar_for(territory)
end

# The :full tag marks exhaustive sweeps (the lunisolar round trips
# cover every day from 1800 to 2025, ~2.5 minutes of CPU). They are
# excluded from default runs so the suite stays fast and other tests
# are not starved toward their timeouts; run them with
# `mix test --include full`. CI includes them on the lint entry.
#
# The :known_failure tag marks a law of the calendar contract an existing
# calendar is known to break (test/calendrical/laws_test.exs), each with
# its reason, for the user to rule on; run them with
# `mix test --include known_failure`.
ExUnit.start(exclude: [:full, :known_failure])
