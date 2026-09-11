import SwiftUI

@main
struct GreenScanApp: App {
    @State private var auth = AuthState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(auth)
        }
    }
}
