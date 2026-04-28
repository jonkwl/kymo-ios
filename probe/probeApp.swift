import SwiftUI

@main
struct probeApp: App {
    @State private var sensorManager = SensorManager()
    @State private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sensorManager)
                .environment(sessionManager)
                .preferredColorScheme(.dark)
        }
    }
}
