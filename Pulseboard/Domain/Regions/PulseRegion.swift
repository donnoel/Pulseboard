import Foundation
import MapKit

struct PulseBounds: Sendable {
    let latitude: ClosedRange<Double>
    let longitudeSegments: [ClosedRange<Double>]

    init(latitude: ClosedRange<Double>, longitude: ClosedRange<Double>) {
        self.latitude = latitude
        longitudeSegments = [longitude]
    }

    init(latitude: ClosedRange<Double>, longitudeSegments: [ClosedRange<Double>]) {
        self.latitude = latitude
        self.longitudeSegments = longitudeSegments
    }

    func contains(_ coordinate: PulseCoordinate) -> Bool {
        guard latitude.contains(coordinate.latitude) else {
            return false
        }

        return longitudeSegments.contains { $0.contains(coordinate.longitude) }
    }
}

enum PulseRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case world
    case northAmerica
    case southAmerica
    case europe
    case africa
    case asia
    case oceania

    var id: String { rawValue }

    var title: String {
        switch self {
        case .world:
            "World"
        case .northAmerica:
            "North America"
        case .southAmerica:
            "South America"
        case .europe:
            "Europe"
        case .africa:
            "Africa"
        case .asia:
            "Asia"
        case .oceania:
            "Oceania"
        }
    }

    var bounds: [PulseBounds]? {
        switch self {
        case .world:
            nil
        case .northAmerica:
            [PulseBounds(latitude: 7...84, longitude: -170 ... -52)]
        case .southAmerica:
            [PulseBounds(latitude: -56...13, longitude: -82 ... -35)]
        case .europe:
            [PulseBounds(latitude: 35...71, longitude: -25 ... 45)]
        case .africa:
            [PulseBounds(latitude: -36...38, longitude: -19 ... 55)]
        case .asia:
            [PulseBounds(latitude: 1...80, longitude: 25 ... 180)]
        case .oceania:
            [
                PulseBounds(latitude: -52...5, longitudeSegments: [110...180, -180 ... -140])
            ]
        }
    }

    var defaultMapRegion: MKCoordinateRegion {
        switch self {
        case .world:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 10, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 320)
            )
        case .northAmerica:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46, longitude: -100),
                span: MKCoordinateSpan(latitudeDelta: 56, longitudeDelta: 84)
            )
        case .southAmerica:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -16, longitude: -62),
                span: MKCoordinateSpan(latitudeDelta: 72, longitudeDelta: 58)
            )
        case .europe:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54, longitude: 12),
                span: MKCoordinateSpan(latitudeDelta: 36, longitudeDelta: 54)
            )
        case .africa:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 3, longitude: 20),
                span: MKCoordinateSpan(latitudeDelta: 72, longitudeDelta: 72)
            )
        case .asia:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34, longitude: 95),
                span: MKCoordinateSpan(latitudeDelta: 70, longitudeDelta: 128)
            )
        case .oceania:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -22, longitude: 152),
                span: MKCoordinateSpan(latitudeDelta: 52, longitudeDelta: 84)
            )
        }
    }

    func contains(_ coordinate: PulseCoordinate) -> Bool {
        guard let bounds else {
            return true
        }

        return bounds.contains { $0.contains(coordinate) }
    }
}
