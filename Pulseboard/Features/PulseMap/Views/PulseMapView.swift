import MapKit
import SwiftUI

private enum HighlightsOverlayState: Int, CaseIterable {
    case hidden
    case peek
    case expanded

    func nextExpandedState() -> HighlightsOverlayState {
        switch self {
        case .hidden:
            .peek
        case .peek:
            .expanded
        case .expanded:
            .expanded
        }
    }

    func nextCollapsedState() -> HighlightsOverlayState {
        switch self {
        case .hidden:
            .hidden
        case .peek:
            .hidden
        case .expanded:
            .peek
        }
    }
}

private enum MapZoomLevel: Equatable {
    case global
    case regional
    case local

    init(latitudeDelta: CLLocationDegrees) {
        if latitudeDelta > 70 {
            self = .global
        } else if latitudeDelta > 20 {
            self = .regional
        } else {
            self = .local
        }
    }
}

struct PulseMapView: View {
    @StateObject private var viewModel: PulseMapViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedMapItem: PulseMapItem?
    @State private var isFilterTrayExpanded = false
    @State private var isExplorePresented = false
    @State private var overlayState: HighlightsOverlayState = .hidden
    @State private var zoomLevel: MapZoomLevel = .global
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
            ForEach(visibleMapItems) { item in
                Annotation(annotationTitle(for: item), coordinate: item.coordinate.clCoordinate) {
                    PulseMarkerView(item: item, zoomLevel: zoomLevel)
                        .onTapGesture {
                            selectedMapItem = item
                        }
                        .accessibilityLabel(markerAccessibilityLabel(for: item))
                        .zIndex(markerZIndex(for: item))
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            let nextLevel = MapZoomLevel(latitudeDelta: context.region.span.latitudeDelta)
            if nextLevel != zoomLevel {
                zoomLevel = nextLevel
            }
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.22), value: isFilterTrayExpanded)
    }

    private var topBar: some View {
        HStack(spacing: PulseSpacing.small) {
            regionMenuControl
            filterToggleControl
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regionMenuControl: some View {
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
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.17), lineWidth: 1)
                    }
            }
        }
    }

    private var filterToggleControl: some View {
        Button {
            isFilterTrayExpanded.toggle()
        } label: {
            Image(systemName: isFilterTrayExpanded ? "slider.horizontal.3.circle.fill" : "slider.horizontal.3")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFilterTrayExpanded ? PulsePalette.accent : .white)
                .padding(9)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle().stroke(.white.opacity(0.17), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFilterTrayExpanded ? "Hide filters" : "Show filters")
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
        .padding(PulseSpacing.medium)
        .frame(maxWidth: 560, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                        .stroke(.white.opacity(0.17), lineWidth: 1)
                }
        }
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
        guard overlayState != .hidden else {
            return AnyView(
                VStack {
                    Spacer()
                    minimizedHighlightsDockButton
                        .padding(.bottom, max(PulseSpacing.large, geometry.safeAreaInsets.bottom))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, PulseSpacing.large)
                .ignoresSafeArea(edges: .bottom)
            )
        }

        let safeBottomInset = max(PulseSpacing.small, geometry.safeAreaInsets.bottom)
        let minimumHeight = phoneDrawerHeight(for: .peek, in: geometry.size.height, safeBottomInset: safeBottomInset)
        let targetHeight = phoneDrawerHeight(for: overlayState, in: geometry.size.height, safeBottomInset: safeBottomInset)
        let dragAdjustment = max(0, phoneDrawerDragTranslation)
        let effectiveHeight = max(minimumHeight, targetHeight - dragAdjustment)

        return AnyView(VStack {
            Spacer()

            VStack(alignment: .leading, spacing: PulseSpacing.small) {
                HStack {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.34))
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity)

                    Button {
                        setOverlayState(.hidden)
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Minimize highlights")
                }
                .padding(.top, PulseSpacing.tiny)

                PulseHighlightsPanel(
                    events: viewModel.featuredEvents,
                    lastUpdated: viewModel.lastUpdated,
                    maxSecondaryEvents: overlayState == .expanded ? 2 : 1,
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
                guard overlayState == .peek else {
                    return
                }
                setOverlayState(.expanded)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Pulse Highlights Drawer")
            .accessibilityHint("Drag up to expand, drag down to minimize")
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: overlayState)
        }
        .ignoresSafeArea(edges: .bottom))
    }

    private var iPadSidePanel: some View {
        HStack {
            Spacer()

            if overlayState == .hidden {
                minimizedHighlightsDockButton
                    .padding(.top, 132)
                    .padding(.trailing, PulseSpacing.large)
            } else {
                VStack(alignment: .trailing, spacing: PulseSpacing.small) {
                    Button {
                        setOverlayState(.hidden)
                    } label: {
                        Label("Minimize", systemImage: "sidebar.trailing")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, PulseSpacing.small)
                            .padding(.vertical, PulseSpacing.tiny)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Minimize highlights panel")

                    PulseHighlightsPanel(
                        events: viewModel.featuredEvents,
                        lastUpdated: viewModel.lastUpdated,
                        maxSecondaryEvents: overlayState == .expanded ? 4 : 2,
                        displayMode: panelDisplayMode,
                        onSelect: presentEvent,
                        onExplore: { isExplorePresented = true }
                    )
                    .frame(width: overlayState == .expanded ? 360 : 332)
                }
                .padding(.top, 132)
                .padding(.trailing, PulseSpacing.large)
                .padding(.bottom, PulseSpacing.large)
            }
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
        switch overlayState {
        case .hidden:
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
                    setOverlayState(overlayState.nextExpandedState())
                } else if dragDistance >= 65 {
                    setOverlayState(overlayState.nextCollapsedState())
                }
            }
    }

    private func setOverlayState(_ state: HighlightsOverlayState) {
        let update = {
            overlayState = state
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86), update)
        }
    }

    private func phoneDrawerHeight(for state: HighlightsOverlayState, in screenHeight: CGFloat, safeBottomInset: CGFloat) -> CGFloat {
        switch state {
        case .hidden:
            return 0
        case .peek:
            return min(232, max(196, screenHeight * 0.28)) + safeBottomInset
        case .expanded:
            return min(470, max(320, screenHeight * 0.56)) + safeBottomInset
        }
    }

    private var minimizedHighlightsDockButton: some View {
        Button {
            setOverlayState(.peek)
        } label: {
            Label("Pulse Highlights", systemImage: "waveform.path.ecg.rectangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, PulseSpacing.medium)
                .padding(.vertical, PulseSpacing.small)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show pulse highlights")
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

    private var visibleMapItems: [PulseMapItem] {
        viewModel.mapItems.filter { item in
            if item.isCluster {
                return true
            }

            switch zoomLevel {
            case .global:
                return item.primaryEvent.severity.rank >= PulseSeverity.high.rank
            case .regional:
                return item.primaryEvent.severity.rank >= PulseSeverity.moderate.rank
            case .local:
                return true
            }
        }
    }

    private func annotationTitle(for item: PulseMapItem) -> String {
        guard zoomLevel == .local, !item.isCluster else {
            return ""
        }
        return item.primaryEvent.title
    }

    private func markerZIndex(for item: PulseMapItem) -> Double {
        if item.isCluster {
            return 5 + Double(min(6, item.count))
        }
        return Double(item.primaryEvent.severity.rank)
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
    private enum MarkerImportance {
        case primary
        case secondary
        case background
    }

    let item: PulseMapItem
    let zoomLevel: MapZoomLevel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            if !reduceMotion, markerImportance == .primary, zoomLevel != .global || item.isCluster {
                Circle()
                    .stroke(markerColor.opacity(markerOpacity * 0.55), lineWidth: 2)
                    .frame(width: markerSize * 1.7, height: markerSize * 1.7)
                    .scaleEffect(animatePulse ? 1.08 : 0.92)
                    .opacity(animatePulse ? 0.18 : 0.54)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animatePulse)
            }

            Circle()
                .fill(markerColor.opacity(markerOpacity))
                .frame(width: markerSize, height: markerSize)
                .overlay {
                    Circle()
                        .stroke(
                            PulseIconography.tint(for: item.primaryEvent.source).opacity(markerStrokeOpacity),
                            lineWidth: markerImportance == .primary ? 1.4 : 1.0
                        )
                }

            if item.isCluster {
                Text("\(item.count)")
                    .font(markerImportance == .background ? .caption2.weight(.medium) : .caption2.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: PulseIconography.symbol(for: item.primaryEvent.category))
                    .font(markerImportance == .primary ? .caption2.weight(.bold) : .caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            animatePulse = true
        }
    }

    private var markerSize: CGFloat {
        let zoomScale: CGFloat
        switch zoomLevel {
        case .global:
            zoomScale = 0.84
        case .regional:
            zoomScale = 0.94
        case .local:
            zoomScale = 1.0
        }

        let hierarchyScale: CGFloat
        switch markerImportance {
        case .primary:
            hierarchyScale = 1.0
        case .secondary:
            hierarchyScale = 0.9
        case .background:
            hierarchyScale = 0.8
        }

        let baseSize: CGFloat
        if item.isCluster {
            baseSize = min(38, 22 + CGFloat(item.count))
        } else {
            switch item.primaryEvent.severity {
            case .severe:
                baseSize = 20
            case .high:
                baseSize = 18
            case .moderate:
                baseSize = 16
            case .low, .unknown:
                baseSize = 14
            }
        }

        return max(10, baseSize * hierarchyScale * zoomScale)
    }

    private var markerImportance: MarkerImportance {
        if item.isCluster {
            if item.count >= 6 || item.primaryEvent.severity.rank >= PulseSeverity.high.rank {
                return .primary
            }
            if item.count >= 3 || item.primaryEvent.severity.rank >= PulseSeverity.moderate.rank {
                return .secondary
            }
            return .background
        }

        switch item.primaryEvent.severity {
        case .severe, .high:
            return .primary
        case .moderate:
            return .secondary
        case .low, .unknown:
            return .background
        }
    }

    private var markerColor: Color {
        PulsePalette.color(for: item.primaryEvent.severity)
    }

    private var markerOpacity: Double {
        switch (markerImportance, zoomLevel) {
        case (.primary, _):
            return 0.94
        case (.secondary, .global):
            return 0.62
        case (.secondary, _):
            return 0.76
        case (.background, .global):
            return 0.35
        case (.background, .regional):
            return 0.5
        case (.background, .local):
            return 0.62
        }
    }

    private var markerStrokeOpacity: Double {
        switch markerImportance {
        case .primary:
            return 0.88
        case .secondary:
            return 0.72
        case .background:
            return 0.56
        }
    }
}

private struct PulseFeaturedEventCard: View {
    enum SurfaceStyle {
        case glass
        case signal
    }

    let event: PulseEvent
    var compact = true
    var surfaceStyle: SurfaceStyle = .glass

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
        .padding(surfaceStyle == .signal ? PulseSpacing.small : 0)
        .modifier(PulseOptionalGlassCard(enabled: surfaceStyle == .glass))
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
                    PulseFeaturedEventCard(event: primary, compact: false, surfaceStyle: .signal)
                        .onTapGesture {
                            onSelect(primary)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(.white.opacity(0.12))
                                .frame(height: 1)
                        }
                } else {
                    Text("No highlights for this region and filter set.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.vertical, PulseSpacing.small)
                }

                if events.count > 1 {
                    VStack(spacing: PulseSpacing.tiny) {
                        ForEach(Array(events.dropFirst().prefix(maxSecondaryEvents))) { event in
                            PulseSecondaryHighlightCard(event: event, surfaceStyle: .signal)
                                .onTapGesture {
                                    onSelect(event)
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(.white.opacity(0.09))
                                        .frame(height: 1)
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
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(PulsePalette.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
            }
        }
        .padding(displayMode == .collapsed ? PulseSpacing.small : PulseSpacing.medium)
        .background {
            if displayMode == .expanded {
                RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                    .fill(.black.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: PulseCornerRadius.panel, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            }
        }
    }
}

private struct PulseSecondaryHighlightCard: View {
    enum SurfaceStyle {
        case glass
        case signal
    }

    let event: PulseEvent
    var surfaceStyle: SurfaceStyle = .glass

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
        .padding(surfaceStyle == .signal ? PulseSpacing.small : 0)
        .modifier(PulseOptionalGlassCard(enabled: surfaceStyle == .glass))
    }
}

private struct PulseOptionalGlassCard: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.pulseGlassCard()
        } else {
            content
        }
    }
}

#Preview {
    PulseMapView()
}
