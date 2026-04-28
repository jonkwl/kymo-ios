import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @Environment(BluetoothManager.self) private var bleManager
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
                
                if !bleManager.savedDevices.isEmpty {
                    savedDevicesSection
                }
                
                if bleManager.isBluetoothPoweredOn {
                    discoveredDevicesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Devices")
            .padding(.vertical, 16)
            .onAppear {
                if bleManager.isBluetoothPoweredOn && bleManager.connectedDeviceId == nil {
                    bleManager.startScanning()
                }
            }
            .onDisappear {
                bleManager.stopScanning()
            }
            .onChange(of: bleManager.isBluetoothPoweredOn) { _, isOn in
                if isOn && bleManager.connectedDeviceId == nil {
                    bleManager.startScanning()
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
                        .fill(bleManager.isBluetoothPoweredOn ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color.red.gradient))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: bleManager.isBluetoothPoweredOn ? "antenna.radiowaves.left.and.right" : "bolt.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: bleManager.isBluetoothPoweredOn && bleManager.connectionState.contains("Scanning"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bleManager.isBluetoothPoweredOn ? "Bluetooth Active" : "Bluetooth Offline")
                        .font(.headline.weight(.bold))
                    
                    Text(bleManager.isBluetoothPoweredOn ? bleManager.connectionState : "Please turn on Bluetooth")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if bleManager.isBluetoothPoweredOn && bleManager.connectionState.contains("Scanning") {
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
            ForEach(Array(bleManager.savedDevices.keys.sorted()), id: \.self) { id in
                let name = bleManager.savedDevices[id] ?? "Unknown Sensor"
                let isConnected = (bleManager.connectedDeviceId == id)
                
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
                            Text(isConnected ? "Connected" : (bleManager.isConnecting ? "Connecting..." : "Tap to connect"))
                                .font(.caption.weight(.bold))
                                .foregroundColor(isConnected ? .green : .secondary)
                            
                            if isConnected {
                                if let batteryLevel = bleManager.sensorBatteryLevel {
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
                        bleManager.disconnectFromDevice(id: id)
                    } else if bleManager.isBluetoothPoweredOn && !bleManager.isConnecting {
                        bleManager.connectToDevice(id: id, name: name)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        bleManager.forgetDevice(id: id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }
    
    // MARK: Discovered Devices Section
    private var discoveredDevicesSection: some View {
        let filteredDevices = bleManager.discoveredDevices.filter { !bleManager.savedDevices.keys.contains($0.id) }
        
        return Section("Discovered Devices") {
            if filteredDevices.isEmpty {
                Text(bleManager.connectionState.contains("Scanning") ? "Searching for nearby sensors..." : "No new devices found.")
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
                        bleManager.connectToDevice(id: device.id, name: device.name)
                    }
                }
            }
        }
    }
}
