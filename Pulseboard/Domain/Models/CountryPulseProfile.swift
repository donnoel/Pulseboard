import Foundation

struct CountryPulseProfile: Identifiable, Codable, Equatable, Sendable {
    let countryCode: String
    let countryName: String
    let summary: String
    let updatedYear: Int?
    let pillarSnapshots: [CountryPillarSnapshot]

    var id: String { countryCode }
}

struct CountryPillarSnapshot: Identifiable, Codable, Equatable, Sendable {
    let pillar: PulsePillar
    let status: PulseIndicatorStatus
    let summary: String
    let indicators: [PulseIndicator]

    var id: PulsePillar { pillar }
}

struct PulseIndicator: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let value: String
    let unit: String?
    let year: Int?
    let sourceName: String
    let status: PulseIndicatorStatus
    let trend: PulseTrend
    let detail: String?
}

enum PulseIndicatorStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case favorable
    case stable
    case watch
    case elevated
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorable:
            "Favorable"
        case .stable:
            "Stable"
        case .watch:
            "Watch"
        case .elevated:
            "Elevated"
        case .unknown:
            "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .favorable:
            "checkmark.seal"
        case .stable:
            "equal.circle"
        case .watch:
            "eye"
        case .elevated:
            "exclamationmark.triangle"
        case .unknown:
            "questionmark.circle"
        }
    }
}

enum PulseTrend: String, Codable, CaseIterable, Identifiable, Sendable {
    case improving
    case stable
    case worsening
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .improving:
            "Improving"
        case .stable:
            "Stable"
        case .worsening:
            "Worsening"
        case .unknown:
            "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .improving:
            "arrow.up.right"
        case .stable:
            "arrow.right"
        case .worsening:
            "arrow.down.right"
        case .unknown:
            "questionmark"
        }
    }
}

extension CountryPulseProfile {
    static let previewSamples: [CountryPulseProfile] = [
        CountryPulseProfile(
            countryCode: "US",
            countryName: "United States",
            summary: "Large, high-income economy with broad education access and elevated public-debt pressure.",
            updatedYear: 2025,
            pillarSnapshots: [
                CountryPillarSnapshot(
                    pillar: .learning,
                    status: .stable,
                    summary: "High literacy and broad education access.",
                    indicators: [
                        PulseIndicator(
                            id: "us-learning-literacy",
                            title: "Literacy",
                            value: "High",
                            unit: nil,
                            year: nil,
                            sourceName: "Future education indicator source",
                            status: .stable,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                ),
                CountryPillarSnapshot(
                    pillar: .economy,
                    status: .watch,
                    summary: "High-income economy with debt pressure worth watching.",
                    indicators: [
                        PulseIndicator(
                            id: "us-economy-debt",
                            title: "Debt Pressure",
                            value: "Watch",
                            unit: nil,
                            year: nil,
                            sourceName: "Future economy indicator source",
                            status: .watch,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                )
            ]
        ),
        CountryPulseProfile(
            countryCode: "JP",
            countryName: "Japan",
            summary: "Advanced economy with strong learning indicators and persistent debt pressure.",
            updatedYear: 2025,
            pillarSnapshots: [
                CountryPillarSnapshot(
                    pillar: .learning,
                    status: .favorable,
                    summary: "Strong education and learning-access profile.",
                    indicators: [
                        PulseIndicator(
                            id: "jp-learning-access",
                            title: "Learning Access",
                            value: "Strong",
                            unit: nil,
                            year: nil,
                            sourceName: "Future education indicator source",
                            status: .favorable,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                ),
                CountryPillarSnapshot(
                    pillar: .economy,
                    status: .elevated,
                    summary: "Advanced economy with elevated debt burden.",
                    indicators: [
                        PulseIndicator(
                            id: "jp-economy-debt",
                            title: "Debt Pressure",
                            value: "Elevated",
                            unit: nil,
                            year: nil,
                            sourceName: "Future economy indicator source",
                            status: .elevated,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                )
            ]
        ),
        CountryPulseProfile(
            countryCode: "DE",
            countryName: "Germany",
            summary: "Advanced economy with strong learning access and comparatively stable debt pressure.",
            updatedYear: 2025,
            pillarSnapshots: [
                CountryPillarSnapshot(
                    pillar: .learning,
                    status: .favorable,
                    summary: "Strong education and workforce-skills foundation.",
                    indicators: [
                        PulseIndicator(
                            id: "de-learning-access",
                            title: "Learning Access",
                            value: "Strong",
                            unit: nil,
                            year: nil,
                            sourceName: "Future education indicator source",
                            status: .favorable,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                ),
                CountryPillarSnapshot(
                    pillar: .economy,
                    status: .stable,
                    summary: "Large advanced economy with stable debt profile relative to peers.",
                    indicators: [
                        PulseIndicator(
                            id: "de-economy-debt",
                            title: "Debt Pressure",
                            value: "Stable",
                            unit: nil,
                            year: nil,
                            sourceName: "Future economy indicator source",
                            status: .stable,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                )
            ]
        ),
        CountryPulseProfile(
            countryCode: "IN",
            countryName: "India",
            summary: "Large emerging economy with expanding learning access and growth-focused economic signals.",
            updatedYear: 2025,
            pillarSnapshots: [
                CountryPillarSnapshot(
                    pillar: .learning,
                    status: .watch,
                    summary: "Large-scale learning access continues expanding, with uneven regional outcomes.",
                    indicators: [
                        PulseIndicator(
                            id: "in-learning-access",
                            title: "Learning Access",
                            value: "Expanding",
                            unit: nil,
                            year: nil,
                            sourceName: "Future education indicator source",
                            status: .watch,
                            trend: .improving,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                ),
                CountryPillarSnapshot(
                    pillar: .economy,
                    status: .watch,
                    summary: "Growth-focused economy with development and debt signals to monitor.",
                    indicators: [
                        PulseIndicator(
                            id: "in-economy-growth",
                            title: "Economic Momentum",
                            value: "Watch",
                            unit: nil,
                            year: nil,
                            sourceName: "Future economy indicator source",
                            status: .watch,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                )
            ]
        ),
        CountryPulseProfile(
            countryCode: "BR",
            countryName: "Brazil",
            summary: "Large regional economy with broad education access and recurring fiscal-watch signals.",
            updatedYear: 2025,
            pillarSnapshots: [
                CountryPillarSnapshot(
                    pillar: .learning,
                    status: .stable,
                    summary: "Broad learning access with room for quality and completion improvements.",
                    indicators: [
                        PulseIndicator(
                            id: "br-learning-access",
                            title: "Learning Access",
                            value: "Broad",
                            unit: nil,
                            year: nil,
                            sourceName: "Future education indicator source",
                            status: .stable,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                ),
                CountryPillarSnapshot(
                    pillar: .economy,
                    status: .watch,
                    summary: "Major economy with fiscal and inflation-watch context to track.",
                    indicators: [
                        PulseIndicator(
                            id: "br-economy-fiscal",
                            title: "Fiscal Pressure",
                            value: "Watch",
                            unit: nil,
                            year: nil,
                            sourceName: "Future economy indicator source",
                            status: .watch,
                            trend: .unknown,
                            detail: "Placeholder preview classification until sourced indicator data is integrated."
                        )
                    ]
                )
            ]
        )
    ]
}
