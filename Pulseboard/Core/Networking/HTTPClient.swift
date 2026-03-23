import Foundation

enum HTTPClientError: LocalizedError {
    case invalidResponse
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Server returned an invalid response."
        case let .statusCode(code):
            "Server returned status code \(code)."
        }
    }
}

actor HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            throw HTTPClientError.statusCode(response.statusCode)
        }

        return data
    }
}
