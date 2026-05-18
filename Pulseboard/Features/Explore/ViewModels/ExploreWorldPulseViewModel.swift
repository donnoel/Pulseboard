import Foundation
import Combine

@MainActor
final class ExploreWorldPulseViewModel: ObservableObject {
    @Published private(set) var countryProfiles: [CountryPulseProfile] = []

    private let countryProfileService: CountryPulseProfileService
    private var hasLoaded = false

    init(countryProfileService: CountryPulseProfileService = CountryPulseProfileService()) {
        self.countryProfileService = countryProfileService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        countryProfiles = await countryProfileService.fetchPreviewProfiles()
    }
}
