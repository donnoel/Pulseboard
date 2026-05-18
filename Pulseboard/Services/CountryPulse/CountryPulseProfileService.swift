import Foundation

actor CountryPulseProfileService {
    func fetchPreviewProfiles() async -> [CountryPulseProfile] {
        CountryPulseProfile.previewSamples
    }
}
