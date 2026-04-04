import SwiftUI
import MapKit
import Combine
import CoreLocation
import simd

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

struct MapHomeView: View {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var directionCollector = DeviceDirectionsCollector()

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedDevice: TrackedDevice?
    @State private var showAddSheet = false
    @State private var showDetail = false
    @State private var showUWBDiagnostics = false
    @State private var drawerDetent: PresentationDetent = .fraction(0.3)

    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapSize: CGSize = .zero
    /// Screen-space drag fallback: fixed geographic start until drag ends.
    @State private var activeMockDrag: (id: UUID, startCoord: CLLocationCoordinate2D)?

    var body: some View {
        MapReader { proxy in
            GeometryReader { geo in
                mapStack(proxy: proxy, mapSize: geo.size)
                    .onAppear { mapSize = geo.size }
                    .onChange(of: geo.size) { _, new in mapSize = new }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            directionCollector.bind(devices: deviceManager.devices)
        }
        .onChange(of: deviceManager.devices.map(\.id)) { _, _ in
            directionCollector.bind(devices: deviceManager.devices)
        }
        .sheet(isPresented: .constant(true)) {
            drawerContent
                .presentationDetents(
                    [.fraction(0.1), .fraction(0.3), .fraction(0.7)],
                    selection: $drawerDetent
                )
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddSheet) {
            AddDeviceSheet(deviceManager: deviceManager, isPresented: $showAddSheet)
        }
        .sheet(isPresented: $showUWBDiagnostics) {
            NavigationStack {
                UWBDiagnosticsView()
                    .navigationTitle("UWB Diagnostics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showUWBDiagnostics = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showDetail) {
            NavigationStack {
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Back") { showDetail = false }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func mapStack(proxy: MapProxy, mapSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Map(position: $position) {
                if locationManager.userLocation != nil {
                    UserAnnotation()
                }

                if let userLoc = locationManager.userLocation {
                    ForEach(deviceManager.devices) { device in
                        let distance = device.alertEngine.latestDistance
                        MapCircle(center: userLoc, radius: max(distance, 1))
                            .foregroundStyle(alertColor(for: device).opacity(0.12))
                            .stroke(alertColor(for: device).opacity(0.5), lineWidth: 1.5)
                    }
                }

                ForEach(deviceManager.devices) { device in
                    if let coord = pinCoordinate(for: device) {
                        Annotation(device.name, coordinate: coord) {
                            devicePin(
                                device: device,
                                proxy: proxy,
                                coordinate: coord,
                                mapSize: mapSize
                            )
                        }
                    }
                }
            }
            .coordinateSpace(name: "mapSpace")
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
            }
        }
    }

    @ViewBuilder
    private func devicePin(
        device: TrackedDevice,
        proxy: MapProxy,
        coordinate: CLLocationCoordinate2D,
        mapSize: CGSize
    ) -> some View {
        let color = alertColor(for: device)
        let isMockDraggable = device.mockCoordinate != nil

        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 36, height: 36)
            Image(systemName: "figure.child")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
        }
        .contentShape(Circle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("mapSpace"))
                .onChanged { value in
                    guard isMockDraggable else { return }
                    if activeMockDrag?.id != device.id {
                        activeMockDrag = (device.id, device.mockCoordinate ?? coordinate)
                    }
                    guard let anchor = activeMockDrag?.startCoord else { return }

                    if let coord = proxy.convert(value.location, from: .named("mapSpace")) {
                        updateMockFromCoordinate(device, coordinate: coord)
                    } else if let mapped = coordinateFromDrag(
                        start: anchor,
                        translation: value.translation,
                        region: visibleRegion,
                        mapSize: mapSize
                    ) {
                        updateMockFromCoordinate(device, coordinate: mapped)
                    }
                }
                .onEnded { _ in
                    if activeMockDrag?.id == device.id {
                        activeMockDrag = nil
                    }
                }
        )
    }

    private var drawerContent: some View {
        NavigationStack {
            Group {
                if let device = selectedDevice {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            selectedDevice = nil
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)

                        DeviceSummaryStrip(device: device) {
                            showDetail = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                } else {
                    List {
                        ForEach(deviceManager.devices) { device in
                            DeviceCardView(device: device)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectDevice(device)
                                }
                        }
                        .onDelete(perform: deleteDevices)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .navigationTitle("My Devices")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showUWBDiagnostics = true
                            } label: {
                                Image(systemName: "dot.radiowaves.left.and.right")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectDevice(_ device: TrackedDevice) {
        selectedDevice = device
        drawerDetent = .fraction(0.3)
        guard let coord = pinCoordinate(for: device) else { return }
        let span = max(device.alertEngine.latestDistance * 3, 50)
        let region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: span,
            longitudinalMeters: span
        )
        withAnimation {
            position = .region(region)
        }
    }

    private func deleteDevices(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let id = deviceManager.devices[index].id
            if selectedDevice?.id == id {
                selectedDevice = nil
            }
            deviceManager.removeDevice(id: id)
        }
    }

    private func pinCoordinate(for device: TrackedDevice) -> CLLocationCoordinate2D? {
        if let mock = device.mockCoordinate {
            return mock
        }
        guard let userLoc = locationManager.userLocation,
              let heading = locationManager.heading,
              let dirOpt = directionCollector.directions[device.id],
              let dir = dirOpt,
              device.alertEngine.latestDistance > 0 else { return nil }

        let distance = device.alertEngine.latestDistance
        let bearingRadians = Double(atan2(dir.x, dir.z))
        let absoluteBearing = heading * .pi / 180 + bearingRadians

        let earthRadius = 6_371_000.0
        let lat1 = userLoc.latitude * .pi / 180
        let lon1 = userLoc.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                        cos(lat1) * sin(distance / earthRadius) * cos(absoluteBearing))
        let lon2 = lon1 + atan2(sin(absoluteBearing) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi,
                                      longitude: lon2 * 180 / .pi)
    }

    private func alertColor(for device: TrackedDevice) -> Color {
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private func coordinateFromDrag(
        start: CLLocationCoordinate2D,
        translation: CGSize,
        region: MKCoordinateRegion?,
        mapSize: CGSize
    ) -> CLLocationCoordinate2D? {
        guard let region, mapSize.width > 1, mapSize.height > 1 else { return nil }
        let latPerPoint = region.span.latitudeDelta / Double(mapSize.height)
        let lonPerPoint = region.span.longitudeDelta / Double(mapSize.width)
        let dLat = Double(-translation.height) * latPerPoint
        let dLon = Double(translation.width) * lonPerPoint
        return CLLocationCoordinate2D(
            latitude: start.latitude + dLat,
            longitude: start.longitude + dLon
        )
    }

    private func updateMockFromCoordinate(_ device: TrackedDevice, coordinate: CLLocationCoordinate2D) {
        device.mockCoordinate = coordinate
        guard let userLoc = locationManager.userLocation,
              let mock = device.provider as? MockDistanceProvider else { return }

        let lat1 = userLoc.latitude * .pi / 180
        let lon1 = userLoc.longitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let lon2 = coordinate.longitude * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distance = 6_371_000.0 * c

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        let direction = simd_float3(Float(sin(bearing)), 0, Float(cos(bearing)))

        mock.setDistance(distance, direction: direction)
    }
}
