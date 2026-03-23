import Combine
import Foundation
import MapKit

struct EventDetailRow: Identifiable, Hashable {
    let label: String
    let value: String

    var id: String { "\(label)-\(value)" }
}

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published private(set) var mapItem: PulseMapItem

    init(mapItem: PulseMapItem) {
        self.mapItem = mapItem
    }

    var event: PulseEvent {
        mapItem.primaryEvent
    }

    var title: String {
        event.title
    }

    var summary: String {
        event.summary
    }

    var categoryTitle: String {
        event.category.title
    }

    var severityTitle: String {
        event.severity.title
    }

    var sourceTitle: String {
        event.source.title
    }

    var eventTimestamp: Date {
        event.timestamp
    }

    var sourceLink: URL? {
        event.link
    }

    var nearbyEventsText: String? {
        mapItem.isCluster ? "\(mapItem.count)" : nil
    }

    var detailRows: [EventDetailRow] {
        var rows = [
            EventDetailRow(label: "Category", value: event.category.title),
            EventDetailRow(label: "Source", value: event.source.title),
            EventDetailRow(label: "Severity", value: event.severity.title),
            EventDetailRow(label: "Timestamp", value: event.timestamp.formatted(date: .abbreviated, time: .shortened))
        ]

        if let nearbyEventsText {
            rows.append(EventDetailRow(label: "Nearby events", value: nearbyEventsText))
        }

        return rows
    }

    var metadataRows: [EventDetailRow] {
        event.metadata
            .keys
            .sorted()
            .compactMap { key in
                guard let value = event.metadata[key] else {
                    return nil
                }
                return EventDetailRow(label: key, value: value)
            }
    }

    var mapEvents: [PulseEvent] {
        mapItem.events
    }

    var mapRegion: MKCoordinateRegion {
        let coordinates = mapItem.events.map(\.coordinate.clCoordinate)
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: event.coordinate.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            )
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)

        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLon = lons.min(),
            let maxLon = lons.max()
        else {
            return MKCoordinateRegion(
                center: event.coordinate.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            )
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latitudeDelta = max(3, abs(maxLat - minLat) * 1.8)
        let longitudeDelta = max(3, abs(maxLon - minLon) * 1.8)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
