import SwiftUI

struct CaptureView: View {
    @Environment(BluetoothManager.self) private var bleManager
    @Environment(SessionManager.self) private var sessionManager
    
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if sessionManager.state == .idle {
                    idleInterface
                } else {
                    activeInterface
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: Idle Interface
    private var idleInterface: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Record button
            Button {
                sessionManager.startSession()
            } label: {
                ZStack {
                    Circle()
                        .fill(bleManager.isConnected ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 60))
                        Text("START")
                            .font(.headline.bold())
                    }
                    .foregroundColor(bleManager.isConnected ? .white : .secondary)
                }
            }
            .disabled(!bleManager.isConnected)
            
            // BPM indicator when connected but idle
            if bleManager.isConnected {
                VStack(spacing: 4) {
                    Text("\(bleManager.currentBpm)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("LIVE BPM")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // MARK: Connection Information
            if !bleManager.isConnected {
                Button {
                    selectedTab = 2
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            let icon = bleManager.isConnecting ? "arrow.triangle.2.circlepath" : "sensor.tag.radiowaves.forward.fill"
                            let color: Color = bleManager.isConnecting ? .blue : (bleManager.isBluetoothPoweredOn ? .orange : .red)
                            
                            Label(bleManager.isConnecting ? "Connecting to Sensor..." : (bleManager.isBluetoothPoweredOn ? "No Sensor Connected" : "Bluetooth Required"), systemImage: icon)
                                .font(.headline)
                                .foregroundColor(color)
                            
                            Spacer()
                            
                            if bleManager.isConnecting {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(bleManager.isConnecting ? "Re-establishing connection to your last used sensor." : (bleManager.isBluetoothPoweredOn ? "Tap to connect a sensor in the devices tab." : "Activate bluetooth to establish a connection to a sensor."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 32)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: Active Interface
    private var activeInterface: some View {
        VStack {
            // Metrics carousel
            TabView {
                mainMetricsPage
                ekgPlaceholderPage
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            Spacer()
            
            // Active controls
            VStack(spacing: 24) {
                // Lap button
                Button {
                    sessionManager.addLap()
                } label: {
                    Label("LAP", systemImage: "flag.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                }
                .padding(.horizontal)
                
                // Control row
                HStack(spacing: 20) {
                    // Stop button
                    Button {
                        sessionManager.stopSession()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .frame(width: 80, height: 80)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    
                    // Pause/resume toggle
                    Button {
                        if sessionManager.state == .recording {
                            sessionManager.pauseSession()
                        } else {
                            sessionManager.resumeSession()
                        }
                    } label: {
                        Label(sessionManager.state == .recording ? "PAUSE" : "RESUME",
                              systemImage: sessionManager.state == .recording ? "pause.fill" : "play.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(sessionManager.state == .recording ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(sessionManager.state == .recording ? .orange : .green)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: Pages
    private var mainMetricsPage: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("ELAPSED TIME")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text(sessionManager.timeString)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
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
                    Label("LAPS", systemImage: "flag.fill")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                    Text("\(sessionManager.laps.count)")
                        .font(.system(.title, design: .rounded).bold())
                }
                .telemetryCard()
            }
            .padding(.horizontal)
        }
    }
    
    private var ekgPlaceholderPage: some View {
        VStack {
            Text("EKG STREAM")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                .frame(height: 200)
                .overlay(Text("Real-time EKG Visualization").foregroundColor(.secondary))
                .padding()
        }
    }
}
