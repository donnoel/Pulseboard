# Pulseboard

## Overview
Pulseboard is a map-first iPhone + iPad SwiftUI app for exploring the living pulse of the world across safety, learning, and economic signals.

Current V1 foundation:
- Safety layer is live now with real-time USGS, NASA EONET, GDACS, and NWS integrations (no mock runtime data).
- Learning and Economy pillars are now part of the product direction and are staged for future indicator layers.
- Unified event/domain models for multi-source expansion.
- Region, category, and time-window filtering.
- Layered map UI with chips, summary cards, clustered markers, and featured event panel.
- Phase 2 is in progress, with active NWS alerts now part of the live source foundation.

## Requirements
- Xcode 17+ (Swift 6 toolchain)
- iOS/iPadOS Simulator or device

## Getting Started
1. Open `Pulseboard.xcodeproj`
2. Select an iOS Simulator destination
3. Build and Run

### Build
```bash
xcodebuild -scheme Pulseboard -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

### Unit tests
```bash
xcodebuild -scheme Pulseboard -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PulseboardTests test
```

### Asset Catalog Validation
Use the build as the primary asset-catalog validation gate:
```bash
xcodebuild -scheme Pulseboard -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

For asset catalog `Contents.json` parsing, use:
```bash
find Pulseboard/Assets.xcassets -name Contents.json -print0 | while IFS= read -r -d '' file; do
  plutil -convert json -o /dev/null "$file"
done
```

On this repo/toolchain, `plutil -lint` may report `Unexpected character { at line 1` for valid asset catalog JSON. If `plutil -convert json` and the Xcode build both pass, do not treat that lint output alone as an asset failure.

## Project Structure
```text
Pulseboard/
├── Pulseboard/
│   ├── App/
│   ├── Core/
│   ├── Domain/
│   ├── Features/
│   └── Services/
├── PulseboardTests/
└── PulseboardUITests/
```

## Roadmap
- [x] Phase 1: architecture + design tokens + live USGS map foundation
- [ ] Phase 2: map-first live-source refinement, event detail, filters, and iPad polish
- [x] USGS integration
- [x] NASA EONET integration
- [x] GDACS integration
- [x] NWS alerts integration
- [x] World Pulse pillar framing
- [ ] Learning pillar indicator foundation
- [ ] Economy pillar indicator foundation
- [ ] Region polish
