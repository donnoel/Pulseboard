import Foundation

actor GDACSService: PulseEventProviding {
    let source: PulseSource = .gdacs

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        throw GDACSServiceError.notImplemented
    }
}

enum GDACSServiceError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        "GDACS integration will be added in Phase 4."
    }
}
