import SwiftUI
import MapKit
import simd
import Combine
import CoreLocation

struct TrackView: View {
    @ObservedObject var device: TrackedDevice
    @ObservedObject var locationManager: LocationManager
    let onDismiss: () -> Void

    @StateObject private var motionManager = MotionManager()
    @State private var direction: simd_float3?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var smoothedAngle: Double = 0
    @State private var smoothedHeading: Double = 0

    private var alertColor: Color {
        guard device.alertEngine.settings.alertEnabled else { return .gray }
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private var pinCoordinate: CLLocationCoordinate2D? {
        if let mock = device.mockCoordinate { return mock }
        guard let userLoc = locationManager.userLocation,
              let heading = locationManager.heading,
              let dir = direction,
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

    private var mapCameraTrigger: MapTrackCameraTrigger {
        MapTrackCameraTrigger(
            lat: locationManager.userLocation?.latitude,
            lon: locationManager.userLocation?.longitude,
            heading: smoothedHeading
        )
    }

    var body: some View {
        ZStack {
            mapBackground

            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()
                centerContent
                Spacer()
            }

            VStack {
                if !motionManager.isFlat {
                    flatWarningBanner
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: motionManager.isFlat)
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .padding(.trailing, 20)
            .padding(.top, 12)
        }
        .onAppear {
            motionManager.startMonitoring()
            updateSmoothedHeading()
            syncMapPosition()
            updateMockDirection()
            updateSmoothedAngle()
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
        .onReceive(device.provider.distancePublisher.receive(on: DispatchQueue.main)) { reading in
            if device.mockCoordinate != nil {
                updateMockDirection()
            } else {
                direction = reading.direction
            }
            updateSmoothedAngle()
        }
        .onReceive(locationManager.$heading) { _ in
            updateSmoothedHeading()
            updateSmoothedAngle()
        }
        .onChange(of: locationManager.userLocation != nil) { _, _ in
            updateMockDirection()
            updateSmoothedAngle()
        }
    }

    private var mapBackground: some View {
        Map(position: $mapPosition) {
            if locationManager.userLocation != nil {
                UserAnnotation()
            }
            if let coord = pinCoordinate {
                Annotation("", coordinate: coord) {
                    Circle()
                        .fill(alertColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapCameraKeyframeAnimator(trigger: mapCameraTrigger) { camera in
            let center = locationManager.userLocation ?? camera.centerCoordinate
            KeyframeTrack(\MapCamera.centerCoordinate) {
                LinearKeyframe(center, duration: 0.35)
            }
            KeyframeTrack(\MapCamera.heading) {
                LinearKeyframe(smoothedHeading, duration: 0.35)
            }
            KeyframeTrack(\MapCamera.distance) {
                LinearKeyframe(280, duration: 0.35)
            }
            KeyframeTrack(\MapCamera.pitch) {
                LinearKeyframe(0, duration: 0.35)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var centerContent: some View {
        VStack(spacing: 20) {
            if direction != nil {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(alertColor)
                    .rotationEffect(.radians(smoothedAngle))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                    .animation(.easeInOut(duration: 0.3), value: smoothedAngle)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "circle.dotted.circle")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Direction not available")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Text(String(format: "%.1f m", device.alertEngine.latestDistance))
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Text(device.name)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private var flatWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone.landscape")
                .font(.system(size: 18, weight: .semibold))
            Text("Place phone flat for accurate direction")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 20)
    }

    private func syncMapPosition() {
        guard let center = locationManager.userLocation else {
            mapPosition = .automatic
            return
        }
        let camera = MapCamera(
            centerCoordinate: center,
            distance: 280,
            heading: smoothedHeading,
            pitch: 0
        )
        mapPosition = .camera(camera)
    }

    private func updateMockDirection() {
        guard let mockCoord = device.mockCoordinate,
              let userLoc = locationManager.userLocation else { return }
        let lat1 = userLoc.latitude * .pi / 180
        let lon1 = userLoc.longitude * .pi / 180
        let lat2 = mockCoord.latitude * .pi / 180
        let lon2 = mockCoord.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        direction = simd_float3(Float(sin(bearing)), 0, Float(cos(bearing)))
    }

    private func updateSmoothedAngle() {
        guard let dir = direction else { return }
        let absoluteBearing = atan2(Double(dir.x), Double(dir.z))
        let headingRad = (locationManager.heading ?? 0) * .pi / 180
        let target = absoluteBearing - headingRad
        var delta = target - smoothedAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        smoothedAngle += delta
    }

    private func updateSmoothedHeading() {
        let target = locationManager.heading ?? 0
        var delta = target - smoothedHeading
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        smoothedHeading += delta
    }
}

// MARK: - Map camera animation trigger

private struct MapTrackCameraTrigger: Equatable {
    let lat: CLLocationDegrees?
    let lon: CLLocationDegrees?
    let heading: Double
}
