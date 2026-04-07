import SwiftUI

struct MockSettingsSheet: View {
    @ObservedObject var device: TrackedDevice
    @Binding var isPresented: Bool

    @State private var mockBattery: Double = 100

    private var mockProvider: MockDistanceProvider? {
        device.provider as? MockDistanceProvider
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Battery Level")
                            Spacer()
                            Text(String(format: "%.0f%%", mockBattery))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $mockBattery, in: 0...100, step: 5)
                            .onChange(of: mockBattery) { _, newValue in
                                mockProvider?.setBatteryLevel(newValue)
                            }
                    }
                } header: {
                    Text("Battery")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.draw")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Drag Device Pin")
                                .font(.subheadline.weight(.medium))
                            Text("Long press the device pin on the map, then drag it to simulate a new location.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Location")
                }
            }
            .navigationTitle("Mock Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .onAppear {
                mockBattery = device.batteryLevel ?? 100
            }
        }
    }
}
