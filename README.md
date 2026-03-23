# Pulseboard

## Overview
Pulseboard is a map-first iPhone + iPad SwiftUI app for exploring live natural events from direct public feeds.

Current V1 foundation:
- Real-time USGS earthquake integration (no mock runtime data).
- Unified event/domain models for multi-source expansion.
- Region, category, and time-window filtering.
- Layered map UI with chips, summary cards, clustered markers, and featured event panel.

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
- [ ] Phase 2: Event detail + deeper filter behavior
- [ ] Phase 3: EONET integration
- [ ] Phase 4: GDACS integration
- [ ] Phase 5: NWS alerts + region polish
