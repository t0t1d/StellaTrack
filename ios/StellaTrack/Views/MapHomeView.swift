import SwiftUI
import MapKit
import Combine
import CoreLocation
import simd

// MARK: - Direction collector

@MainActor
private final class DeviceDirectionsCollector: ObservableObject {
    @Published var directions: [UUID: simd_float3?] = [:]
    private var cancellables = Set<AnyCancellable>()

    func bind(devices: [TrackedDevice]) {
        cancellables.removeAll()
        let ids = Set(devices.map(\.id))
        directions = directions.filter { ids.contains($0.key) }
        for d in devices {
            d.provider.distancePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] reading in
                    self?.directions[d.id] = reading.direction
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - Custom detent for peek height

private struct PeekDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        return 88
    }
}

private struct ThirdDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        return context.maxDetentValue * 0.33
    }
}

// MARK: - MapHomeView

struct MapHomeView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var directionCollector = DeviceDirectionsCollector()

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedDeviceID: UUID?
    @State private var trackingDevice: TrackedDevice?

    private var selectedDevice: TrackedDevice? {
        guard let id = selectedDeviceID else { return nil }
        return deviceManager.devices.first { $0.id == id }
    }

    @State private var sheetPresented = true
    @State private var selectedDetent: PresentationDetent = .custom(ThirdDetent.self) // ~1/3 screen
    @State private var showStellaScan = false
    @State private var showUWBDiagnostics = false
    @State private var pendingDiagnostics = false
    @State private var showAlertSettings = false

    @State private var visibleRegion: MKCoordinateRegion?
    @State private var alertRefreshToken = 0
    @State private var currentCameraHeading: CLLocationDirection = 0
    @Namespace private var mapScope

    private let peekDetent: PresentationDetent = .custom(PeekDetent.self)
    private let defaultDetent: PresentationDetent = .custom(ThirdDetent.self)

    var body: some View {
        mapLayer
            .ignoresSafeArea()
            .overlay(alignment: .trailing) {
                locationButton
            }
            .floatingOverlay(isPresented: $showStellaScan) {
                StellaScanOverlay(
                    deviceManager: deviceManager,
                    locationManager: locationManager,
                    onDismiss: { showStellaScan = false },
                    onShowDiagnostics: {
                        pendingDiagnostics = true
                        showStellaScan = false
                    },
                    onAddMock: { addMockDevice() }
                )
            }
            .sheet(isPresented: $sheetPresented) {
                sheetContent
                    .presentationDetents(
                        [peekDetent, defaultDetent, .large],
                        selection: $selectedDetent
                    )
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationCornerRadius(44)
                    .presentationContentInteraction(.resizes)
                    .interactiveDismissDisabled()
                    .fullScreenCover(item: $trackingDevice) { device in
                        TrackView(device: device, locationManager: locationManager) {
                            trackingDevice = nil
                        }
                    }
                    .fullScreenCover(isPresented: $showUWBDiagnostics) {
                        NavigationStack {
                            UWBDiagnosticsView()
                                .navigationTitle("UWB Diagnostics")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button {
                                            showUWBDiagnostics = false
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                        }
                    }
            }
            .alertSettingsOverlay(
                isPresented: $showAlertSettings,
                device: selectedDevice
            )
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            directionCollector.bind(devices: deviceManager.devices)
        }
        .onChange(of: deviceManager.devices.map(\.id)) { _, _ in
            directionCollector.bind(devices: deviceManager.devices)
        }
        .onChange(of: showStellaScan) { _, showing in
            if !showing && pendingDiagnostics {
                pendingDiagnostics = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showUWBDiagnostics = true
                }
            }
        }
        .onReceive(locationManager.$userLocation) { loc in
            guard let loc else { return }
            deviceManager.refreshMockDistances(userLocation: loc)
        }
        .onReceive(
            deviceManager.devices
                .map { $0.alertEngine.objectWillChange }
                .reduce(Empty<Void, Never>().eraseToAnyPublisher()) { merged, pub in
                    merged.merge(with: pub.map { _ in () }.eraseToAnyPublisher()).eraseToAnyPublisher()
                }
        ) { _ in
            alertRefreshToken += 1
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
            Map(position: $position, scope: mapScope) {
                if let userLoc = locationManager.userLocation {
                    Annotation("", coordinate: userLoc) {
                        UserLocationDot(heading: locationManager.heading ?? 0, spanDelta: visibleRegion?.span.latitudeDelta)
                    }
                }
                if let userLoc = locationManager.userLocation,
                   let device = selectedDevice {
                    let threshold = device.alertEngine.settings.thresholdDistance
                    MapCircle(center: userLoc, radius: max(threshold, 1))
                        .foregroundStyle(alertColor(for: device).opacity(0.12))
                        .stroke(alertColor(for: device).opacity(0.5), lineWidth: 1.5)
                }
                let _ = alertRefreshToken
                ForEach(deviceManager.devices) { device in
                    if let coord = pinCoordinate(for: device) {
                        Annotation(device.name, coordinate: coord, anchor: .init(x: 0.5, y: 0.7)) {
                            DraggableDevicePin(
                                device: device,
                                color: alertColor(for: device),
                                direction: directionCollector.directions[device.id] ?? nil,
                                isSelected: selectedDevice?.id == device.id,
                                mapRegion: visibleRegion,
                                onSelect: { selectDevice(device) },
                                onMove: { updateMockFromCoordinate(device, coordinate: $0) }
                            )
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapScaleView()
            }
            .overlay(alignment: .topTrailing) {
                MapCompass(scope: mapScope)
                    .padding(.top, 60)
                    .padding(.trailing, 12)
            }
            .mapScope(mapScope)
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
                currentCameraHeading = context.camera.heading
            }
    }

    private var locationButton: some View {
        Button {
            recenterOnUser()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.trailing, 12)
        .offset(y: -170)
    }

    // MARK: - Sheet content

    @ViewBuilder
    private var sheetContent: some View {
        let isPeek = selectedDetent == peekDetent

        if selectedDeviceID != nil {
            TabView(selection: Binding(
                get: { selectedDeviceID ?? UUID() },
                set: { selectedDeviceID = $0 }
            )) {
                ForEach(deviceManager.devices) { device in
                    Group {
                        if isPeek {
                            deviceCollapsedRow(device)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 12)
                        } else {
                            DevicePageDrawer(
                                device: device,
                                deviceManager: deviceManager,
                                onClose: {
                                    var t = Transaction()
                                    t.disablesAnimations = true
                                    withTransaction(t) {
                                        selectedDeviceID = nil
                                    }
                                },
                                onTrack: {
                                    trackingDevice = device
                                },
                                onShowAlertSettings: {
                                    showAlertSettings = true
                                },
                                scrollEnabled: selectedDetent == .large,
                                showExtendedContent: selectedDetent == .large
                            )
                        }
                    }
                    .tag(device.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedDeviceID) { _, newID in
                guard let newID,
                      let device = deviceManager.devices.first(where: { $0.id == newID }),
                      let coord = pinCoordinate(for: device) else { return }
                let span = Swift.max(device.alertEngine.latestDistance * 3, 50)
                let offsetLat = span / 6_371_000.0 * (180.0 / .pi) * 0.35
                let adjustedCenter = CLLocationCoordinate2D(
                    latitude: coord.latitude - offsetLat,
                    longitude: coord.longitude
                )
                withAnimation {
                    position = .camera(MapCamera(
                        centerCoordinate: adjustedCenter,
                        distance: span * 2.5,
                        heading: currentCameraHeading,
                        pitch: 0
                    ))
                }
            }
        } else {
            if isPeek {
                collapsedRow
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 24)
            } else {
                deviceListContent
            }
        }
    }

    // MARK: - Device collapsed row (peek with device selected)

    private func deviceCollapsedRow(_ device: TrackedDevice) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(alertColor(for: device).opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: device.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(alertColor(for: device))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: "%.0f m", device.alertEngine.latestDistance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    selectedDeviceID = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .glassEffect(.regular.interactive().tint(.gray.opacity(0.3)), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { selectedDetent = defaultDetent }
        }
    }

    // MARK: - Collapsed row

    private var collapsedRow: some View {
        Group {
            if deviceManager.devices.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showStellaScan = true }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .glassEffect(.regular.interactive().tint(.gray.opacity(0.3)), in: .circle)
                    }
                    .buttonStyle(.plain)

                    Text("Add a device")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            } else {
                let size: CGFloat = 42

                HStack(spacing: 0) {
                    ForEach(deviceManager.devices.prefix(5)) { device in
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(alertColor(for: device).opacity(0.2))
                                    .frame(width: size, height: size)
                                Image(systemName: device.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(alertColor(for: device))
                            }
                            Text(String(device.name.prefix(8)))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectDevice(device)
                        }
                    }

                    if deviceManager.devices.count > 5 {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: size, height: size)
                                Text("+\(deviceManager.devices.count - 5)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            Text("More")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            withAnimation { selectedDetent = defaultDetent }
                        }
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showStellaScan = true }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: size, height: size)
                                .glassEffect(.regular.interactive().tint(.gray.opacity(0.3)), in: .circle)
                            Text("Add")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Device list

    private var deviceListContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Devices")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { showStellaScan = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .glassEffect(.regular.interactive().tint(.gray.opacity(0.3)), in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            if deviceManager.devices.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Devices").font(.headline)
                    Text("Tap + to add a device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(deviceManager.devices) { device in
                            Button { selectDevice(device) } label: {
                                DeviceCardView(device: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Actions

    private func addMockDevice() {
        let coord: CLLocationCoordinate2D?
        if let userLoc = locationManager.userLocation {
            coord = CLLocationCoordinate2D(
                latitude: userLoc.latitude + 0.0002,
                longitude: userLoc.longitude
            )
        } else {
            coord = nil
        }
        deviceManager.addMockDevice(
            name: "Child \(deviceManager.devices.count + 1)",
            initialCoordinate: coord,
            userLocation: locationManager.userLocation
        )
    }

    private func recenterOnUser() {
        guard let userLoc = locationManager.userLocation else {
            withAnimation { position = .userLocation(fallback: .automatic) }
            return
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1000, heading: currentCameraHeading, pitch: 0))
        }
    }

    private func selectDevice(_ device: TrackedDevice) {
        withAnimation {
            selectedDeviceID = device.id
        }
        guard let coord = pinCoordinate(for: device) else { return }
        let span = Swift.max(device.alertEngine.latestDistance * 3, 50)
        let offsetLat = span / 6_371_000.0 * (180.0 / .pi) * 0.35
        let adjustedCenter = CLLocationCoordinate2D(
            latitude: coord.latitude - offsetLat,
            longitude: coord.longitude
        )
        withAnimation {
            position = .camera(MapCamera(
                centerCoordinate: adjustedCenter,
                distance: span * 2.5,
                heading: currentCameraHeading,
                pitch: 0
            ))
        }
    }

    // MARK: - Helpers

    private func pinCoordinate(for device: TrackedDevice) -> CLLocationCoordinate2D? {
        if let mock = device.mockCoordinate { return mock }
        guard let userLoc = locationManager.userLocation,
              let heading = locationManager.heading,
              let dirOpt = directionCollector.directions[device.id],
              let dir = dirOpt,
              device.alertEngine.latestDistance > 0 else { return nil }
        let distance = device.alertEngine.latestDistance
        let bearingRad = Double(atan2(dir.x, dir.z))
        let absBearing = heading * .pi / 180 + bearingRad
        let R = 6_371_000.0
        let lat1 = userLoc.latitude * .pi / 180, lon1 = userLoc.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(distance / R) + cos(lat1) * sin(distance / R) * cos(absBearing))
        let lon2 = lon1 + atan2(sin(absBearing) * sin(distance / R) * cos(lat1),
                                cos(distance / R) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    private func alertColor(for device: TrackedDevice) -> Color {
        guard device.alertEngine.settings.alertEnabled else { return .gray }
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private func updateMockFromCoordinate(_ device: TrackedDevice, coordinate: CLLocationCoordinate2D) {
        device.mockCoordinate = coordinate
        guard let userLoc = locationManager.userLocation,
              let mock = device.provider as? MockDistanceProvider else { return }
        let lat1 = userLoc.latitude * .pi / 180, lon1 = userLoc.longitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180, lon2 = coordinate.longitude * .pi / 180
        let dLat = lat2 - lat1, dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let dist = 6_371_000.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        mock.setDistance(dist, direction: simd_float3(Float(sin(bearing)), 0, Float(cos(bearing))))
    }
}

// MARK: - Draggable device pin

private struct DraggableDevicePin: View {
    let device: TrackedDevice
    let color: Color
    let direction: simd_float3?
    let isSelected: Bool
    let mapRegion: MKCoordinateRegion?
    let onSelect: () -> Void
    let onMove: (CLLocationCoordinate2D) -> Void

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var didDrag = false
    @State private var pulseScale: CGFloat = 1.0

    private var isMock: Bool { device.mockCoordinate != nil }

    @ViewBuilder
    var body: some View {
        let styled = pinVisual
        if isMock && isSelected {
            styled
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let dist = sqrt(drag.translation.width * drag.translation.width + drag.translation.height * drag.translation.height)
                            if dist > 5 {
                                isDragging = true
                                dragOffset = drag.translation
                            }
                        }
                        .onEnded { drag in
                            if isDragging {
                                let translation = drag.translation
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isDragging = false
                                    dragOffset = .zero
                                }
                                if let region = mapRegion, let origin = device.mockCoordinate {
                                    let screen = UIScreen.main.bounds
                                    let degPerPtLon = region.span.longitudeDelta / screen.width
                                    let degPerPtLat = region.span.latitudeDelta / screen.height
                                    let newCoord = CLLocationCoordinate2D(
                                        latitude: origin.latitude - translation.height * degPerPtLat,
                                        longitude: origin.longitude + translation.width * degPerPtLon
                                    )
                                    onMove(newCoord)
                                }
                            } else {
                                onSelect()
                            }
                        }
                )
        } else {
            styled
                .onTapGesture { onSelect() }
        }
    }

    private var pinVisual: some View {
        VStack(spacing: 0) {
            ZStack {
                PinShape()
                    .fill(color)
                    .frame(width: 36, height: 48)
                PinShape()
                    .stroke(.white.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 36, height: 48)

                if !isMock, let dir = direction {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(Angle(radians: -Double(atan2(dir.x, dir.z))))
                        .offset(y: -6)
                } else {
                    Image(systemName: device.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: -6)
                }
            }
            .overlay {
                if isSelected {
                    PinShape()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .frame(width: 36, height: 48)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))
                        .onAppear {
                            pulseScale = 1.0
                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                pulseScale = 2.0
                            }
                        }
                        .onDisappear { pulseScale = 1.0 }
                }
            }
            .shadow(color: color.opacity(0.4), radius: 4, y: 2)

            Text(String(format: "%.0fm", device.alertEngine.latestDistance))
                .font(.caption2.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 2)
        }
        .scaleEffect(isDragging ? 1.3 : 1.0)
        .offset(y: isDragging ? -20 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
        .frame(width: 50, height: 70)
        .contentShape(Rectangle())
    }
}

// MARK: - User location dot with heading cone

private struct UserLocationDot: View {
    let heading: CLLocationDirection
    var spanDelta: Double?
    @Environment(\.colorScheme) private var colorScheme

    private var coneColor: Color {
        colorScheme == .dark ? Color.cyan : Color.blue
    }

    private var coneSize: CGFloat {
        guard let span = spanDelta, span > 0 else { return 80 }
        let scale = 0.005 / span
        let size = 80 * max(0.8, min(scale, 4.0))
        return size
    }

    var body: some View {
        ZStack {
            HeadingCone()
                .fill(coneColor.opacity(colorScheme == .dark ? 0.4 : 0.2))
                .frame(width: coneSize, height: coneSize)
                .rotationEffect(.degrees(heading))

            Circle()
                .fill(coneColor.opacity(0.15))
                .frame(width: 28, height: 28)
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
            Circle()
                .fill(.blue)
                .frame(width: 12, height: 12)
        }
    }
}

private struct HeadingCone: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-25 - 90), endAngle: .degrees(25 - 90),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Map pin shape

private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let circleR = rect.width / 2
        let center = CGPoint(x: rect.midX, y: circleR)
        let tipY = rect.height
        let halfSpread: CGFloat = circleR * 0.35

        var path = Path()
        let rightAngle = asin(halfSpread / circleR)
        let startDeg = Angle(radians: .pi / 2 - Double(rightAngle))
        let endDeg = Angle(radians: .pi / 2 + Double(rightAngle))

        path.addArc(center: center, radius: circleR,
                    startAngle: startDeg, endAngle: endDeg, clockwise: true)
        path.addLine(to: CGPoint(x: rect.midX, y: tipY))
        path.closeSubpath()
        return path
    }
}
