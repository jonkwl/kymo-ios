import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "heart.text.square")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "sensor.tag.radiowaves.forward")
                }
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environment(BluetoothManager())
        .preferredColorScheme(.dark)
}
