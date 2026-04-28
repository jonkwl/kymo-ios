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
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("The app requires Bluetooth permission to find and connect to your sensors.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .font(.subheadline.bold())
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
                handleAppearance()
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
    
    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: bleManager.isBluetoothPoweredOn ? "antenna.radiowaves.left.and.right" : "bolt.slash.fill")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(bleManager.isBluetoothPoweredOn ? Color.blue : Color.red)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bleManager.isBluetoothPoweredOn ? "Bluetooth Active" : "Bluetooth Offline")
                        .font(.headline)
                    
                    Text(bleManager.isBluetoothPoweredOn ? bleManager.connectionState : "Please turn on Bluetooth")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if bleManager.isBluetoothPoweredOn && bleManager.connectionState.contains("Scanning") {
                    ProgressView()
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var savedDevicesSection: some View {
        Section("My Devices") {
            ForEach(Array(bleManager.savedDevices.keys.sorted()), id: \.self) { id in
                let name = bleManager.savedDevices[id] ?? "Unknown Sensor"
                let isConnected = (bleManager.connectedDeviceId == id)
                
                HStack(spacing: 16) {
                    Image(systemName: isConnected ? "heart.fill" : "heart.slash")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(isConnected ? Color.green : Color.gray)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(isConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(isConnected ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if bleManager.isBluetoothPoweredOn && !bleManager.isConnecting {
                        if isConnected {
                            Button("Disconnect") {
                                bleManager.disconnectFromDevice(id: id)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        } else {
                            Button("Connect") {
                                bleManager.connectToDevice(id: id, name: name)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        bleManager.forgetDevice(id: id)
                    } label: {
                        Label("Forget", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }
    
    private var discoveredDevicesSection: some View {
        let filteredDevices = bleManager.discoveredDevices.filter { !bleManager.savedDevices.keys.contains($0.id) }
        
        return Section("Discovered Devices") {
            if filteredDevices.isEmpty {
                Text(bleManager.connectionState.contains("Scanning") ? "Searching for nearby sensors..." : "No new devices found.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            } else {
                ForEach(filteredDevices) { device in
                    HStack(spacing: 16) {
                        Image(systemName: "sensor.tag.radiowaves.forward")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button("Connect") {
                            bleManager.connectToDevice(id: device.id, name: device.name)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func handleAppearance() {
        if bleManager.isBluetoothPoweredOn && bleManager.connectedDeviceId == nil {
            bleManager.startScanning()
        }
    }
}
