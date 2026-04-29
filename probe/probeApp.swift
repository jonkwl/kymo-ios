import SwiftUI

@main
struct probeApp: App {
    @State private var sensorManager = SensorManager()
    @State private var sessionManager = SessionManager()
    
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sensorManager)
                .environment(sessionManager)
                .preferredColorScheme(colorScheme)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
