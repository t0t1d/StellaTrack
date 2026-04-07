import SwiftUI
import UIKit

private struct FloatingWindowOverlay<OverlayContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let overlayContent: () -> OverlayContent

    @State private var overlayWindow: UIWindow?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isPresented { presentOverlay() }
            }
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

        let view = overlayContent()
        let hc = UIHostingController(rootView: AnyView(view))
        hc.view.backgroundColor = .clear
        window.rootViewController = hc
        window.makeKeyAndVisible()
        window.alpha = 0

        self.overlayWindow = window

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            window.alpha = 1
        }
    }

    private func dismissOverlay() {
        guard let window = overlayWindow else { return }
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            window.alpha = 0
        } completion: { _ in
            window.isHidden = true
            window.rootViewController = nil
            self.overlayWindow = nil
        }
    }
}

extension View {
    func floatingOverlay<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(FloatingWindowOverlay(isPresented: isPresented, overlayContent: content))
    }
}
