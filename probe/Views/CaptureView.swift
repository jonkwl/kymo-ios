import SwiftUI

struct CaptureView: View {
    @Environment(BluetoothManager.self) private var bleManager
    
    var body: some View {
        NavigationStack {
            VStack {
                TabView {
                    VStack(spacing: 40) {
                        VStack(spacing: 8) {
                            Text("ELAPSED TIME")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            Text("00:00:00")
                                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Label("LIVE BPM", systemImage: "heart.fill")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                Text("\(bleManager.currentBpm)")
                                    .font(.system(.title, design: .rounded).bold())
                            }
                            .telemetryCard()
                            
                            VStack(alignment: .leading) {
                                Label("AVG BPM", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                                Text("--")
                                    .font(.system(.title, design: .rounded).bold())
                            }
                            .telemetryCard()
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack {
                        Text("LIVE EKG WAVEFORM")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color(.tertiarySystemBackground))
                            .frame(height: 200)
                            .overlay(Text("EKG Graph coming soon").foregroundColor(.secondary))
                            .cornerRadius(12)
                            .padding()
                    }
                }
                .tabViewStyle(.page)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {}) {
                        Label("LAP", systemImage: "flag.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: {}) {
                        Text("START")
                            .primaryButton(isEnabled: bleManager.isConnected)
                    }
                    .disabled(!bleManager.isConnected)
                }
                .padding()
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
