# AGENTS.project.md

# Pulseboard Project Guide for Agents

## Product intent
- Audience: people who want a quick visual understanding of active natural events and alerts.
- Problem: most open event feeds are text-heavy and hard to scan spatially.
- Success criteria: a map-first, exploration-driven iPhone+iPad experience that loads real public data immediately on first launch without accounts, backend services, or API keys.

## Current product phase
Phase 2 is now in progress:
1) Feature-oriented SwiftUI + MVVM structure is in place.
2) Shared domain/event models and region filtering are established.
3) Real USGS + EONET integrations feed home experience with no mock runtime data.
4) Pulse Map home is map-first with a compact top bar, expandable filter tray, and focused Pulse Highlights surfaces on iPhone and iPad.
5) Event Detail is extracted into a dedicated feature with its own view model.
6) Explore Signals sheet provides a separate browsing surface to reduce home clutter.

Current reliability and UX goals:
- Build stays warning-free.
- Source failures are non-crashing and user-visible.
- UI remains map-first and exploratory (not a list feed).

## Architecture snapshot (current)
- App entry: `PulseboardApp` -> `AppShellView` (Pulse + Settings tabs).
- Main feature: `PulseMapView` with `PulseMapViewModel` driving region/filter state, summary metrics, clustered map markers, and focused Pulse Highlights.
- Detail feature: `EventDetailView` with `EventDetailViewModel` for polished event presentation and map context.
- Explore feature: `ExploreSignalsView` for broader signal browsing off the home map.
- Data layer:
  - `HTTPClient` actor for network requests.
  - `PulseEventAggregatorService` actor for multi-source merge + partial-failure capture.
  - `USGSEarthquakeService` actor for feed fetch, normalization, and in-memory TTL caching.
  - `EONETService` actor for EONET fetch, normalization, and in-memory TTL caching.
  - Shared protocol: `PulseEventProviding`.
- Domain:
  - `PulseEvent`, `PulseCategory`, `PulseSeverity`, `PulseSource`, `PulseRegion`, `PulseTimeWindow`.
  - Region filtering is client-side via coordinate bounds.
- Persistence: none in V1 foundation (network-only + memory cache).

## Concurrency rules (important)
- Keep UI state/view models on `@MainActor`.
- Keep networking and feed normalization off main actor in actors/services.
- Avoid broad global actor shortcuts; use explicit actor boundaries.

## Behavior invariants (do not regress)
- No mock runtime data.
- First launch must work with live public feeds.
- App remains map-first and exploration-first.
- Source attribution must remain visible in-app.

## UX rules
- Home experience is a full-screen map with layered controls.
- Primary interactions are chips, cards, markers, and panels.
- iPad uses intentional composition (not simple scaled iPhone layout).
- Failures show actionable messaging and keep existing data if available.

## Coding conventions
- Keep model/service types small and focused.
- Use async/await + actors for networking and shared mutable state.
- Prefer design-system tokens for spacing/surfaces/chip styles.

## Build/run notes
- Targets: iOS/iPadOS simulator + device, universal iPhone + iPad.
- Build policy: zero warnings (treat warnings as errors in practice).
- Local verification commands:
  - `xcodebuild -scheme Pulseboard -configuration Debug -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -scheme Pulseboard -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PulseboardTests test`

## Near-term priorities
1) Add GDACS + NWS sources with partial-failure aggregation behavior.
2) Expand home summaries/filters for mixed-source events and alert categories.
3) Continue iPad-first polish, accessibility, and performance passes.
4) Add focused tests for remaining source normalizers as they land.

## Output expectations per patch
- Summary of change
- Files modified and why
- Any migration considerations
- Commit message suggestion
