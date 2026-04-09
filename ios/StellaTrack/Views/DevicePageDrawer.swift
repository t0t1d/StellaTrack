import SwiftUI

struct DevicePageDrawer: View {
    @ObservedObject var device: TrackedDevice
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject private var alertEngine: AlertEngine

    let onClose: () -> Void
    let onTrack: () -> Void
    let onShowAlertSettings: () -> Void
    var scrollEnabled: Bool = false
    var showExtendedContent: Bool = false

    @State private var soundPlaying = false
    @State private var bellBounce = false
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showMockSheet = false

    init(
        device: TrackedDevice,
        deviceManager: DeviceManager,
        onClose: @escaping () -> Void,
        onTrack: @escaping () -> Void,
        onShowAlertSettings: @escaping () -> Void = {},
        scrollEnabled: Bool = false,
        showExtendedContent: Bool = false
    ) {
        _device = ObservedObject(wrappedValue: device)
        _deviceManager = ObservedObject(wrappedValue: deviceManager)
        _alertEngine = ObservedObject(wrappedValue: device.alertEngine)
        self.onClose = onClose
        self.onTrack = onTrack
        self.onShowAlertSettings = onShowAlertSettings
        self.scrollEnabled = scrollEnabled
        self.showExtendedContent = showExtendedContent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header

                distanceSection

                BatteryIndicatorView(level: device.batteryLevel)
                    .padding(.horizontal, 20)

                actionButtons

                if showExtendedContent {
                    DistanceChartView(
                        history: device.distanceHistory,
                        threshold: alertEngine.settings.thresholdDistance
                    )
                    .padding(.horizontal, 20)

                    Divider()
                        .padding(.horizontal, 20)

                    settingsSection
                }
            }
            .padding(.bottom, 8)
        }
        .scrollDisabled(!scrollEnabled)
        .fullScreenCover(isPresented: $showEditSheet) {
            EditDeviceSheet(device: device, isPresented: $showEditSheet)
        }
        .fullScreenCover(isPresented: $showMockSheet) {
            MockSettingsSheet(device: device, isPresented: $showMockSheet)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(device.name)
                .font(.largeTitle.bold())
                .lineLimit(1)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .glassEffect(.regular.interactive().tint(.gray.opacity(0.3)), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", alertEngine.latestDistance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("m")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            lastSeenLabel
        }
        .padding(.horizontal, 20)
    }

    private var lastSeenLabel: some View {
        Group {
            if let lastSeen = device.lastSeen {
                let elapsed = Date().timeIntervalSince(lastSeen)
                if elapsed < 10 {
                    Text("Now")
                        .foregroundStyle(.green)
                } else if elapsed < 60 {
                    Text("\(Int(elapsed))s ago")
                        .foregroundStyle(.secondary)
                } else if elapsed < 3600 {
                    Text("\(Int(elapsed / 60)) min ago")
                        .foregroundStyle(.orange)
                } else {
                    Text("\(Int(elapsed / 3600)) hr ago")
                        .foregroundStyle(.red)
                }
            } else if device.connectionStatus == .ranging || device.connectionStatus == .connected {
                Text("Connected (BLE only)")
                    .foregroundStyle(.blue)
            } else if device.connectionStatus == .searching {
                Text("Reconnecting...")
                    .foregroundStyle(.orange)
            } else {
                Text("No signal")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            alertCard
                .frame(maxWidth: .infinity)
            playSoundCard
                .frame(maxWidth: .infinity)
            trackCard
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Alert button

    @GestureState private var alertPressing = false
    @State private var alertPressWorkItem: DispatchWorkItem?
    @State private var longPressFired = false

    private var alertCard: some View {
        let enabled = alertEngine.settings.alertEnabled
        return VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(enabled ? Color.orange.opacity(0.15) : Color(.systemGray6))
                .frame(height: 56)
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: enabled ? "bell.fill" : "bell.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(enabled ? Color.orange : Color.blue)
                        Text(String(format: "%.0f m", alertEngine.settings.thresholdDistance))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(enabled ? Color.orange : Color.blue)
                    }
                }
                .scaleEffect(alertPressing ? 0.92 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: alertPressing)
            Text("Alert")
                .font(.caption)
                .foregroundStyle(Color.blue)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($alertPressing) { _, pressing, _ in
                    pressing = true
                }
                .onChanged { _ in
                    if alertPressWorkItem == nil && !longPressFired {
                        let work = DispatchWorkItem { [self] in
                            longPressFired = true
                            alertPressWorkItem = nil
                            alertEngine.setAlertEnabled(true)
                            onShowAlertSettings()
                        }
                        alertPressWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                    }
                }
                .onEnded { value in
                    alertPressWorkItem?.cancel()
                    alertPressWorkItem = nil
                    if !longPressFired {
                        let dragDistance = sqrt(
                            pow(value.translation.width, 2) + pow(value.translation.height, 2)
                        )
                        if dragDistance < 10 {
                            alertEngine.setAlertEnabled(!enabled)
                        }
                    }
                    longPressFired = false
                }
        )
    }

    @State private var soundWorkItem: DispatchWorkItem?

    private var playSoundCard: some View {
        Button {
            if soundPlaying {
                soundWorkItem?.cancel()
                soundWorkItem = nil
                device.provider.stopSound()
                withAnimation(.easeInOut(duration: 0.2)) { soundPlaying = false }
                bellBounce = false
            } else {
                device.provider.playSound()
                withAnimation(.easeInOut(duration: 0.15)) { soundPlaying = true }
                bellBounce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    bellBounce = false
                }
                let work = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.3)) { soundPlaying = false }
                    soundWorkItem = nil
                }
                soundWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(soundPlaying ? Color.orange.opacity(0.15) : Color(.systemGray6))
                    .frame(height: 56)
                    .overlay {
                        Image(systemName: soundPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.title2)
                            .symbolEffect(.bounce, value: bellBounce)
                            .foregroundStyle(soundPlaying ? Color.orange : Color.blue)
                    }
                Text(soundPlaying ? "Stop" : "Play Sound")
                    .font(.caption)
                    .foregroundStyle(isPlaySoundEnabled ? .primary : .secondary)
            }
        }
        .disabled(!isPlaySoundEnabled)
        .opacity(isPlaySoundEnabled ? 1.0 : 0.5)
    }

    private var isPlaySoundEnabled: Bool {
        device.isMock || device.connectionStatus == .connected || device.connectionStatus == .ranging
    }

    private var trackCard: some View {
        Button(action: onTrack) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
                    .frame(height: 56)
                    .overlay {
                        Image(systemName: "location.north.fill")
                            .font(.title2)
                            .foregroundStyle(Color.blue)
                    }
                Text("Track")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Settings (extended view)

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow(icon: "pencil", title: "Name & Icon", detail: device.name) {
                    showEditSheet = true
                }

                Divider().padding(.leading, 52)

                #if DEBUG
                if device.isMock {
                    settingsRow(icon: "wrench", title: "Mock Settings") {
                        showMockSheet = true
                    }

                    Divider().padding(.leading, 52)
                }
                #endif

                settingsRow(icon: "trash", title: "Remove Device", isDestructive: true) {
                    showDeleteConfirmation = true
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 40)
        .confirmationDialog(
            "Remove this device?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Device", role: .destructive) {
                deviceManager.removeDevice(id: device.id)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        detail: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isDestructive ? Color.red : Color.primary)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(isDestructive ? Color.red : Color.primary)

                Spacer(minLength: 4)

                if let detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
