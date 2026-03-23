import MapKit
import SwiftUI

struct EventDetailView: View {
    @StateObject private var viewModel: EventDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: EventDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.large) {
                    summaryCard
                    mapContextCard
                    attributesCard

                    if !viewModel.metadataRows.isEmpty {
                        metadataCard
                    }

                    if let sourceLink = viewModel.sourceLink {
                        sourceLinkButton(sourceLink)
                    }
                }
                .padding(PulseSpacing.large)
            }
            .background(backgroundGradient)
            .navigationTitle("Event Detail")
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            HStack(spacing: PulseSpacing.small) {
                Label(viewModel.categoryTitle, systemImage: viewModel.event.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulsePalette.color(for: viewModel.event.category))

                Text(viewModel.severityTitle)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PulsePalette.color(for: viewModel.event.severity).opacity(0.22), in: Capsule())
                    .foregroundStyle(.white)

                Spacer()

                Text(viewModel.eventTimestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Text(viewModel.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(viewModel.summary)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
        }
        .pulseGlassCard(prominent: true)
    }

    private var mapContextCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            Text("Map Context")
                .font(.headline)
                .foregroundStyle(.white)

            Map(initialPosition: .region(viewModel.mapRegion), interactionModes: .all) {
                ForEach(viewModel.mapEvents) { event in
                    Marker(event.title, coordinate: event.coordinate.clCoordinate)
                        .tint(PulsePalette.color(for: event.severity))
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: PulseCornerRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseCornerRadius.card, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
            .accessibilityLabel("Map context for selected event")
        }
        .pulseGlassCard()
    }

    private var attributesCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(viewModel.detailRows) { row in
                detailRow(row)
            }
        }
        .pulseGlassCard()
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            Text("Metadata")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(viewModel.metadataRows) { row in
                detailRow(row)
            }
        }
        .pulseGlassCard()
    }

    private func sourceLinkButton(_ link: URL) -> some View {
        Link("Open Source Link", destination: link)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .background(PulsePalette.accent.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .accessibilityLabel("Open source link")
    }

    @ViewBuilder
    private func detailRow(_ row: EventDetailRow) -> some View {
        HStack {
            Text(row.label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(row.value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [PulsePalette.backgroundTop, PulsePalette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    EventDetailView(viewModel: EventDetailViewModel(mapItem: PulseMapItem(
        id: "preview-event",
        coordinate: PulseCoordinate(latitude: 34.05, longitude: -118.24),
        events: [
            PulseEvent(
                id: "preview-event",
                title: "Severe Storm Activity",
                summary: "Active storm track near coastal region.",
                category: .hazards,
                severity: .high,
                source: .eonet,
                timestamp: .now,
                coordinate: PulseCoordinate(latitude: 34.05, longitude: -118.24),
                link: URL(string: "https://eonet.gsfc.nasa.gov"),
                metadata: ["Category": "Severe Storms", "Wind": "78 kts"]
            )
        ]
    )))
}
