import SwiftUI

@main
struct probeApp: App {
    @State private var bleManager = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bleManager)
                .preferredColorScheme(.dark)
        }
    }
}
