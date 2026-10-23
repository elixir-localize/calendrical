# Status

**Status:** release review complete, 2026-10-24

**Next release:** 2.0.0 from `main`
**Blocked on:** nothing. Localize 1.4 and Astro 2.8, which it requires, are on hex.

Calendrical 2.0.0 is built on Localize 1.4 and CLDR 49. `main` is the only branch: the `cldr-49` branch was merged into it on 2026-09-28. The release is 2.0.0 rather than 1.4.0 because every calendar is rebuilt on a kernel of eight callbacks and every error is an exception; the CHANGELOG and the [migration guide](guides/migration.md) list the changes.

Decided 2026-09-28, with Localize: Calendrical is released once, on CLDR 49, so users see one significant release rather than two a fortnight apart.

The release review of 2026-10-24 fixed its findings in the working tree. The judgement calls it left open, such as the composite calendars' `leap_year?/1` in a reform year and England's dateless days of 1155, are recorded in that review rather than here.
