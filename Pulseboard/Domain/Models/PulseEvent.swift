import CoreLocation
import Foundation

struct PulseCoordinate: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PulseEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let category: PulseCategory
    let severity: PulseSeverity
    let source: PulseSource
    let timestamp: Date
    let coordinate: PulseCoordinate
    let link: URL?
    let metadata: [String: String]
}
