# Calendar Summary

This guide describes every CLDR-aligned calendar that ships with Calendrical, grouped by the underlying mechanism. For each calendar it gives the CLDR identifier, the epoch, the month structure, the leap-year rule, and a worked reference date so you can verify a conversion in `iex`.

The 17 CLDR-acceptable calendar types are all implemented. Each section below cites the corresponding CLDR identifier and the Calendrical module that exposes it.

---

## Gregorian calendars

These are calendars whose month and day structure is identical to (or derived from) the proleptic Gregorian calendar. They differ only in their **week structure** or in their **year numbering**.

### Month-based Gregorian calendars

A *month-based* Gregorian calendar lays out years as 12 months of 28–31 days following the proleptic Gregorian rule. Date arithmetic and the leap-year rule are inherited from `Calendar.ISO`. They differ from each other only in **year numbering** and in **which month starts the calendar year** (for fiscal calendars).

| Calendar | CLDR | Year offset | First month | Notes |
|---|---|---|---|---|
| `Calendrical.Gregorian` | `:gregorian` | none | January | The base calendar. Wraps `Calendar.ISO` and adds CLDR localization. |
| `Calendrical.ISO` | (n/a) | none | January | Identical to `Calendrical.Gregorian` but uses the ISO-8601 4-day rule for week-of-year. |
| `Calendrical.Buddhist` | `:buddhist` | +543 | January | Thai Buddhist Era (BE). 1 BE = -542 proleptic Gregorian (= 543 BCE). 2024 CE = 2567 BE. |
| `Calendrical.Roc` | `:roc` | -1911 | January | Republic of China (Minguo). 1 ROC = 1912 CE. 2024 CE = 113 ROC. Used officially in Taiwan. |
| `Calendrical.Japanese` | `:japanese` | none | January | Same arithmetic as `Calendrical.Gregorian` but advertises Japanese era data (Reiwa, Heisei, Shōwa, …) for localization. |
| `Calendrical.NRF` | (n/a, week) | none | January | US National Retail Federation 4-4-5 fiscal calendar. *Week-based*: see below. |
| `Calendrical.FiscalYear.<TERR>` | (n/a) | none | configurable | Pre-built fiscal calendars for 50+ territories (US Oct 1 → Sep 30, AU Jul 1 → Jun 30, …). |

**Worked example.** Buddhist year 2567:

```elixir
iex> {:ok, gregorian} = Date.new(2024, 1, 1, Calendrical.Gregorian)
iex> {:ok, buddhist} = Date.convert(gregorian, Calendrical.Buddhist)
iex> buddhist
~D[2567-01-01 Calendrical.Buddhist]
```

### Week-based Gregorian calendars

A *week-based* Gregorian calendar lays out years as a fixed number of **52 (or 53) seven-day weeks** rather than 12 calendar months. Each "month" is a contiguous block of weeks (typically 4 or 5) so that quarters always have an exact number of complete weeks. The two share the same proleptic Gregorian day numbering as the month-based calendars but expose a very different period structure.

| Calendar | CLDR | Layout | Year start rule |
|---|---|---|---|
| `Calendrical.ISOWeek` | (n/a) | 52/53 ISO-8601 weeks. Each week starts on Monday. | The week containing 4 January (i.e. the first week with at least 4 days in the new Gregorian year). |
| `Calendrical.NRF` | (n/a) | 52/53 weeks in a 4-4-5 / 4-5-4 / 5-4-4 quarter pattern. Each week starts on Sunday. | The Sunday closest to 1 February. |

The key differences between month- and week-based Gregorian calendars:

| Aspect | Month-based | Week-based |
|---|---|---|
| Year length | 365 or 366 days | Always a multiple of 7 days (364 or 371) |
| Period unit | Calendar month (28–31 days) | Logical "month" of 28 or 35 days made up of contiguous weeks |
| Year numbering | Same as Gregorian (with offsets) | The year that contains the most weeks |
| Quarter alignment | Quarters span 90–92 days | Quarters always span exactly 13 weeks |
| Use case | Civil calendars, holidays | Retail, finance, broadcast, and any domain that needs week-aligned reporting |

Both kinds use exactly the same `date_to_iso_days/3` and `date_from_iso_days/1` arithmetic to map to the proleptic Gregorian day count, so a date in either kind round-trips through `Date.convert/2` correctly with all other Calendrical calendars.

---

## Julian calendars

These calendars use the proleptic Julian rule "every fourth year is a leap year" with no centurial exception. They share a single set of date-arithmetic primitives, but differ in **the day on which the year begins**, which affects how a Gregorian-style date corresponds to a Julian year.

| Calendar | Year start | Notes |
|---|---|---|
| `Calendrical.Julian` | January 1 | Astronomical / proleptic Julian. The default. |
| `Calendrical.Julian.Jan1` | January 1 | Same as `Calendrical.Julian`. |
| `Calendrical.Julian.March1` | March 1 | The "*Annunciation Style* (March 1)" historical convention used by the Byzantine Empire and parts of Russia. |
| `Calendrical.Julian.March25` | March 25 | The "*Lady Day*" / *Annunciation Style (March 25)* used by England until 1751 and several other Western European countries. |
| `Calendrical.Julian.Sept1` | September 1 | The Byzantine *Anno Mundi* style. |
| `Calendrical.Julian.Dec25` | December 25 | The *Nativity Style* used in some medieval European chronicles. |

**Leap-year rule (all variants).** A Julian year `y` is a leap year when `rem(y, 4) == 0`. Note that this is the proleptic rule applied without the Gregorian centurial exception, so 1900 *is* a Julian leap year.

The historical year-start variants are useful for reading and writing dates from medieval and early-modern documents. They are also the building blocks for `Calendrical.Composite` (see below) when constructing a calendar that transitioned from Julian to Gregorian on a specific date.

**Worked example.**

```elixir
iex> {:ok, julian} = Date.new(2024, 1, 1, Calendrical.Julian)
iex> {:ok, gregorian} = Date.convert(julian, Calendrical.Gregorian)
iex> gregorian
~D[2024-01-14 Calendrical.Gregorian]
```

---

## Solar, lunar, and lunisolar calendars

The remaining CLDR calendars are not derived from Gregorian or Julian. They are grouped here by their underlying astronomical mechanism.

### Solar (non-Gregorian)

A **solar** calendar tracks the tropical year (the time between successive vernal equinoxes) but does not use the Gregorian/Julian leap-year rule. Each implementation has its own tropical-year approximation and its own month layout.

| Calendar | CLDR | Algorithm | Year length |
|---|---|---|---|
| `Calendrical.Persian` | `:persian` | Astronomical: each Hijri-Shamsi year starts on the Gregorian day on which the vernal equinox occurs in Tehran. Uses `Astro.equinox/2`. | 365 or 366 days |
| `Calendrical.Indian` | `:indian` | Algorithmic, year-offset over Gregorian. Saka year = Gregorian year − 78, but with custom month names and a distinct month structure (Chaitra–Phalguna). | 365 or 366 days |
| `Calendrical.Coptic` | `:coptic` | 13-month year (12 × 30 days + Pi Kogi Enavot of 5 or 6 days). Tabular: leap years are `rem(year, 4) == 3`. Day 1 of year 1 is 29 August 284 CE Julian. | 365 or 366 days |
| `Calendrical.Ethiopic` | `:ethiopic` | Same 13-month layout and leap-year rule as Coptic. Era of Mercy starts 29 August 8 CE Julian. | 365 or 366 days |
| `Calendrical.Ethiopic.AmeteAlem` | `:ethiopic_amete_alem` | Same algorithm as `Calendrical.Ethiopic` with a year offset of +5500 (the *Era of the World*). | 365 or 366 days |

**Worked example (Persian).**

```elixir
iex> {:ok, persian} = Date.new(1403, 1, 1, Calendrical.Persian)
iex> {:ok, gregorian} = Date.convert(persian, Calendrical.Gregorian)
iex> gregorian
~D[2024-03-20 Calendrical.Gregorian]
```

### Lunar

A **lunar** calendar tracks the synodic month (the ~29.5-day cycle of lunar phases) but does *not* attempt to stay aligned with the tropical year. Twelve lunar months are about 354 days, so a lunar calendar drifts ~11 days per year against the seasons.

The Islamic family is the only CLDR-supported lunar calendar family. All five variants share the same month names (Muharram → Dhuʻl-Hijjah) and year numbering (Anno Hegirae) but differ in how they decide which Gregorian day each lunar month begins on.

#### Islamic calendars

| Calendar | CLDR | Method | Epoch | Notes |
|---|---|---|---|---|
| `Calendrical.Islamic.Civil` | `:islamic_civil` | **Tabular**, *civil* (Friday) epoch | Friday 16 July 622 Julian = 19 July 622 proleptic Gregorian | Standard arithmetic Hijri calendar. 30-year cycle with 11 leap years (Type II *Kūshyār*: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29). |
| `Calendrical.Islamic.Tbla` | `:islamic_tbla` | **Tabular**, *astronomical* (Thursday) epoch | Thursday 15 July 622 Julian = 18 July 622 proleptic Gregorian | Same algorithm as `Civil` but the epoch is one day earlier. *TBLA* = "tabular based on lunar astronomy". |
| `Calendrical.Islamic.UmmAlQura` | `:islamic_umalqura` | **Precomputed table** of KACST official month-start dates (van Gent dataset) | 1 Muharram 1 AH = 19 July 622 (notional) | The official Saudi civil calendar. Coverage 1356 AH–1500 AH (1937–2076 CE). Out-of-range dates raise `Calendrical.IslamicYearOutOfRangeError`. |
| `Calendrical.Islamic.UmmAlQura.Astronomical` | (alternative for `:islamic_umalqura`) | **Astronomical** (sunset/moonset at Mecca) using the KACST visibility rules | (notional) | Computes the official Umm al-Qura rule from astronomy on demand. Available as a research / validation tool; the canonical UmmAlQura calendar uses the precomputed table. |
| `Calendrical.Islamic.Observational` | `:islamic` | **Astronomical** (crescent visibility at Cairo) using `Astro.new_visible_crescent/3` (Odeh 2006) | (notional) | The "generic" CLDR `:islamic` calendar. Implements `phasis-on-or-before` from Reingold but uses the modern Odeh visibility model rather than Shaukat. |
| `Calendrical.Islamic.Rgsa` | `:islamic_rgsa` | **Astronomical** (crescent visibility at Mecca) | (notional) | The Saudi *religious sighting* calendar. Same algorithm as `Observational` but observed at al-Masjid al-Ḥarām. May diverge from `UmmAlQura` in months where the astronomical prediction does not match the KACST table. |

All Islamic calendars share the same 12-month layout:

| # | Name | Tabular days |
|---|---|---|
| 1 | Muharram | 30 |
| 2 | Safar | 29 |
| 3 | Rabiʻ I | 30 |
| 4 | Rabiʻ II | 29 |
| 5 | Jumada I | 30 |
| 6 | Jumada II | 29 |
| 7 | Rajab | 30 |
| 8 | Shaʻban | 29 |
| 9 | Ramadan | 30 |
| 10 | Shawwal | 29 |
| 11 | Dhuʻl-Qiʻdah | 30 |
| 12 | Dhuʻl-Hijjah | 29 / 30 (leap) |

In the observational and Umm al-Qura variants, individual months may be 29 or 30 days based on actual lunar visibility, so the table above only describes `Civil` and `Tbla`.

**Worked example.**

```elixir
iex> {:ok, gregorian} = Date.new(2025, 3, 1, Calendrical.Gregorian)
iex> {:ok, hijri} = Date.convert(gregorian, Calendrical.Islamic.UmmAlQura)
iex> hijri
~D[1446-09-01 Calendrical.Islamic.UmmAlQura]

iex> Calendrical.localize(hijri, :month, locale: "en")
"Ramadan"
```

### Lunisolar

A **lunisolar** calendar tracks the synodic month *and* keeps the year aligned with the tropical year by inserting a leap (or *embolismic*) month every two or three years. The result is a year of either 12 months (~354 days) or 13 months (~384 days), with month boundaries on the new moon.

| Calendar | CLDR | Algorithm | Leap rule |
|---|---|---|---|
| `Calendrical.Hebrew` | `:hebrew` | **Arithmetic** (Reingold) | 19-year Metonic cycle: years 3, 6, 8, 11, 14, 17, 19 are leap. Public API uses the CLDR Tishri = 1 numbering with month 6 (Adar I) only valid in leap years. |
| `Calendrical.Chinese` | `:chinese` | **Astronomical** (lunar phase + winter solstice at Beijing/China longitude) | Inserts a 13th leap month between the new moons that contain no major solar term. Uses the `Astro` library. |
| `Calendrical.Korean` | `:dangi` | **Astronomical** (lunar phase + winter solstice at Seoul longitude) | Same algorithm as `Calendrical.Chinese` but observed from Seoul. The CLDR identifier `:dangi` refers to the *Dangi* era starting 2333 BCE. |
| `Calendrical.LunarJapanese` | `:chinese` (shared) | **Astronomical** (lunar phase + winter solstice at Japan-standard-time longitude) | The historical Japanese lunisolar calendar used until 1873, when Japan switched to the proleptic Gregorian. |

**Year length.** All four lunisolar calendars produce year lengths of **353, 354, 355, 383, 384, or 385** days (Hebrew is restricted to these specific lengths by additional *dehiyyah* postponement rules; the Chinese family permits the full range).

**Worked example (Hebrew).**

```elixir
iex> {:ok, hebrew} = Date.new(5784, 1, 1, Calendrical.Hebrew)  # 1 Tishri 5784
iex> {:ok, gregorian} = Date.convert(hebrew, Calendrical.Gregorian)
iex> gregorian
~D[2023-09-16 Calendrical.Gregorian]

iex> {:ok, passover} = Date.new(5784, 8, 15, Calendrical.Hebrew)  # 15 Nisan
iex> {:ok, gregorian} = Date.convert(passover, Calendrical.Gregorian)
iex> gregorian
~D[2024-04-23 Calendrical.Gregorian]
```

---

## Composite calendars

A **composite** calendar uses one base calendar before a specified date and a different calendar afterwards. This is the canonical way to model the historical Julian-to-Gregorian transition for individual countries, where the calendar in use literally changed on a known date and a window of "missing" days appeared in the historical record.

| Calendar | Module | Description |
|---|---|---|
| User-defined | `Calendrical.Composite` | The `defmacro __using__` template that builds a composite calendar from a list of transition dates. |
| Pre-built | `Calendrical.England` | Demonstrates Britain's three transitions: 1155 (March 25 year-start), 1751 (January 1 year-start), 1752 (Julian → Gregorian, dropping 11 days). |
| Pre-built | `Calendrical.Russia` | The Russian calendar: Julian (March 1 year-start) → Julian (September 1 year-start, 1492) → Julian (January 1 year-start, 1700) → Gregorian (1918, dropping 13 days). |

**Worked example (England, 1752 transition).**

```elixir
iex> day_before = ~D[1752-09-02 Calendrical.England]
iex> Date.shift(day_before, day: 1)
~D[1752-09-14 Calendrical.England]
```

The 11 "missing" days (3 September 1752 through 13 September 1752) are not valid dates in the English composite calendar — `Calendrical.England.valid_date?(1752, 9, 5)` returns `false`.

See [`calendar_behaviour.md`](calendar_behaviour.md) for the syntax of `use Calendrical.Composite`.

---

## Ecclesiastical calendars

The `Calendrical.Ecclesiastical` module is not a calendar in the `Calendar` behaviour sense — it does not implement `date_to_iso_days/3` or `valid_date?/3` and is not registered as a CLDR calendar type. Instead, it provides functions that, given a Gregorian year, return the dates of the principal Christian liturgical events for that year. The algorithms are taken from Dershowitz & Reingold, *Calendrical Calculations* (4th ed.), Chapter 9 ("Ecclesiastical Calendars").

### Three Easter traditions

Calendrical exposes three different *Easter* computations because they really are three distinct calculations. The differences are small in most years (and the three frequently coincide) but the underlying definitions and target audiences are different.

| Function | Method | Calendar | Used by |
|---|---|---|---|
| `easter_sunday/1` | Gregorian *computus* (tabular) | `Calendrical.Gregorian` | Roman Catholic, Anglican, most Protestants |
| `astronomical_easter_sunday/1` | **Astronomical** Paschal Full Moon + first Sunday after | `Calendar.ISO` (UTC) | "Astronomical Easter" — proposed by the World Council of Churches in 1997, no Church follows it |
| `orthodox_easter_sunday/1` | Julian *computus* (tabular) | `Calendrical.Julian` | Eastern Orthodox |

Western Easter and Orthodox Easter coincide in years like **2025**; they can differ by one, four, or five weeks in other years because the Western (Gregorian) and Eastern (Julian) computus use different lookup tables and different leap-year rules. The astronomical reckoning agrees with the Western Gregorian computus for most years in the 21st century but is not actually used by any Church — it is included for comparison and research.

### Movable feasts (Western)

Western (Roman Catholic, Anglican, most Protestants). All return `Calendrical.Gregorian` dates.

| Function | Returns | Notes |
|---|---|---|
| `easter_sunday/1` | Western Easter Sunday | Gregorian *computus*. |
| `good_friday/1` | Western Good Friday | Two days before `easter_sunday/1`. |
| `pentecost/1` | Western Pentecost Sunday (Whitsunday) | 49 days after `easter_sunday/1`. |
| `advent/1` | Western Advent Sunday | The Sunday closest to 30 November. |

### Movable feasts (Eastern Orthodox)

All return `Calendrical.Julian` dates so the calendar context is visible in the result.

| Function | Returns | Notes |
|---|---|---|
| `orthodox_easter_sunday/1` | Orthodox Easter Sunday | Julian *computus*. |
| `orthodox_good_friday/1` | Orthodox Good Friday | Two days before `orthodox_easter_sunday/1`. |
| `orthodox_pentecost/1` | Orthodox Pentecost Sunday | 49 days after `orthodox_easter_sunday/1`. |
| `orthodox_advent/1` | Start of the Eastern Orthodox *Nativity Fast* | **Fixed** at 15 November (Julian) — a 40-day Lenten preparation. The Orthodox tradition does not have a movable "Advent Sunday" equivalent. |

### Movable feasts (astronomical, WCC 1997)

The World Council of Churches' 1997 Aleppo proposal for unifying Western and Eastern Easter. **No Church currently follows it.** All return `Calendar.ISO` dates and are restricted to year range 1000..3000.

| Function | Returns | Notes |
|---|---|---|
| `astronomical_easter_sunday/1` | `{:ok, Date}` for Astronomical Easter | First Sunday strictly after the astronomical Paschal Full Moon. |
| `astronomical_good_friday/1` | `{:ok, Date}` for Astronomical Good Friday | Two days before `astronomical_easter_sunday/1`. |
| `paschal_full_moon/1` | `{:ok, Date}` for the astronomical Paschal Full Moon | The first astronomical full moon on or after the March vernal equinox, computed via `Astro.equinox/2` and `Astro.date_time_lunar_phase_at_or_after/2`. May differ by a day from the *ecclesiastical* PFM used by the Western or Eastern computus. |

### Fixed feasts

| Function | Returns | Notes |
|---|---|---|
| `christmas/1` | The Gregorian date of Western Christmas Day | Always 25 December. |
| `epiphany/1` | The Gregorian date of Epiphany (US observance) | The first Sunday after 1 January. The traditional fixed-date Epiphany on 6 January is more widely observed elsewhere. |
| `eastern_orthodox_christmas/1` | A list of zero, one, or two Gregorian dates | 25 December Julian projected onto the proleptic Gregorian calendar. May fall in either January or December of the requested Gregorian year. |
| `coptic_christmas/1` | A list of zero, one, or two Gregorian dates | 29 Koiak in the Coptic calendar projected onto the proleptic Gregorian calendar. |

**Worked example.**

```elixir
iex> Calendrical.Ecclesiastical.easter_sunday(2024)
~D[2024-03-31 Calendrical.Gregorian]

iex> Calendrical.Ecclesiastical.orthodox_easter_sunday(2024)
~D[2024-04-22 Calendrical.Julian]

# Project onto Gregorian: Orthodox Easter 2024 = May 5 Gregorian
iex> {:ok, gregorian} =
...>   Date.convert(
...>     Calendrical.Ecclesiastical.orthodox_easter_sunday(2024),
...>     Calendrical.Gregorian
...>   )
iex> gregorian
~D[2024-05-05 Calendrical.Gregorian]

iex> Calendrical.Ecclesiastical.pentecost(2025)
~D[2025-06-08 Calendrical.Gregorian]

iex> Calendrical.Ecclesiastical.orthodox_pentecost(2025)
~D[2025-05-26 Calendrical.Julian]

iex> Calendrical.Ecclesiastical.advent(2025)
~D[2025-11-30 Calendrical.Gregorian]

iex> Calendrical.Ecclesiastical.orthodox_advent(2025)
~D[2025-11-15 Calendrical.Julian]
```
