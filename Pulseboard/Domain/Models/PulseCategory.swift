import Foundation

enum PulsePillar: String, CaseIterable, Codable, Identifiable, Sendable {
    case safety
    case learning
    case economy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safety:
            "Safety"
        case .learning:
            "Learning"
        case .economy:
            "Economy"
        }
    }

    var subtitle: String {
        switch self {
        case .safety:
            "Live natural events and public alerts"
        case .learning:
            "Education and access indicators"
        case .economy:
            "Debt, growth, and stability signals"
        }
    }

    var statusLabel: String {
        switch self {
        case .safety:
            "Live now"
        case .learning, .economy:
            "Coming next"
        }
    }

    var systemImage: String {
        switch self {
        case .safety:
            "shield.lefthalf.filled"
        case .learning:
            "book.closed"
        case .economy:
            "chart.line.uptrend.xyaxis"
        }
    }
}

enum PulseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case earthquakes
    case hazards
    case alerts

    var id: String { rawValue }

    var pillar: PulsePillar {
        switch self {
        case .all, .earthquakes, .hazards, .alerts:
            .safety
        }
    }

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
