# Dialyzer exclusions for Calendrical.
#
# `mix.exs` enables the strict flag set Localize uses — `:underspecs`,
# `:extra_return` and `:missing_return` — so that any *new* imprecision
# in a spec is caught. The entries below are the cases where satisfying
# those flags would make the published contract worse rather than
# better. Each is verified, not assumed; every genuine defect the flags
# surfaced has been fixed rather than listed here.
#
# Remove an entry if the underlying code changes so that it no longer
# warrants an exclusion.
#
# ── 1. Float over-approximation (`missing_range`) ──────────────────
#
# Calendar arithmetic runs through helpers that use `:math.floor/1` and
# `:math.ceil/1`, whose results are truncated before use. Dialyzer
# cannot see that the truncation always happens, so it concludes these
# functions can return `float()` where the spec says `integer()`.
#
# Each was called at runtime and returns an integer:
#
#     Calendrical.Hebrew.date_to_iso_days(5785, 1, 1)     #=> 739527
#     Calendrical.Indian.date_to_iso_days(1947, 1, 1)     #=> 739697
#     Calendrical.Islamic.UmmAlQura.date_to_iso_days(1446, 1, 1) #=> 739439
#     Calendrical.Chinese.cyclic_year(2024, 1)            #=> 44
#     Calendrical.Chinese.day_of_year(2024, 1, 1)         #=> 1
#     Calendrical.Gregorian.day_of_year(2024, 3, 1)       #=> 61
#
# Silencing these by scattering no-op `trunc/1` calls through the
# calendar arithmetic would obscure the mathematics for no runtime
# benefit. The one case where the float was real — an `:math.ceil/1`
# that leaked a float month out of `Calendrical.Persian` — was a genuine
# defect and is fixed.
#
# `day_of_year/3`, `days_in_month/2` and `cyclic_year/2` are generated
# by `Calendrical.Behaviour` and `Calendrical.Compiler.Month`, so the
# warning is reported against the `use`/`defmodule` line of each
# calendar rather than a function definition.
#
# ── 2. Deliberately abstract specs (`contract_supertype`) ──────────
#
# `:underspecs` reports a spec that is broader than what dialyzer can
# currently infer. In these cases the breadth is the point:
#
# * `Calendrical.default_calendar/0` is spec'd `calendar()` and returns
#   whatever is configured; dialyzer only sees the `Gregorian` default
#   because it cannot model runtime configuration.
#
# * `Calendrical.Islamic.UmmAlQura.min_year/0` and `max_year/0` are
#   spec'd `pos_integer()`. They are years, not the literals `1356` and
#   `1500` that the current tabular data happens to bound them to.
#
# * The `Visibility` and `Lunisolar` astronomical helpers are spec'd in
#   terms of `Astro` types rather than the raw numbers they reduce to.
#
# ── 3. Domain types wider than current data (`extra_range`) ────────
#
# `first_day_for_locale/1` and `first_day_for_territory/1` are spec'd
# `1..7` — a day of the week. Today's CLDR data only yields `1, 5, 6, 7`,
# and `min_days_for_*` only `1, 4`. Narrowing the specs to the values
# present in this CLDR release would be wrong: they are day-of-week and
# minimum-days values, and a future CLDR release may use others.
[
  # 1. Float over-approximation in calendar arithmetic.
  {"lib/calendrical.ex", :missing_range, 4040},
  {"lib/calendrical/calendars/chinese.ex", :missing_range, 66},
  {"lib/calendrical/calendars/chinese.ex", :missing_range, 631},
  {"lib/calendrical/calendars/gregorian.ex", :missing_range, 3},
  {"lib/calendrical/calendars/hebrew.ex", :missing_range, 355},
  {"lib/calendrical/calendars/indian.ex", :missing_range, 281},
  {"lib/calendrical/calendars/islamic/tabular.ex", :missing_range, 47},
  {"lib/calendrical/calendars/islamic/umm_al_qura/umm_al_qura.ex", :missing_range, 231},
  {"lib/calendrical/calendars/iso.ex", :missing_range, 3},
  {"lib/calendrical/calendars/korean.ex", :missing_range, 52},
  {"lib/calendrical/calendars/korean.ex", :missing_range, 450},
  {"lib/calendrical/calendars/lunar_japanese.ex", :missing_range, 75},
  {"lib/calendrical/calendars/lunar_japanese.ex", :missing_range, 552},

  # 2. Deliberately abstract specs.
  {"lib/calendrical.ex", :contract_supertype, 515},
  {"lib/calendrical/calendars/islamic/umm_al_qura/umm_al_qura.ex", :contract_supertype, 126},
  {"lib/calendrical/calendars/islamic/umm_al_qura/umm_al_qura.ex", :contract_supertype, 133},
  {"lib/calendrical/calendars/islamic/visibility.ex", :contract_supertype, 34},
  {"lib/calendrical/calendars/islamic/visibility.ex", :contract_supertype, 61},
  {"lib/calendrical/compiler/lunisolar.ex", :contract_supertype, 668},
  {"lib/calendrical/fiscal_years.ex", :contract_supertype, 117},
  {"lib/calendrical/format.ex", :contract_supertype, 37},

  # 3. Domain types wider than the current CLDR data.
  {"lib/calendrical.ex", :extra_range, 2326},
  {"lib/calendrical.ex", :extra_range, 2365},
  {"lib/calendrical.ex", :extra_range, 2472},
  {"lib/calendrical.ex", :extra_range, 2500}
]
