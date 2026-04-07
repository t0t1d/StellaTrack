import SwiftUI
import UIKit

private struct AlertSettingsWindowOverlay: ViewModifier {
    @Binding var isPresented: Bool
    var device: TrackedDevice?

    @State private var overlayWindow: UIWindow?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, show in
                if show {
                    presentOverlay()
                } else {
                    dismissOverlay()
                }
            }
    }

    private func presentOverlay() {
        guard overlayWindow == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let dismiss = {
            withAnimation {
                self.isPresented = false
            }
        }

        let overlayView = AlertOverlayContainer(
            device: device,
            onDismiss: dismiss
        )

        let hc = UIHostingController(rootView: AnyView(overlayView))
        hc.view.backgroundColor = .clear
        window.rootViewController = hc
        window.makeKeyAndVisible()
        window.alpha = 0

        self.overlayWindow = window

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            window.alpha = 1
        }
    }

    private func dismissOverlay() {
        guard let window = overlayWindow else { return }
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            window.alpha = 0
        } completion: { _ in
            window.isHidden = true
            window.rootViewController = nil
            self.overlayWindow = nil
        }
    }
}

private struct AlertOverlayContainer: View {
    var device: TrackedDevice?
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()

            if let device {
                AlertSettingsOverlay(
                    alertEngine: device.alertEngine,
                    onDismiss: onDismiss
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension View {
    func alertSettingsOverlay(
        isPresented: Binding<Bool>,
        device: TrackedDevice?
    ) -> some View {
        modifier(AlertSettingsWindowOverlay(isPresented: isPresented, device: device))
    }
}
