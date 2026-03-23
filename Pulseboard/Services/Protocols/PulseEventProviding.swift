import Foundation

protocol PulseEventProviding: Sendable {
    var source: PulseSource { get }
    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent]
}
