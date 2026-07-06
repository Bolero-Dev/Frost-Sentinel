# Frost Sentinel

One question, answered quietly: **does anything in my garden need covering tonight?**

Gardeners cross-reference weather forecasts against each plant's cold tolerance by
hand, every cold-snap evening. Frost Sentinel removes that friction. Log your plants
once; every night it fetches the forecast and gives you a plain answer per plant:
*"Basil is fine tonight." "Cover the lavender." "Bring the seedlings in — covering
may not be enough."*

No accounts. No ads. No location permission — you give it coordinates, it never asks
the OS where you are. Works offline with the last cached forecast, because frost
doesn't wait for good Wi-Fi.

## Why this project exists (the technical story)

Frost Sentinel is deliberately built across three layers that mirror real production
iOS work:

**REST networking (Swift, async/await).** Nightly minimum temperatures come from the
[Open-Meteo API](https://open-meteo.com/) — no API key, consistent with the app's
no-tracking posture. The service is defined behind a `ForecastFetching` protocol, the
response parser is a pure static function tested against fixtures, and the URL
construction is unit-tested.

**Core Data, offline-first.** The stack uses a *programmatic* managed object model —
the entire schema is reviewable in a code diff, with no `.xcdatamodeld` drift. On every
successful fetch the forecast cache is replaced; when the network fails, the app falls
back to the cache and says so honestly ("Offline — using forecast from 2 hours ago").
A slightly stale answer beats no answer when frost is coming.

**Objective-C legacy layer, bridged into Swift.** The frost-risk classification lives
in `FSFrostCalculator`, written in Objective-C on purpose. Real-world horticultural and
agricultural calculation libraries are frequently legacy code, and contract work means
maintaining and bridging code like this — not rewriting it. The class demonstrates
`NS_ENUM` bridging, nullability annotations, designated initializers, and a legacy
surface consumed by a modern `@MainActor` Swift view model.

## Tests

The suite covers all three layers and the seams between them:

- `FrostCalculatorTests` — the Objective-C domain math, exercised through the Swift bridge
- `ForecastServiceTests` — response parsing against fixtures, malformed-payload rejection, URL construction
- `GardenViewModelTests` — integration: mocked REST service + real in-memory Core Data + bridged calculator; verdict ordering, cache population, offline fallback, and error paths

Run with ⌘U.

## Architecture

```
App/FrostSentinelApp.swift          entry point, dependency wiring
Features/GardenView.swift           the single screen: tonight's low + verdicts
Core/GardenViewModel.swift          orchestrates fetch -> cache -> classify
Core/Network/ForecastService.swift  Open-Meteo client behind a protocol
Core/Persistence/                   programmatic Core Data model + GardenStore
Legacy/FSFrostCalculator.h/.m       Objective-C risk classification (bridged)
```

---

Built by Liza Sloane — [github.com/Bolero-Dev](https://github.com/Bolero-Dev)
