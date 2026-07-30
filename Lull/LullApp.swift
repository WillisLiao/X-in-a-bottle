import SwiftUI

@main
struct LullApp: App {
    var body: some Scene {
        WindowGroup {
            MetalCanvas { LullRenderer() }
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .background(.black)
        }
    }
}
