import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PulsePalette.backgroundTop, PulsePalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.large) {
                    VStack(alignment: .leading, spacing: PulseSpacing.small) {
                        Text("Pulseboard")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Live natural-event awareness with direct public data feeds and no backend.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    .pulseGlassCard(prominent: true)

                    VStack(alignment: .leading, spacing: PulseSpacing.small) {
                        Text("Live Data Sources")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        ForEach(PulseSource.allCases) { source in
                            HStack {
                                Text(source.title)
                                    .foregroundStyle(.white)
                                Spacer()
                                if let url = source.attributionURL {
                                    Link("Open", destination: url)
                                        .foregroundStyle(PulsePalette.accent)
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 2)
                        }
                    }
                    .pulseGlassCard()
                }
                .padding(PulseSpacing.large)
            }
        }
    }
}

#Preview {
    SettingsView()
}
