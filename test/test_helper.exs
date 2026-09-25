Application.put_env(:localize, :default_locale, :en)

# The CLDR 49 locale data is not on the CDN yet. A Localize checkout beside
# this one generates the test locales from the CLDR sources when its own
# tests run, so read them from its cache when it is present.
localize_locales = Path.expand("../../localize/priv/localize/locales", __DIR__)

if File.dir?(localize_locales) do
  Application.put_env(:localize, :locale_cache_dir, localize_locales)
end

# The :full tag marks exhaustive sweeps (the lunisolar round trips
# cover every day from 1800 to 2025, ~2.5 minutes of CPU). They are
# excluded from default runs so the suite stays fast and other tests
# are not starved toward their timeouts; run them with
# `mix test --include full`. CI includes them on the lint entry.
ExUnit.start(exclude: [:full])
