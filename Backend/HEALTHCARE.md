# Hospitals and pharmacies — native app 0.14.0 (30)

The existing category chips, stable map, place cards, add/edit form, in-app walking navigation and category favourites are reused. No Canva or website changes are part of this release.

## Discovery and hours

- A single Здраве navigation slot groups hospitals and pharmacies on the start page, map and favourites. The stored categories remain distinct, including when adding/editing a place.
- Inside Здраве the filters are Болници / Аптеки. Known 24-hour schedules are indicated on map pins with a 24/7 badge; there are no pharmacy-hours filter buttons. Unknown schedules remain explicitly unknown; names such as “Фрамар 24” do not prove 24-hour operation.
- Closed healthcare locations remain visible with their status so people can inspect regular hours. The nearest-pharmacy action only uses places open according to an explicit schedule. Individual detail pages still allow directions to a chosen place.
- Schedules use the existing Europe/Sofia calculations and update periodically. Published weekly hours are not a live opening guarantee; the source date and call action are provided.
- Hospitals are not marked open 24 hours merely because they have an emergency department. Pins identify the hospital building, not a verified emergency entrance. Details retain a 112 call action and advise checking the department and entrance.
- Three hospitals and two pharmacies are bundled; Apple Maps searches can add further results. This is not a complete registry. Missing Apple results do not remove the bundled directory.

## Sources

The machine-readable starter dataset is [healthcare-sources.json](healthcare-sources.json). Contact/address/hours pages were checked on 14 October 2026. Coordinates come from OpenStreetMap contributors and the coordinate dataset is available under [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Attribution appears on the healthcare map list and catalogue place details.

- [УМБАЛ Бургас](https://www.mbalburgas.com/) — бул. Стефан Стамболов 73.
- [Бургасмед](https://www.hospitalburgasmed.bg/contacts.block1.php) — Меден рудник, зона А.
- [Сърце и Мозък](https://cardiacinstitute.bg/en/hospitals-and-centers/heart-and-brain-center-of-excellence-burgas/contacts/) — use the provider’s address, ул. Здраве 1. The OSM address tag differs; only its building geometry is used.
- [Пулс](https://www.pulsapteka.com/kontakti) — Славейков бл. 77, published 24/7.
- [SOpharmacy Pirgos Park](https://pirgospark.bg/obekti/sopharmacy/) — Янко Комитов 4, published daily 09:00–20:00.

## Shared database

The 0.13.1 grouping is app-only and needs no database changes. Future SQL updates are provided as files for the user to apply manually.

[healthcare-categories.sql](healthcare-categories.sql) extends existing category checks and the private-favourites validator. It preserves stored rows and existing ownership/RLS policies. Applied to project `shodinaimhixnudqqgck` on 14 October 2026; SQL Editor returned **Healthcare categories ready**. The two original setup scripts also accept the new categories.

## Verification

82 regression tests passed, including ten healthcare tests covering ambiguous names, invalid schedules, closed/unknown/open distinctions, filters, saved contact/schedule/source round trips, category validation, branch deduplication and the combined navigation group. All native Swift sources pass iOS 17 type checking. The full Xcode simulator build for 0.14.0 (30) also passed. Xcode reported simulator-service connection warnings, so the updated UI has not been visually verified on a device.
