import SwiftUI

struct ExploreSignalsView: View {
    let events: [PulseEvent]
    let onSelect: (PulseEvent) -> Void

    @StateObject private var viewModel = ExploreWorldPulseViewModel()
    @Environment(\.dismiss) private var dismiss

    private var visibleEvents: [PulseEvent] {
        Array(events.prefix(60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.medium) {
                    headerCard
                    countryIntelligenceSection
                    liveSignalsSection
                }
                .padding(PulseSpacing.large)
            }
            .background(
                LinearGradient(
                    colors: [PulsePalette.backgroundTop, PulsePalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Explore World Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("World Pulse Browser")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Live safety signals are active now. Country intelligence previews Learning and Economy layers coming next.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
            }

            Spacer()

            Text("\(events.count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        }
        .pulseGlassCard(prominent: true)
    }

    private var countryIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Country Intelligence")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Early preview profiles for Learning and Economy indicators. These are local placeholders until sourced country data is integrated.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if viewModel.countryProfiles.isEmpty {
                CountryPulseLoadingCard()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: PulseSpacing.small)], spacing: PulseSpacing.small) {
                    ForEach(viewModel.countryProfiles) { profile in
                        CountryPulsePreviewCard(profile: profile)
                    }
                }
            }
        }
    }

    private var liveSignalsSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Safety Signals")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Current public feeds from the active Safety layer.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("\(visibleEvents.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            if visibleEvents.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: PulseSpacing.small)], spacing: PulseSpacing.small) {
                    ForEach(visibleEvents) { event in
                        ExploreSignalCard(event: event)
                            .onTapGesture {
                                onSelect(event)
                                dismiss()
                            }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            Text("No live safety signals available")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Try changing region or filters from the Pulse map.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseGlassCard()
    }
}

private struct CountryPulseLoadingCard: View {
    var body: some View {
        HStack(spacing: PulseSpacing.small) {
            ProgressView()
                .tint(.white)
            Text("Loading country intelligence preview…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseGlassCard()
    }
}

private struct CountryPulsePreviewCard: View {
    let profile: CountryPulseProfile

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.countryName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(profile.countryCode)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                if let updatedYear = profile.updatedYear {
                    Text("Preview · \(updatedYear)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Text(profile.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            VStack(alignment: .leading, spacing: PulseSpacing.tiny) {
                ForEach(profile.pillarSnapshots) { snapshot in
                    CountryPillarStatusRow(snapshot: snapshot)
                }
            }
        }
        .pulseGlassCard()
    }
}

private struct CountryPillarStatusRow: View {
    let snapshot: CountryPillarSnapshot

    var body: some View {
        HStack(spacing: PulseSpacing.tiny) {
            Image(systemName: snapshot.pillar.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(width: 18)

            Text(snapshot.pillar.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Spacer()

            Label(snapshot.status.title, systemImage: snapshot.status.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusTint)
                .labelStyle(.titleAndIcon)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.pillar.title), \(snapshot.status.title)")
    }

    private var statusTint: Color {
        switch snapshot.status {
        case .favorable:
            PulsePalette.success
        case .stable:
            PulsePalette.accent
        case .watch:
            PulsePalette.warning
        case .elevated:
            PulsePalette.danger
        case .unknown:
            .white.opacity(0.62)
        }
    }
}

private struct ExploreSignalCard: View {
    let event: PulseEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(event.category.title, systemImage: PulseIconography.symbol(for: event.category))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulsePalette.color(for: event.category))

                Spacer()

                Image(systemName: PulseIconography.symbol(for: event.source))
                    .foregroundStyle(PulseIconography.tint(for: event.source))
            }

            Text(event.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(3)

            Text(event.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)

            HStack {
                Image(systemName: PulseIconography.symbol(for: event.severity))
                Text(event.severity.title)
                Spacer()
                Text(event.timestamp, style: .relative)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.74))
        }
        .pulseGlassCard()
    }
}
