import SwiftUI
import Combine
import simd

struct DeviceDetailView: View {
    @ObservedObject var device: TrackedDevice
    @State private var settings: AlertSettings
    @State private var showSettings = false
    @State private var mockBattery: Double = 100.0
    @State private var direction: simd_float3?
    @State private var connectionStatus: ConnectionStatus = .disconnected
    @State private var soundPlaying = false

    init(device: TrackedDevice, settings: AlertSettings = .default) {
        self.device = device
        _settings = State(initialValue: settings)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DirectionArrowView(
                    direction: direction,
                    distance: device.alertEngine.latestDistance,
                    alertLevel: device.alertEngine.currentLevel
                )
                .padding(.top, 16)

                playSoundButton
                    .padding(.horizontal)

                if let mock = device.provider as? MockDistanceProvider {
                    mockControls(mock: mock)
                        .padding(.horizontal)
                }

                DistanceChartView(
                    history: device.distanceHistory,
                    threshold: settings.thresholdDistance
                )
            }
        }
        .navigationTitle(device.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                DeviceSettingsView(settings: $settings)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .onChange(of: settings) { _, newSettings in
            device.alertEngine.updateSettings(newSettings)
        }
        .onReceive(device.provider.distancePublisher) { reading in
            direction = reading.direction
        }
        .onReceive(device.provider.connectionStatusPublisher) { status in
            connectionStatus = status
        }
    }

    private var playSoundButton: some View {
        Button {
            device.provider.playSound()
            soundPlaying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                soundPlaying = false
            }
        } label: {
            Label(soundPlaying ? "Playing Sound..." : "Play Sound",
                  systemImage: soundPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(soundPlaying ? .gray : .blue)
        .disabled(connectionStatus == .disconnected)
    }

    private func mockControls(mock: MockDistanceProvider) -> some View {
        VStack(spacing: 8) {
            Text("Simulated Battery: \(Int(mockBattery))%")
                .font(.caption)
                .foregroundColor(.secondary)
            Slider(value: $mockBattery, in: 0...100, step: 5)
                .onChange(of: mockBattery) { _, newValue in
                    mock.setBatteryLevel(newValue)
                }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
