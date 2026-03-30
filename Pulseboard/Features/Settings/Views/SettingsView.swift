import SwiftUI

struct SettingsView: View {
    private var activeSources: [PulseSource] {
        PulseRuntimeSources.activeSources
    }

    private var comingSoonSources: [PulseSource] {
        PulseSource.allCases.filter { !activeSources.contains($0) }
    }

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

                        ForEach(activeSources) { source in
                            sourceRow(source, status: "Live Now", tint: PulsePalette.success)
                        }

                        if !comingSoonSources.isEmpty {
                            Text("Coming Soon")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.top, PulseSpacing.small)

                            ForEach(comingSoonSources) { source in
                                sourceRow(source, status: "Not Active Yet", tint: .white.opacity(0.52))
                            }
                        }
                    }
                    .pulseGlassCard()
                }
                .padding(PulseSpacing.large)
            }
        }
    }

    private func sourceRow(_ source: PulseSource, status: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .foregroundStyle(.white)
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
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

#Preview {
    SettingsView()
}
