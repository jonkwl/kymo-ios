import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView(selectedTab: $selectedTab)
                .tag(0)
                .tabItem { Label("Capture", systemImage: "heart.text.square") }
            HistoryView()
                .tag(1)
                .tabItem { Label("Archive", systemImage: "clock.arrow.circlepath") }
            
            DevicesView()
                .tag(2)
                .tabItem { Label("Devices", systemImage: "sensor.tag.radiowaves.forward") }
        }
        .tint(.blue)
    }
}
