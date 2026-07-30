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

/// The whole interface. A canvas, and a swipe to change what is in the bottle.
struct BottleScreen: View {

    @State private var renderer = BottleRenderer()

    /// Far enough that a stray thumb does not change environment, short enough
    /// that a deliberate swipe always lands.
    private static let swipeThreshold: CGFloat = 70

    var body: some View {
        MetalCanvas { renderer }
            .gesture(
                DragGesture(minimumDistance: Self.swipeThreshold)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height)
                        else { return }
                        renderer.swipe(forward: value.translation.width < 0)
                    }
            )
    }
}
