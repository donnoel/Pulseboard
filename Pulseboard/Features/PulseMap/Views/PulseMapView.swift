import MapKit
import SwiftUI

private enum PhoneHighlightsDrawerState: Int, CaseIterable {
    case collapsed
    case peek
    case expanded

    func nextExpandedState() -> PhoneHighlightsDrawerState {
        switch self {
        case .collapsed:
            .peek
        case .peek:
            .expanded
        case .expanded:
            .expanded
        }
    }

    func nextCollapsedState() -> PhoneHighlightsDrawerState {
        switch self {
        case .collapsed:
            .collapsed
        case .peek:
            .collapsed
        case .expanded:
            .peek
        }
    }
}

struct PulseMapView: View {
    @StateObject private var viewModel: PulseMapViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedMapItem: PulseMapItem?
    @State private var isFilterTrayExpanded = false
    @State private var isExplorePresented = false
    @State private var phoneDrawerState: PhoneHighlightsDrawerState = .peek
    @GestureState private var phoneDrawerDragTranslation: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: PulseMapViewModel = PulseMapViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _cameraPosition = State(initialValue: .region(PulseRegion.world.defaultMapRegion))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                mapLayer
                gradientScrim
                topControls

                if isWideLayout(for: geometry.size) {
                    iPadSidePanel
                } else {
                    iPhoneBottomPanel(in: geometry)
                }

                if viewModel.isLoading, viewModel.filteredEvents.isEmpty {
                    loadingOverlay
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .onChange(of: viewModel.selectedRegion) { _, newRegion in
                updateCamera(for: newRegion)
            }
        }
        .sheet(item: $selectedMapItem) { item in
            EventDetailView(viewModel: EventDetailViewModel(mapItem: item))
        }
        .sheet(isPresented: $isExplorePresented) {
            ExploreSignalsView(events: viewModel.filteredEvents) { selectedEvent in
                selectedMapItem = PulseMapItem(
                    id: selectedEvent.id,
                    coordinate: selectedEvent.coordinate,
                    events: [selectedEvent]
                )
            }
        }
        .alert("Live Data Unavailable", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            ForEach(viewModel.mapItems) { item in
                Annotation(item.primaryEvent.title, coordinate: item.coordinate.clCoordinate) {
                    PulseMarkerView(item: item)
                        .onTapGesture {
                            selectedMapItem = item
                        }
                        .accessibilityLabel(markerAccessibilityLabel(for: item))
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    private var gradientScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .frame(height: 220)
        .ignoresSafeArea()
    }

    private var topControls: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            topBar

            if isFilterTrayExpanded {
                filterTray
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, PulseSpacing.large)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.22), value: isFilterTrayExpanded)
    }

    private var topBar: some View {
        HStack(spacing: PulseSpacing.small) {
            Menu {
                ForEach(PulseRegion.allCases) { region in
                    Button {
                        viewModel.selectedRegion = region
                    } label: {
                        Label(
                            region.title,
                            systemImage: viewModel.selectedRegion == region ? "checkmark.circle.fill" : "globe.europe.africa.fill"
                        )
                    }
                }
            } label: {
                HStack(spacing: PulseSpacing.tiny) {
                    Image(systemName: "location.circle.fill")
                    Text(viewModel.selectedRegion.title)
                        .lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, PulseSpacing.medium)
                .padding(.vertical, PulseSpacing.small)
                .background {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.12))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        }
                }
            }

            Spacer()

            Button {
                isFilterTrayExpanded.toggle()
            } label: {
                Image(systemName: isFilterTrayExpanded ? "slider.horizontal.3.circle.fill" : "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isFilterTrayExpanded ? PulsePalette.accent : .white)
                    .padding(10)
                    .background {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .overlay {
                                Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFilterTrayExpanded ? "Hide filters" : "Show filters")
        }
        .pulseGlassCard(prominent: true)
    }

    private var filterTray: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.small) {
            HStack {
                Label("Filter Tray", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Collapse") {
                    isFilterTrayExpanded = false
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulsePalette.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PulseSpacing.small) {
                    ForEach(PulseTimeWindow.allCases) { window in
                        PulseChip(
                            title: window.title,
                            systemImage: "clock",
                            selected: viewModel.selectedTimeWindow == window,
                            tint: PulsePalette.accent
                        ) {
                            viewModel.select(timeWindow: window)
                        }
                        .accessibilityLabel("Time window \(window.title)")
                    }
                }
            }

            categoryChips
            summaryCards
        }
        .pulseGlassCard()
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseSpacing.small) {
                ForEach(PulseCategory.allCases) { category in
                    PulseChip(
                        title: category.title,
                        systemImage: PulseIconography.symbol(for: category),
                        selected: viewModel.selectedCategory == category,
                        tint: PulsePalette.color(for: category)
                    ) {
                        viewModel.selectedCategory = category
                    }
                    .accessibilityLabel("Filter \(category.title)")
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: PulseSpacing.small) {
            PulseSummaryCard(
                title: "Events",
                value: "\(viewModel.metrics.totalCount)",
                subtitle: "Visible"
            )

            PulseSummaryCard(
                title: "High Impact",
                value: "\(viewModel.metrics.severeCount)",
                subtitle: "High/Severe"
            )

            PulseSummaryCard(
                title: "Recent",
                value: "\(viewModel.metrics.recentCount)",
                subtitle: "Last 6h"
            )
        }
    }

    private func iPhoneBottomPanel(in geometry: GeometryProxy) -> some View {
        let safeBottomInset = max(PulseSpacing.small, geometry.safeAreaInsets.bottom)
        let collapsedHeight = phoneDrawerHeight(for: .collapsed, in: geometry.size.height, safeBottomInset: safeBottomInset)
        let targetHeight = phoneDrawerHeight(for: phoneDrawerState, in: geometry.size.height, safeBottomInset: safeBottomInset)
        let dragAdjustment = max(0, phoneDrawerDragTranslation)
        let effectiveHeight = max(collapsedHeight, targetHeight - dragAdjustment)

        return VStack {
            Spacer()

            VStack(alignment: .leading, spacing: PulseSpacing.small) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.34))
                    .frame(width: 44, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, PulseSpacing.tiny)

                PulseHighlightsPanel(
                    events: viewModel.featuredEvents,
                    lastUpdated: viewModel.lastUpdated,
                    maxSecondaryEvents: phoneDrawerState == .expanded ? 2 : 1,
                    displayMode: panelDisplayMode,
                    onSelect: presentEvent,
                    onExplore: { isExplorePresented = true }
                )
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, PulseSpacing.medium)
            .padding(.bottom, safeBottomInset)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: effectiveHeight, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
            }
            .padding(.horizontal, PulseSpacing.small)
            .contentShape(RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous))
            .gesture(phoneDrawerGesture)
            .onTapGesture {
                guard phoneDrawerState == .collapsed else {
                    return
                }
                setPhoneDrawerState(.peek)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Pulse Highlights Drawer")
            .accessibilityHint("Drag up to expand, drag down to collapse")
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: phoneDrawerState)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var iPadSidePanel: some View {
        HStack {
            Spacer()

            PulseHighlightsPanel(
                events: viewModel.featuredEvents,
                lastUpdated: viewModel.lastUpdated,
                maxSecondaryEvents: 4,
                displayMode: .expanded,
                onSelect: presentEvent,
                onExplore: { isExplorePresented = true }
            )
            .frame(width: 360)
            .padding(.top, 132)
            .padding(.trailing, PulseSpacing.large)
            .padding(.bottom, PulseSpacing.large)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: PulseSpacing.small) {
                ProgressView()
                    .tint(.white)
                Text("Loading live global event feeds…")
                    .foregroundStyle(.white.opacity(0.82))
                    .font(.footnote.weight(.medium))
            }
            .pulseGlassCard(prominent: true)
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.dismissError()
                }
            }
        )
    }

    private func isWideLayout(for size: CGSize) -> Bool {
        size.width >= 900
    }

    private var panelDisplayMode: PulseHighlightsPanel.DisplayMode {
        switch phoneDrawerState {
        case .collapsed:
            .collapsed
        case .peek:
            .peek
        case .expanded:
            .expanded
        }
    }

    private var phoneDrawerGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($phoneDrawerDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let dragDistance = value.translation.height
                if dragDistance <= -65 {
                    setPhoneDrawerState(phoneDrawerState.nextExpandedState())
                } else if dragDistance >= 65 {
                    setPhoneDrawerState(phoneDrawerState.nextCollapsedState())
                }
            }
    }

    private func setPhoneDrawerState(_ state: PhoneHighlightsDrawerState) {
        let update = {
            phoneDrawerState = state
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86), update)
        }
    }

    private func phoneDrawerHeight(for state: PhoneHighlightsDrawerState, in screenHeight: CGFloat, safeBottomInset: CGFloat) -> CGFloat {
        switch state {
        case .collapsed:
            return 76 + safeBottomInset
        case .peek:
            return min(232, max(196, screenHeight * 0.28)) + safeBottomInset
        case .expanded:
            return min(470, max(320, screenHeight * 0.56)) + safeBottomInset
        }
    }

    private func updateCamera(for region: PulseRegion) {
        let update = {
            cameraPosition = .region(region.defaultMapRegion)
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.45), update)
        }
    }

    private func markerAccessibilityLabel(for item: PulseMapItem) -> String {
        if item.isCluster {
            return "\(item.count) events clustered near \(item.primaryEvent.summary)"
        }

        return item.primaryEvent.title
    }

    private func presentEvent(_ event: PulseEvent) {
        selectedMapItem = PulseMapItem(
            id: event.id,
            coordinate: event.coordinate,
            events: [event]
        )
    }
}

private struct PulseSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseGlassCard()
    }
}

private struct PulseMarkerView: View {
    let item: PulseMapItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(markerColor.opacity(0.55), lineWidth: 2)
                    .frame(width: markerSize * 1.7, height: markerSize * 1.7)
                    .scaleEffect(animatePulse ? 1.08 : 0.92)
                    .opacity(animatePulse ? 0.18 : 0.54)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animatePulse)
            }

            Circle()
                .fill(markerColor)
                .frame(width: markerSize, height: markerSize)
                .overlay {
                    Circle()
                        .stroke(PulseIconography.tint(for: item.primaryEvent.source).opacity(0.88), lineWidth: 1.4)
                }

            if item.isCluster {
                Text("\(item.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: PulseIconography.symbol(for: item.primaryEvent.category))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            animatePulse = true
        }
    }

    private var markerSize: CGFloat {
        if item.isCluster {
            return min(38, 22 + CGFloat(item.count))
        }

        switch item.primaryEvent.severity {
        case .severe:
            return 20
        case .high:
            return 18
        case .moderate:
            return 16
        case .low, .unknown:
            return 14
        }
    }

    private var markerColor: Color {
        PulsePalette.color(for: item.primaryEvent.severity)
    }
}

private struct PulseFeaturedEventCard: View {
    let event: PulseEvent
    var compact = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .lineLimit(compact ? 2 : 3)

            Text(event.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(compact ? 2 : 3)

            HStack {
                Label(event.severity.title, systemImage: PulseIconography.symbol(for: event.severity))
                    .foregroundStyle(PulsePalette.color(for: event.severity))
                Spacer()
                Text(event.timestamp, style: .relative)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.68))
        }
        .frame(width: compact ? 228 : nil, alignment: .leading)
        .pulseGlassCard()
    }
}

private struct PulseHighlightsPanel: View {
    enum DisplayMode {
        case collapsed
        case peek
        case expanded
    }

    let events: [PulseEvent]
    let lastUpdated: Date?
    let maxSecondaryEvents: Int
    let displayMode: DisplayMode
    let onSelect: (PulseEvent) -> Void
    let onExplore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: displayMode == .collapsed ? PulseSpacing.tiny : PulseSpacing.medium) {
            HStack {
                Text("Pulse Highlights")
                    .font(displayMode == .collapsed ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if displayMode != .collapsed, let lastUpdated {
                    Text(lastUpdated, style: .time)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("\(events.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.76))
                }

                if displayMode == .collapsed {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }

            switch displayMode {
            case .collapsed:
                Text(events.isEmpty ? "No live signals" : "\(events.count) live signals")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
            case .peek:
                if let primary = events.first {
                    PulseSecondaryHighlightCard(event: primary)
                        .onTapGesture {
                            onSelect(primary)
                        }
                } else {
                    Text("No highlights for this region and filter set.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                if let secondary = events.dropFirst().first {
                    PulseSecondaryHighlightCard(event: secondary)
                        .onTapGesture {
                            onSelect(secondary)
                        }
                }
                Button {
                    onExplore()
                } label: {
                    Label("Explore Signals", systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(PulsePalette.accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .expanded:
                if let primary = events.first {
                    PulseFeaturedEventCard(event: primary, compact: false)
                        .onTapGesture {
                            onSelect(primary)
                        }
                } else {
                    Text("No highlights for this region and filter set.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .pulseGlassCard()
                }

                if events.count > 1 {
                    VStack(spacing: PulseSpacing.small) {
                        ForEach(Array(events.dropFirst().prefix(maxSecondaryEvents))) { event in
                            PulseSecondaryHighlightCard(event: event)
                                .onTapGesture {
                                    onSelect(event)
                                }
                        }
                    }
                }

                Button {
                    onExplore()
                } label: {
                    Label("Explore Signals", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(PulsePalette.accent.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(displayMode == .collapsed ? PulseSpacing.small : PulseSpacing.medium)
        .background {
            if displayMode == .expanded {
                RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }
}

private struct PulseSecondaryHighlightCard: View {
    let event: PulseEvent

    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.small) {
            Image(systemName: PulseIconography.symbol(for: event.category))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.color(for: event.category))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack {
                    Image(systemName: PulseIconography.symbol(for: event.source))
                        .foregroundStyle(PulseIconography.tint(for: event.source))
                    Text(event.source.title)
                    Spacer()
                    Text(event.timestamp, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseGlassCard()
    }
}

#Preview {
    PulseMapView()
}
