import Foundation

enum PulseSeverity: String, Codable, CaseIterable, Sendable {
    case low
    case moderate
    case high
    case severe
    case unknown

    var rank: Int {
        switch self {
        case .low:
            1
        case .moderate:
            2
        case .high:
            3
        case .severe:
            4
        case .unknown:
            0
        }
    }

    var title: String {
        switch self {
        case .low:
            "Low"
        case .moderate:
            "Moderate"
        case .high:
            "High"
        case .severe:
            "Severe"
        case .unknown:
            "Unknown"
        }
    }

    static func fromMagnitude(_ magnitude: Double?, alertLevel: String?) -> PulseSeverity {
        if let alertLevel {
            switch alertLevel.lowercased() {
            case "red":
                return .severe
            case "orange":
                return .high
            case "yellow":
                return .moderate
            default:
                break
            }
        }

        guard let magnitude else {
            return .unknown
        }

        switch magnitude {
        case ..<3.5:
            return .low
        case ..<5.5:
            return .moderate
        case ..<6.8:
            return .high
        default:
            return .severe
        }
    }
}
