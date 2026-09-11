import SwiftUI

@main
struct GreenScanApp: App {
    @State private var auth = AuthState()
    @State private var diagnosisFlow = DiagnosisFlowState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(auth)
                .environment(diagnosisFlow)
        }
    }
}
