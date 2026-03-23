import Foundation

enum PulseTimeWindow: String, CaseIterable, Codable, Identifiable, Sendable {
    case hours24
    case hours72
    case days7

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hours24:
            "24h"
        case .hours72:
            "72h"
        case .days7:
            "7d"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .hours24:
            24 * 60 * 60
        case .hours72:
            72 * 60 * 60
        case .days7:
            7 * 24 * 60 * 60
        }
    }

    var usgsFeedPath: String {
        switch self {
        case .hours24:
            "all_day.geojson"
        case .hours72, .days7:
            "all_week.geojson"
        }
    }
}
