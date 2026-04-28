import SwiftUI

@main
struct probeApp: App {
    @State private var bleManager = BluetoothManager()
    @State private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bleManager)
                .environment(sessionManager)
                .preferredColorScheme(.dark)
        }
    }
}
