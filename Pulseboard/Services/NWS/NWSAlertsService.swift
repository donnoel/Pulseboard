import Foundation

actor NWSAlertsService: PulseEventProviding {
    let source: PulseSource = .nws

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        throw NWSAlertsServiceError.notImplemented
    }
}

enum NWSAlertsServiceError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        "NWS integration will be added in Phase 5."
    }
}
