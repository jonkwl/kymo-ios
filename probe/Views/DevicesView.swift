import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: App Permission Warning
                if CBCentralManager.authorization == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Permission Denied", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.orange)
                            
                            Text("The app requires Bluetooth permission to find and connect to your sensors.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                statusSection
                
                if !sensorManager.savedDevices.isEmpty {
                    savedDevicesSection
                }
                
                if sensorManager.isConnected {
                    connectionQualitySection
                }
                
                if sensorManager.isBluetoothPoweredOn {
                    discoveredDevicesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Devices")
            .contentMargins(.top, 16, for: .scrollContent)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .onAppear {
                if sensorManager.isBluetoothPoweredOn && sensorManager.connectedDeviceId == nil {
                    sensorManager.startScanning()
                }
            }
            .onDisappear {
                sensorManager.stopScanning()
            }
            .onChange(of: sensorManager.isBluetoothPoweredOn) { _, isOn in
                if isOn && sensorManager.connectedDeviceId == nil {
                    sensorManager.startScanning()
                }
            }
        }
    }
    
    // MARK: Status Section
    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(sensorManager.isBluetoothPoweredOn ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color.red.gradient))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: sensorManager.isBluetoothPoweredOn ? "antenna.radiowaves.left.and.right" : "bolt.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: sensorManager.isBluetoothPoweredOn && sensorManager.connectionState.contains("Scanning"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensorManager.isBluetoothPoweredOn ? "Bluetooth Active" : "Bluetooth Offline")
                        .font(.headline.weight(.bold))
                    
                    Text(sensorManager.isBluetoothPoweredOn ? sensorManager.connectionState : "Please turn on Bluetooth")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if sensorManager.isBluetoothPoweredOn && sensorManager.connectionState.contains("Scanning") {
                    ProgressView()
                        .tint(.blue)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    // MARK: Saved Devices Section
    private var savedDevicesSection: some View {
        Section("My Devices") {
            ForEach(Array(sensorManager.savedDevices.keys.sorted()), id: \.self) { id in
                let name = sensorManager.savedDevices[id] ?? "Unknown Sensor"
                let isConnected = (sensorManager.connectedDeviceId == id)
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(isConnected ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.gray.gradient))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: isConnected ? "heart.fill" : "heart.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Text(isConnected ? "Connected" : (sensorManager.isConnecting ? "Connecting..." : "Tap to connect"))
                                .font(.caption.weight(.bold))
                                .foregroundColor(isConnected ? .green : .secondary)
                            
                            if isConnected {
                                if let batteryLevel = sensorManager.sensorBatteryLevel {
                                    SensorBatteryBadge(batteryLevel: batteryLevel)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isConnected {
                        sensorManager.disconnectFromDevice(id: id)
                    } else if sensorManager.isBluetoothPoweredOn && !sensorManager.isConnecting {
                        sensorManager.connectToDevice(id: id, name: name)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        sensorManager.forgetDevice(id: id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }
    
    // MARK: Connection Quality Section
    private var connectionQualitySection: some View {
        let quality = sensorManager.connectionQuality
        
        return Section("Connection Quality") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(quality.level.rawValue, systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline.weight(.bold))
                        .foregroundColor(qualityColor(for: quality.level))
                    
                    Spacer()
                    
                    Text(quality.scoreText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(qualityColor(for: quality.level))
                }
                
                ProgressView(value: Double(quality.score ?? 0), total: 100)
                    .tint(qualityColor(for: quality.level))
            }
            .padding(.vertical, 6)
            
            qualityMetricRow(
                title: "RSSI",
                value: quality.rssiText,
                icon: "dot.radiowaves.left.and.right",
                color: .blue
            )
            
            qualityMetricRow(
                title: "Packet Loss",
                value: quality.packetLossText,
                icon: "arrow.down.forward.and.arrow.up.backward",
                color: .orange
            )
            
            qualityMetricRow(
                title: "Artifacts",
                value: quality.artifactText,
                icon: "waveform.path.badge.minus",
                color: .pink
            )
            
            qualityMetricRow(
                title: "Contact",
                value: contactText(for: quality),
                icon: "sensor.tag.radiowaves.forward",
                color: quality.contactStatus == false ? .red : .green
            )
            
            if !quality.supportedStreams.isEmpty {
                qualityMetricRow(
                    title: "Streams",
                    value: quality.supportedStreams.joined(separator: ", "),
                    icon: "waveform",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: Discovered Devices Section
    private var discoveredDevicesSection: some View {
        let filteredDevices = sensorManager.discoveredDevices.filter { !sensorManager.savedDevices.keys.contains($0.id) }
        
        return Section("Discovered Devices") {
            if filteredDevices.isEmpty {
                Text(sensorManager.connectionState.contains("Scanning") ? "Searching for nearby sensors..." : "No new devices found.")
                    .foregroundColor(.secondary)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredDevices) { device in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Text("Tap to connect")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sensorManager.connectToDevice(id: device.id, name: device.name)
                    }
                }
            }
        }
    }
    
    private func qualityMetricRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline.weight(.medium))
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
    
    private func contactText(for quality: SensorManager.ConnectionQualityMetrics) -> String {
        guard let contactStatus = quality.contactStatus else { return "--" }
        return contactStatus ? "OK" : "Weak"
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
