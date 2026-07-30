import SwiftUI

@main
struct BottleApp: App {
    var body: some Scene {
        WindowGroup {
            BottleScreen()
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .background(.black)
        }
    }
}

/// The whole interface. A canvas, a swipe to change what is in the bottle, and
/// the name of the world you landed in, which then gets out of the way.
struct BottleScreen: View {

    @State private var renderer = BottleRenderer()
    @State private var titleShown: String?

    /// Far enough that a stray thumb does not change environment, short enough
    /// that a deliberate swipe always lands.
    private static let swipeThreshold: CGFloat = 70

    /// Long enough to read, short enough that it never becomes furniture.
    private static let titleSeconds: Double = 2.0

    var body: some View {
        ZStack {
            MetalCanvas { renderer }

            if let titleShown {
                Text(titleShown)
                    .font(.system(size: 19, weight: .light, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.62))
                    .shadow(color: .black.opacity(0.6), radius: 12)
                    .transition(.opacity)
                    // Never interactive: a tap on the label is still a tap on
                    // the phone, and the whole app is about not doing that.
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: Self.swipeThreshold)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height)
                    else { return }
                    renderer.swipe(forward: value.translation.width < 0)
                    announce(renderer.active.title)
                }
        )
        .onAppear { announce(renderer.active.title) }
    }

    private func announce(_ title: String) {
        withAnimation(.easeOut(duration: 0.45)) { titleShown = title }

        Task {
            try? await Task.sleep(for: .seconds(Self.titleSeconds))
            guard titleShown == title else { return }
            withAnimation(.easeIn(duration: 0.9)) { titleShown = nil }
        }
    }
}
