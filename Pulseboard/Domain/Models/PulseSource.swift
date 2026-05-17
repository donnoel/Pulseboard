import Foundation

enum PulseSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case usgs
    case eonet
    case gdacs
    case nws

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usgs:
            "USGS"
        case .eonet:
            "NASA EONET"
        case .gdacs:
            "GDACS"
        case .nws:
            "NWS / National Weather Service"
        }
    }

    var attributionURL: URL? {
        switch self {
        case .usgs:
            URL(string: "https://earthquake.usgs.gov")
        case .eonet:
            URL(string: "https://eonet.gsfc.nasa.gov")
        case .gdacs:
            URL(string: "https://www.gdacs.org")
        case .nws:
            URL(string: "https://www.weather.gov")
        }
    }
}
