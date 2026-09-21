# Dialyzer exclusions for Calendrical.
#
# `mix.exs` enables the strict flag set Localize uses — `:underspecs`,
# `:extra_range` and `:missing_return` — so that any new imprecision
# in a spec is caught. There are currently no exclusions: every
# warning the flags surfaced has been fixed at the source. The fixes
# worth knowing about when adding code:
#
# * Exported arithmetic guards its integer arguments; an unguarded
#   exported function is typed over any() inputs, so `x + 1` alone
#   admits float() into the inferred range.
#
# * Integer accumulation uses explicit recursion, not `Enum.reduce`;
#   a higher-order fold types its accumulator as any().
#
# * ISO day conversion goes through the spec'd public
#   `Calendar.ISO.naive_datetime_to_iso_days/7`, not the spec-less
#   internal `Calendar.ISO.date_to_iso_days/3`.
#
# * `Localize.Utils.Math.mod/2` and `amod/2` carry overloaded
#   contracts (integer in, integer out).
#
# * Territory week data (first day, minimum days) is read from
#   Localize's runtime data behind an `in 1..7` domain guard rather
#   than compiled into clause heads, so the specs state the domain
#   and the success typing agrees.
[]
