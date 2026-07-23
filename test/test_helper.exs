Application.put_env(:localize, :default_locale, :en)

# The :full tag marks exhaustive sweeps (the lunisolar round trips
# cover every day from 1800 to 2025, ~2.5 minutes of CPU). They are
# excluded from default runs so the suite stays fast and other tests
# are not starved toward their timeouts; run them with
# `mix test --include full`. CI includes them on the lint entry.
ExUnit.start(exclude: [:full])
