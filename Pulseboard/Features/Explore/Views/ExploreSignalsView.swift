import SwiftUI

struct ExploreSignalsView: View {
    let events: [PulseEvent]
    let onSelect: (PulseEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    private var visibleEvents: [PulseEvent] {
        Array(events.prefix(60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.medium) {
                    headerCard

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
            .navigationTitle("Explore Signals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Signal Browser")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Browse active events without crowding the map home.")
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            Text("No signals available")
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
