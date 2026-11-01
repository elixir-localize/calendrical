# Status

**Status:** active, 2026-11-01

Calendrical is built on Localize 1.5, CLDR 49 and Astro 2.10 (locked at 2.11); 2.3.0 is on hex (2026-10-31) and 2.4.0 is prepared on `main`. 2.4.0 gives the day-start calendars `day_bounds/1`, a day from the sunset it begins at to the one it ends at, at the calendar's own place, and `time_zone/0`, that place's zone, for Tempo's `Tempo.day_start/1`.

Decided 2026-09-28, with Localize: Calendrical moved to CLDR 49 in one significant release, 2.0.0, rather than two a fortnight apart; the CHANGELOG and the [migration guide](guides/migration.md) list its changes.
