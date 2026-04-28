import SwiftUI

struct CaptureView: View {
    @Environment(BluetoothManager.self) private var bleManager
    @Environment(SessionManager.self) private var sessionManager
    
    @Binding var selectedTab: Int
    
    @State private var isBeating = false

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
                    .font(.system(size: 22, weight: .bold))
                Text("ProCapture")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .tracking(0.5)
            }
            
            Spacer()
            
            // Sensor battery
            if sessionManager.state == .idle, let batteryLevel = bleManager.sensorBatteryLevel {
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
                        .fill(bleManager.isConnected ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.gray.opacity(0.1)))
                        .frame(width: 230, height: 230)
                        .shadow(color: bleManager.isConnected ? Color.green.opacity(0.3) : .clear, radius: 24, x: 0, y: 12)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60, weight: .medium))
                        Text("START")
                            .font(.title2.weight(.bold))
                            .tracking(2)
                    }
                    .foregroundColor(bleManager.isConnected ? .white : .secondary)
                }
            }
            .disabled(!bleManager.isConnected)
            .clickyButton(weight: .medium, cornerRadius: 115)
            .scaleEffect(bleManager.isConnected ? 1.0 : 0.95)
            .animation(.snappy(duration: 0.35, extraBounce: 0.1), value: bleManager.isConnected)
            
            VStack(spacing: 12) {
                Text("\(bleManager.currentBpm)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .scaleEffect(isBeating ? 1.3 : 1.0)
                        .animation(.spring(duration: 0.8, bounce: 0.7).repeatForever(autoreverses: true), value: isBeating)
                    
                    Text("LIVE BPM")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundColor(.secondary)
                }
            }
            .opacity(bleManager.isConnected ? 1 : 0)
            .offset(y: bleManager.isConnected ? 0 : 20)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: bleManager.isConnected)
            .onAppear {
                isBeating = true
                sessionManager.bleManager = bleManager
            }
            .onDisappear {
                isBeating = false
            }
            
            Spacer()
            
            if !bleManager.isConnected {
                Button {
                    selectedTab = 2
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(bleManager.isConnecting ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: bleManager.isConnecting ? "arrow.triangle.2.circlepath" : "sensor.tag.radiowaves.forward.fill")
                                .foregroundColor(bleManager.isConnecting ? .blue : .red)
                                .font(.system(size: 22, weight: .semibold))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bleManager.isConnecting ? "Connecting..." : (bleManager.isBluetoothPoweredOn ? "No Sensor" : "Bluetooth Off"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(bleManager.isConnecting ? "Finding your last device" : "Tap to manage devices")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if bleManager.isConnecting {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
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
            TabView {
                mainMetricsPage
                ekgPlaceholderPage
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            activeControls
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }
    
    // MARK: Active Controls Layout
    private var activeControls: some View {
        VStack(spacing: 16) {
            // LAP
            if sessionManager.state == .recording {
                Button {
                    sessionManager.addLap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                        Text("LAP")
                            .tracking(1.5)
                    }
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100) // Much larger target area
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                }
                .clickyButton(weight: .medium, cornerRadius: 32)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(spacing: 14) {
                // STOP
                if sessionManager.state == .paused {
                    controlCircle(title: "STOP", icon: "stop.fill", bgColor: .red, fgColor: .white) {
                        sessionManager.stopSession()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // PAUSE / RESUME
                if sessionManager.state == .recording {
                    controlCircle(title: "PAUSE", icon: "pause.fill", bgColor: .orange, fgColor: .white) {
                        sessionManager.pauseSession()
                    }
                } else {
                    controlCircle(title: "RESUME", icon: "play.fill", bgColor: .green, fgColor: .white) {
                        sessionManager.resumeSession()
                    }
                }
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sessionManager.state)
        }
    }
    
    private func controlCircle(title: String, icon: String, bgColor: Color, fgColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(bgColor)
            .foregroundColor(fgColor)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: bgColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .clickyButton(weight: .medium, cornerRadius: 24)
    }
    
    // MARK: Metrics Pages
    private var mainMetricsPage: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("ELAPSED TIME")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                
                Text(sessionManager.timeString)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            
            HStack(spacing: 16) {
                metricCard(title: "LIVE BPM", value: "\(bleManager.currentBpm)", icon: "heart.fill", iconColor: .red)
                metricCard(title: "LAPS", value: "\(sessionManager.laps.count)", icon: "flag.fill", iconColor: .blue)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func metricCard(title: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
    
    private var ekgPlaceholderPage: some View {
        VStack {
            Text("EKG STREAM")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.secondary)
                .tracking(1.5)
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    Text("Real-time EKG Visualization")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
