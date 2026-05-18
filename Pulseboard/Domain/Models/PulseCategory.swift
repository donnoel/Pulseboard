import Foundation

enum PulseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case earthquakes
    case hazards
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .earthquakes:
            "Earthquakes"
        case .hazards:
            "Hazards"
        case .alerts:
            "NWS Alerts"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "line.3.horizontal.decrease.circle"
        case .earthquakes:
            "waveform.path.ecg"
        case .hazards:
            "hurricane"
        case .alerts:
            "exclamationmark.triangle"
        }
    }
}
