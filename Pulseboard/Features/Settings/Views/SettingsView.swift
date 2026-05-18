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
                        Text("A living world pulse across safety, learning, and economic signals.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    .pulseGlassCard(prominent: true)

                    VStack(alignment: .leading, spacing: PulseSpacing.small) {
                        Text("World Pulse Pillars")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        ForEach(PulsePillar.allCases) { pillar in
                            pillarRow(pillar)
                        }
                    }
                    .pulseGlassCard()

                    VStack(alignment: .leading, spacing: PulseSpacing.small) {
                        Text("Live Safety Sources")
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

    private func pillarRow(_ pillar: PulsePillar) -> some View {
        HStack(spacing: PulseSpacing.small) {
            Image(systemName: pillar.systemImage)
                .font(.headline)
                .foregroundStyle(pillar == .safety ? PulsePalette.accent : .white.opacity(0.7))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(pillar.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(pillar.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Text(pillar.statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(pillar == .safety ? PulsePalette.success : .white.opacity(0.52))
        }
        .padding(.vertical, 3)
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
