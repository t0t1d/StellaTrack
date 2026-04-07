import SwiftUI

struct AlertSettingsOverlay: View {
    @ObservedObject var alertEngine: AlertEngine
    var onDismiss: () -> Void

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { alertEngine.settings.thresholdDistance },
            set: { alertEngine.updateSettings(thresholdDistance: $0) }
        )
    }

    private var durationIndex: Int {
        AlertSettings.durationOptions.firstIndex(where: { $0.value == alertEngine.settings.alertDuration })
            ?? AlertSettings.durationOptions.count - 1
    }

    private let capsuleWidth: CGFloat = 88
    private let capsuleHeight: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    thresholdLabel
                        .frame(width: capsuleWidth)
                    durationLabel
                        .frame(width: capsuleWidth)
                }

                GlassEffectContainer {
                    HStack(spacing: 24) {
                        thresholdCapsule
                        durationCapsule
                    }
                }

                escalateSection
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .sensoryFeedback(.selection, trigger: Int(alertEngine.settings.thresholdDistance))
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Labels above capsules

    private var thresholdLabel: some View {
        VStack(spacing: 4) {
            routePinIcon
                .frame(height: 24)
            Text("\(Int(alertEngine.settings.thresholdDistance)) m")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 20)
        }
    }

    private var routePinIcon: some View {
        Image("RouteMarker")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 22)
            .foregroundStyle(.white)
    }

    private var durationLabel: some View {
        let options = AlertSettings.durationOptions
        let label = options[durationIndex].label
        let isInfinity = alertEngine.settings.alertDuration.isInfinite
        return VStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(height: 24)
            Group {
                if isInfinity {
                    Image(systemName: "infinity")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text(label)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(height: 20)
        }
    }

    // MARK: - Threshold capsule

    private var thresholdCapsule: some View {
        let frac = (alertEngine.settings.thresholdDistance - 1) / 99.0
        return VStack(spacing: 8) {
            glassCapsule(fraction: frac, coordinateSpaceName: "thresholdCapsule")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("thresholdCapsule"))
                        .onChanged { gesture in
                            let y = min(max(gesture.location.y, 0), capsuleHeight)
                            let t = 1.0 - (y / capsuleHeight)
                            thresholdBinding.wrappedValue = 1.0 + t * 99.0
                        }
                )

            Text("Threshold")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Duration capsule

    private var durationCapsule: some View {
        let options = AlertSettings.durationOptions
        let index = durationIndex
        let fraction = Double(index) / Double(max(options.count - 1, 1))

        return VStack(spacing: 8) {
            glassCapsule(fraction: fraction, coordinateSpaceName: "durationCapsule")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("durationCapsule"))
                        .onChanged { gesture in
                            let y = min(max(gesture.location.y, 0), capsuleHeight)
                            let t = 1.0 - (y / capsuleHeight)
                            let idx = Int((t * Double(options.count - 1)).rounded())
                            let clamped = min(max(idx, 0), options.count - 1)
                            alertEngine.settings.alertDuration = options[clamped].value
                        }
                )

            Text("Duration")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Glass capsule (no text inside)

    @ViewBuilder
    private func glassCapsule(
        fraction: Double,
        coordinateSpaceName: String
    ) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(height: max(0, capsuleHeight * fraction))
            }
            .clipShape(Capsule())
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .glassEffect(.regular, in: .capsule)
        .coordinateSpace(name: coordinateSpaceName)
        .contentShape(Capsule())
    }

    // MARK: - Escalate after

    private var escalateSection: some View {
        VStack(spacing: 10) {
            GlassEffectContainer {
                HStack(spacing: 14) {
                    ForEach(AlertSettings.escalateOptions, id: \.self) { (seconds: TimeInterval) in
                        let selected = alertEngine.settings.persistenceDuration == seconds
                        Button {
                            alertEngine.updateSettings(persistenceDuration: seconds)
                        } label: {
                            ZStack {
                                if selected {
                                    Circle().fill(.white)
                                }
                                Text("\(Int(seconds))")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(selected ? .black : .white)
                            }
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular, in: .circle)
                    }
                }
            }

            Text("Escalate After (second)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
