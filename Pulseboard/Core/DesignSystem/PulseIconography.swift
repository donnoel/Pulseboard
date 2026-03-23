import SwiftUI

enum PulseIconography {
    static func symbol(for category: PulseCategory) -> String {
        switch category {
        case .all:
            return "circle.grid.3x3.fill"
        case .earthquakes:
            return "wave.3.right.circle.fill"
        case .hazards:
            return "tornado"
        case .alerts:
            return "exclamationmark.triangle.fill"
        }
    }

    static func symbol(for source: PulseSource) -> String {
        switch source {
        case .usgs:
            return "mountain.2.fill"
        case .eonet:
            return "globe.americas.fill"
        case .gdacs:
            return "bell.badge.fill"
        case .nws:
            return "cloud.bolt.rain.fill"
        }
    }

    static func symbol(for severity: PulseSeverity) -> String {
        switch severity {
        case .low:
            return "checkmark.circle.fill"
        case .moderate:
            return "exclamationmark.circle.fill"
        case .high:
            return "exclamationmark.shield.fill"
        case .severe:
            return "bolt.trianglebadge.exclamationmark.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    static func tint(for source: PulseSource) -> Color {
        switch source {
        case .usgs:
            return Color(red: 0.31, green: 0.87, blue: 0.96)
        case .eonet:
            return Color(red: 0.44, green: 0.81, blue: 0.50)
        case .gdacs:
            return Color(red: 0.98, green: 0.59, blue: 0.28)
        case .nws:
            return Color(red: 0.94, green: 0.71, blue: 0.26)
        }
    }
}
