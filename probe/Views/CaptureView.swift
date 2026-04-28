import SwiftUI

struct CaptureView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(SessionManager.self) private var sessionManager
    
    @Binding var selectedTab: Int
    
    @State private var activePage = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    customTopBar
                    
                    if sessionManager.state == .idle {
                        idleInterface
                            .transition(.opacity)
                    } else {
                        activeInterface
                            .transition(.opacity)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(sessionManager.state == .idle ? .visible : .hidden, for: .tabBar)
            .toolbarBackground(Color(.systemGroupedBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .animation(.snappy(duration: 0.3), value: sessionManager.state)
        }
    }
    
    // MARK: Top Bar
    private var customTopBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .semibold))
                Text("ProCapture")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            
            Spacer()
            
            if sessionManager.state == .idle, let batteryLevel = sensorManager.sensorBatteryLevel {
                SensorBatteryBadge(batteryLevel: batteryLevel, showSensorIcon: true)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: Idle Interface
    private var idleInterface: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Button {
                sessionManager.startSession()
            } label: {
                ZStack {
                    Circle()
                        .fill(sensorManager.isConnected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
                        .frame(width: 250, height: 250)
                        .shadow(color: sensorManager.isConnected ? Color.green.opacity(0.25) : .clear, radius: 24, x: 0, y: 12)
                                
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60, weight: .medium))
                                        
                        Text("START")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                    }
                    .foregroundColor(sensorManager.isConnected ? .white : .secondary)
                }
            }
            .disabled(!sensorManager.isConnected)
            .clickyButton(weight: .medium, cornerRadius: 115)
            .scaleEffect(sensorManager.isConnected ? 1.0 : 0.96)
            .animation(.snappy(duration: 0.35, extraBounce: 0.1), value: sensorManager.isConnected)
            
            VStack(spacing: 8) {
                Text("\(sensorManager.currentBpm)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("LIVE BPM")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .opacity(sensorManager.isConnected ? 1 : 0)
            .offset(y: sensorManager.isConnected ? 0 : 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: sensorManager.isConnected)
            .onAppear {
                sessionManager.sensorManagerRef = sensorManager
            }
            
            Spacer()
            
            if !sensorManager.isConnected {
                Button {
                    selectedTab = 2
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(sensorManager.isConnecting ? Color.blue.opacity(0.15) : Color(.tertiarySystemFill))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: sensorManager.isConnecting ? "arrow.triangle.2.circlepath" : "sensor.tag.radiowaves.forward")
                                .foregroundColor(sensorManager.isConnecting ? .blue : .secondary)
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sensorManager.isConnecting ? "Connecting..." : (sensorManager.isBluetoothPoweredOn ? "No Sensor" : "Bluetooth Off"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            if sensorManager.isConnecting && !sensorManager.hasAttemptedInitialConnect {
                                Text("Finding your last device")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if !sensorManager.isConnecting {
                                Text("Tap to manage devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if sensorManager.isConnecting {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: Active Interface
    private var activeInterface: some View {
        VStack(spacing: 0) {
            TabView(selection: $activePage) {
                mainMetricsPage
                    .tag(0)
                ecgPage
                    .tag(1)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: activePage) { _, newValue in
                if newValue == 1 {
                    if sensorManager.isEcgAvailable {
                        sensorManager.startEcgStreaming()
                    }
                } else {
                    sensorManager.stopEcgStreaming()
                }
            }
            
            activeControls
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }
    
    // MARK: Active Controls Layout
    private var activeControls: some View {
        VStack(spacing: 12) {
            // LAP
            if sessionManager.state == .recording {
                Button {
                    sessionManager.addLap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text("Lap")
                    }
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                }
                .clickyButton(weight: .medium, cornerRadius: 28)
                .padding(.horizontal)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                // STOP
                if sessionManager.state == .paused {
                    controlButton(title: "End", icon: "stop.fill", color: .red) {
                        sessionManager.stopSession()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // PAUSE / RESUME
                if sessionManager.state == .recording {
                    controlButton(title: "Pause", icon: "pause.fill", color: .orange) {
                        sessionManager.pauseSession()
                    }
                } else {
                    controlButton(title: "Resume", icon: "play.fill", color: .green) {
                        sessionManager.resumeSession()
                    }
                }
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sessionManager.state)
        }
    }
    
    private func controlButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
        }
        .clickyButton(weight: .medium, cornerRadius: 28)
    }
    
    // MARK: Metrics Pages
    private var mainMetricsPage: some View {
        VStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("Elapsed Time")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                Text(sessionManager.timeString)
                    .font(.system(size: 76, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            
            HStack(spacing: 16) {
                metricCard(title: "Live BPM", value: "\(sensorManager.currentBpm)", icon: "heart.fill", iconColor: .red)
                metricCard(title: "Laps", value: "\(sessionManager.laps.count)", icon: "flag.fill", iconColor: .blue)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func metricCard(title: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var ecgPage: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("ECG View")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                EcgGridView()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                
                if sensorManager.isEcgAvailable {
                    EcgGraphView(samples: sensorManager.ecgSamples)
                        .padding(.vertical, 24)
                } else {
                    ContentUnavailableView(
                        "ECG Unavailable",
                        systemImage: "waveform.path.ecg.dotted",
                        description: Text("Connecting to sensor...")
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text("\(sensorManager.currentBpm) BPM")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.bottom, 48)
        .frame(maxHeight: .infinity)
    }
}
