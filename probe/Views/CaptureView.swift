import SwiftUI

struct CaptureView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(SessionManager.self) private var sessionManager

    @Binding var selectedTab: Int

    // MARK: Persistent Storage
    @AppStorage("isGPSEnabled") private var isGPSEnabled = false
    @AppStorage("selectedWorkout") private var selectedSport: Sport = .running
    @AppStorage("userMaxHR") private var userMaxHR: Int = 190 // default fallback

    // UI State
    @State private var activePage = 0
    @State private var showingWorkoutSheet = false
    @State private var pendingSaveDraft: ActivitySaveDraft?

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
            .sheet(isPresented: $showingWorkoutSheet) {
                SportSelectionView(selectedSport: $selectedSport)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $pendingSaveDraft) { draft in
                ActivitySaveView(
                    draft: draft,
                    onSave: { metadata in
                        sensorManager.stopEcgStreaming()
                        sessionManager.stopSession()
                        pendingSaveDraft = nil

                        print("Saved note:", metadata.note)
                        print("Saved RPE:", metadata.rpe as Any)
                        print("Saved color:", metadata.color.rawValue)
                    },
                    onDiscard: {
                        sensorManager.stopEcgStreaming()
                        sessionManager.stopSession()
                        pendingSaveDraft = nil
                    }
                )
            }
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

            if sessionManager.state == .idle {
                if let batteryLevel = sensorManager.sensorBatteryLevel {
                    SensorBatteryBadge(batteryLevel: batteryLevel, showSensorIcon: true)
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                HStack {
                    Image(systemName: selectedSport.icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(selectedSport.rawValue.uppercased())
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: Idle Interface
    private var idleInterface: some View {
        VStack(spacing: 32) {
            Spacer()

            HStack(spacing: 12) {
                Button {
                    showingWorkoutSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedSport.icon)
                        Text(selectedSport.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .clickyButton(weight: .light, cornerRadius: 30)

                if selectedSport.useLocation {
                    Button {
                        withAnimation(.snappy) {
                            isGPSEnabled.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isGPSEnabled ? "location.fill" : "location.slash.fill")
                                .foregroundColor(isGPSEnabled ? .blue : .secondary)
                            Text("GPS")
                        }
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(isGPSEnabled ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                        .foregroundColor(isGPSEnabled ? .blue : .primary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .clickyButton(weight: .light, cornerRadius: 30)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.35, extraBounce: 0.1), value: sensorManager.isConnected)

            StartButton(
                isConnected: sensorManager.isConnected,
                selectedSportIcon: selectedSport.icon,
                selectedSportName: selectedSport.rawValue,
                action: {
                    sessionManager.startSession(sport: selectedSport)
                }
            )

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)

                    Text("BPM")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Text("\(sensorManager.currentBpm)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            .opacity(sensorManager.isConnected ? 1 : 0)
            .offset(y: sensorManager.isConnected ? 0 : 10)
            .padding(.top, 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: sensorManager.isConnected)
            .onAppear {
                sessionManager.sensorManagerRef = sensorManager
            }

            Spacer()

            if !sensorManager.isConnected {
                deviceConnectionPrompt
            }
        }
    }

    private var deviceConnectionPrompt: some View {
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

    // MARK: Active Interface
    private var activeInterface: some View {
        VStack(spacing: 0) {
            TabView(selection: $activePage) {
                recordingStatusPage
                    .tag(0)

                mainMetricsPage
                    .tag(1)

                lapMetricsPage
                    .tag(2)

                bpmGraphPage
                    .tag(3)

                if sensorManager.isEcgAvailable {
                    ecgPage
                        .tag(4)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: activePage) { _, newValue in
                if newValue == 4 && sensorManager.isEcgAvailable {
                    sensorManager.startEcgStreaming()
                } else {
                    sensorManager.stopEcgStreaming()
                }
            }

            activeControls
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }

    // MARK: Carousel Pages

    // PAGE 0: Recording Status
    private var recordingStatusPage: some View {
        let quality = sensorManager.connectionQuality
        let isRecording = sessionManager.state == .recording
        let gpsIsRecording = isGPSEnabled && selectedSport.useLocation

        return VStack(spacing: 24) {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Elapsed Time")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    Text(sessionManager.timeString)
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                metricCard(
                    title: "Heart Rate",
                    value: "\(sensorManager.currentBpm)",
                    icon: "heart.fill",
                    iconColor: .red,
                    unit: "bpm"
                )

                connectionQualityCard(quality)

                metricCard(
                    title: "RSSI",
                    value: quality.rssiText,
                    icon: "dot.radiowaves.left.and.right",
                    iconColor: .blue
                )

                metricCard(
                    title: "Packet Loss",
                    value: quality.packetLossText,
                    icon: "arrow.down.forward.and.arrow.up.backward",
                    iconColor: .orange
                )
            }

            if gpsIsRecording {
                Label("GPS is recording in the background", systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
    }

    // PAGE 1: Main View
    private var mainMetricsPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Elapsed Time")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    Text(sessionManager.timeString)
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                zoneIndicatorView
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                metricCard(title: "BPM", value: "\(sensorManager.currentBpm)", icon: "heart.fill", iconColor: .red)
                metricCard(title: "Laps", value: "\(sessionManager.laps.count)", icon: "flag.fill", iconColor: .blue)

                if selectedSport.useSpeed {
                    let unit = selectedSport.typicalPaceUnit == .minPerKm ? "min/km" : "km/h"
                    metricCard(title: selectedSport.typicalPaceUnit == .minPerKm ? "Pace" : "Speed",
                               value: "0.0",
                               icon: "speedometer",
                               iconColor: .orange,
                               unit: unit)

                    metricCard(title: "Distance",
                               value: "0.00",
                               icon: "figure.walk.motion",
                               iconColor: .purple,
                               unit: "km")
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
    }

    // PAGE 2: Lap View
    private var lapMetricsPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Last Lap Time")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    Text("00:00")
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                zoneIndicatorView
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                metricCard(title: "BPM", value: "\(sensorManager.currentBpm)", icon: "heart.fill", iconColor: .red)
                metricCard(title: "Lap BPM (Avg)", value: "0", icon: "waveform.path.ecg", iconColor: .pink)

                if selectedSport.useSpeed {
                    let unit = selectedSport.typicalPaceUnit == .minPerKm ? "min/km" : "km/h"
                    metricCard(title: "Lap \(selectedSport.typicalPaceUnit == .minPerKm ? "Pace (Avg)" : "Speed (Avg)")",
                               value: "0.0",
                               icon: "speedometer",
                               iconColor: .orange,
                               unit: unit)

                    metricCard(title: "Lap Distance",
                               value: "0.00",
                               icon: "figure.walk.motion",
                               iconColor: .purple,
                               unit: "km")
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 56)
    }

    // PAGE 3: BPM Graph
    private var bpmGraphPage: some View {
        VStack(spacing: 16) {
            Text("HEART RATE HISTORY")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            ZStack {
                EcgGridView()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

                Text("BPM Chart Visualization")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 56)
    }

    // PAGE 4: ECG
    private var ecgPage: some View {
        VStack(spacing: 16) {
            Text("ECG STREAM")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            ZStack {
                EcgGridView()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

                if sensorManager.isEcgAvailable {
                    EcgGraphView(samples: sensorManager.ecgSamples)
                        .padding(.vertical, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 56)
    }

    private func makeSaveDraft() -> ActivitySaveDraft {
        ActivitySaveDraft(
            sport: selectedSport,
            color: .blue,
            durationText: sessionManager.timeString,
            currentBpmAtEnd: sensorManager.currentBpm > 0 ? sensorManager.currentBpm : nil,
            averageBpmText: nil, // SET LATER!
            maxBpmText: nil, // SET LATER!
            lapCount: sessionManager.laps.count,
            distanceText: nil, // SET LATER!
            gpsWasEnabled: isGPSEnabled && selectedSport.useLocation,
            rrIntervalCount: nil, // SET LATER!
            ecgSampleCount: sensorManager.ecgSamples.isEmpty ? nil : sensorManager.ecgSamples.count,
            ecgWasAvailable: sensorManager.isEcgAvailable,
            startedAt: nil, // SET LATER!
            endedAt: Date()
        )
    }

    // MARK: Active Controls
    private var activeControls: some View {
        VStack(spacing: 12) {
            if sessionManager.state == .recording {
                Button {
                    sessionManager.addLap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text("Lap")
                    }
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                }
                .clickyButton(weight: .medium, cornerRadius: 36)
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                if sessionManager.state == .paused {
                    controlButton(title: "End", icon: "stop.fill", color: .red) {
                        sensorManager.stopEcgStreaming()
                        pendingSaveDraft = makeSaveDraft()
                    }
                }

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
        }
    }

    // MARK: View Components

    private var zoneIndicatorView: some View {
        let currentBpm = sensorManager.currentBpm
        let maxHR = Double(userMaxHR > 0 ? userMaxHR : 190)
        let percent = Double(currentBpm) / maxHR
        let currentZone = HeartRateZone.current(bpm: currentBpm, maxHR: Int(maxHR))

        return GeometryReader { geo in
            ZStack(alignment: .leading) {

                ZStack {
                    Capsule()
                        .fill(Color.black.opacity(0.035))

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            let zone = HeartRateZone(rawValue: index) ?? .zone1
                            let isActive = currentZone.rawValue == index

                            Capsule()
                                .fill(zone.color.opacity(isActive ? 0.8 : 0.35))
                                .frame(height: isActive ? 8 : 5)
                                .scaleEffect(x: isActive ? 1.11 : 1.0, y: 1.0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.85),
                                    value: currentZone
                                )
                        }
                    }
                    .padding(2)
                }

                let progress = (percent - 0.5) / 0.5
                let clampedProgress = CGFloat(max(0, min(1, progress)))

                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    .offset(x: (geo.size.width - 10) * clampedProgress)
                    .animation(
                        .spring(duration: 1.0, bounce: 0),
                        value: percent
                    )
            }
        }
        .frame(height: 14)
        .padding(.horizontal)
        .padding(.vertical, 10)
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

    private func connectionQualityCard(_ quality: SensorManager.ConnectionQualityMetrics) -> some View {
        let color = qualityColor(for: quality.level)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)

                Text("Quality")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(quality.scoreText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()

                if quality.score != nil {
                    Text("/100")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricCard(title: String, value: String, icon: String, iconColor: Color, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()

                if let unit = unit {
                    Text(unit)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func qualityColor(for level: SensorManager.ConnectionQualityLevel) -> Color {
        switch level {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
