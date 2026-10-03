# Umm al-Qura astronomical rule against KACST and ICU

**Status:** reference, 2026-10-03

`Calendrical.Islamic.UmmAlQura.Astronomical` implements the Umm al-Qura rule as R. H. van Gent documents it: on the 29th of a month the next day begins a new month when, at Mecca, the conjunction is before sunset and the moon sets after the sun. Against the published tables it is a day early in a third of months, and never late. This records why.

## Findings

* **To 1450 AH the rule is KACST's.** 335 of 336 months of 1423 to 1450 AH begin on KACST's day.

* **From 1451 AH KACST's table follows another rule.** 1451 AH begins in 2029 CE: these are KACST's projected months, not announced ones. 209 of 600 months of 1451 to 1500 AH begin a day after the astronomical calendar's, and ICU4C's table, which this calendar uses for 1501 to 1600 AH, does the same (92 of 287 months of 1501 to 1524 AH).

* **The later rule is stricter.** Every one of those months is one where the moon sets 0 to 19 minutes after the sun on the day the published rule fires. Measured at Mecca's sunset on that day, a month begins the next day when

  * the moon sets at least 19.5 minutes after the sun, or

  * the moon is at least about 18.1 hours past conjunction.

  This reproduces 598 of KACST's 600 months of 1451 to 1500 AH and all 287 of ICU's of 1501 to 1524 AH. It misses 1451/1 (a 2-hour moon setting 2.7 minutes after the sun, begun the next day: the first projected month) and 1472/11 (an 18.8-hour moon setting 16 minutes after the sun, held back a day). Applied to 1423 to 1450 AH it would hold back 116 months KACST begins the next day.

* **Other criteria fit worse.** Alone, of 887 months: moonset lag 12 misses, the moon's geocentric altitude at sunset 18, its topocentric altitude 19, the lag at Riyadh 29, its age 89, its elongation 89. The boundary at 19.5 minutes rather than 20 may be a difference of rise and set conventions (this calendar uses centre-of-disk sunset and moonset with standard refraction).

## Not a crescent-visibility criterion

The obvious astronomical reading, that from 1451 AH a month begins only when the new crescent would be visible from Mecca, does not hold. Yallop's q-test and Odeh's V, at the best time (sunset plus four ninths of the lag), separate the 887 months no better than the lag does, and only at thresholds far below any of their zones: q above -0.62 (17 to 19 misses) where Yallop's lowest zone, not visible even by telescope, is -0.293 (204 misses), and V above -2.5 where Odeh's optical-aid-only zone is -0.96 (88 misses). The tables begin many months on crescents no criterion calls visible.

Nor is it the site: the lag at Riyadh separates worse (29 misses) than at Mecca (12). An error in rise and set conventions cannot make a 19-minute difference; a minute or two at most.

So the later months follow something stricter than the published rule and far laxer than visibility, with a sharp boundary near a 19.5-minute moonset lag. No published criterion is known to match it, and the fitted rule above describes the tables rather than explains them.

## Where ICU's table comes from

* ICU's 1300 to 1600 AH table was contributed in 2013 (ICU-8449, Scott Russell; reviewed by Yoshito Umaoka). Its source states no origin, and ICU4J calls it "an approximation of the Umm al-Qura lunar calendar". ICU did not derive a rule: it carries a table.

* The same table ships with Oracle's JDK as the `Hijrah-umalqura` variant (`hijrah-config-Hijrah-umalqura_islamic-umalqura.properties`, 1300 to 1600 AH, also from 2013); its last year matches ICU's month for month, and neither file nor its documentation names a source.

* KACST's own data agrees with ICU's table on every month of 1300 to 1500 AH (checked here), and with the JDK's on 1356 to 1500 AH (moment-hijri issue #105). So the switch at 1451 AH was already in KACST's data by 2013, when ICU and the JDK took it, and ICU's 1501 to 1600 AH, which follow the later pattern, are most likely the continuation of the same KACST computation. That is an inference: no source found says so.

* van Gent's account of the rules documents the 1423 AH rule and nothing about how projected months are computed.

## Method

Sunset, moonset and conjunction are those `evaluate_era_4_conditions/1` computes on the day before each month the astronomical calendar begins; altitudes from `Astro.Lunar.lunar_altitude/2`, elongation from `Astro.sun_position_at/1` and `Astro.moon_position_at/1`. KACST's months are `Calendrical.Islamic.UmmAlQura`'s for 1 to 1500 AH, and ICU's are its 1501 to 1600 AH. The bundled ephemeris ends in 1524 AH.

## Open questions

* What criterion, or what computation, produced KACST's months from 1451 AH. KACST's own documentation, likely in Arabic, or KACST itself, is the place to ask; the Saudi astronomical literature on the Umm al-Qura projections may describe it.

* Whether the 1451 AH boundary marks a change of method or the edge of a recomputation: announced months recomputed with the 1423 AH rule, later months left from an earlier projection.

## Options

* Document the two regimes in the moduledoc and keep the published rule.

* Add a fifth era from 1451 AH with the fitted rule, which reproduces the tables in all but two months but explains nothing.

* Wait for the criterion before changing the calendar.
