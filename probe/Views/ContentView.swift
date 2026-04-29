import SwiftUI

struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedTab = 0
    @State private var historyPath = NavigationPath()
    
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView(selectedTab: $selectedTab)
                .tag(0)
                .tabItem { Label("Capture", systemImage: "circle.circle") }
            
            HistoryView()
                .tag(1)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            
            DevicesView()
                .tag(2)
                .tabItem { Label("Devices", systemImage: "sensor.tag.radiowaves.forward") }
            
            SettingsView()
                .tag(3)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.blue)
        .preferredColorScheme(appTheme == .light ? .light : (appTheme == .dark ? .dark : nil))
    }
}
