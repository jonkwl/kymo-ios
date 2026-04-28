import Foundation
import PolarBleSdk
import RxSwift
import CoreBluetooth
import Observation

@Observable
class BluetoothManager: PolarBleApiObserver, PolarBleApiPowerStateObserver, PolarBleApiDeviceFeaturesObserver {
    
    private var api: PolarBleApi!
    private let disposeBag = DisposeBag()
    private var scanDisposable: Disposable?
    
    var isBluetoothPoweredOn: Bool = false
    var isConnecting: Bool = false
    var connectedDeviceId: String? = nil
    var connectionState: String = "Initializing..."
    var currentBpm: Int = 0
    
    struct DiscoveredDevice: Identifiable {
        let id: String
        let name: String
        let rssi: Int
    }
    var discoveredDevices: [DiscoveredDevice] = []
    
    var savedDevices: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(savedDevices, forKey: "SavedPolarSensors")
        }
    }

    var lastConnectedDeviceId: String? {
        get { UserDefaults.standard.string(forKey: "LastConnectedDeviceId") }
        set { UserDefaults.standard.set(newValue, forKey: "LastConnectedDeviceId") }
    }

    private var hasAttemptedInitialConnect = false
    
    var isConnected: Bool {
        return connectedDeviceId != nil
    }
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "SavedPolarSensors") as? [String: String] {
            self.savedDevices = saved
        }
        
        api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: [
            .feature_hr,
            .feature_polar_online_streaming
        ])
        
        api.observer = self
        api.powerStateObserver = self
        api.deviceFeaturesObserver = self
    }
    
    func startScanning() {
        guard isBluetoothPoweredOn else {
            connectionState = "Bluetooth is turned off"
            return
        }
        
        guard connectedDeviceId == nil else { return }
        
        discoveredDevices.removeAll()
        connectionState = "Scanning for Polar devices..."
        
        stopScanning()
        
        scanDisposable = api.searchForDevice()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] deviceInfo in
                if deviceInfo.name.contains("H10") {
                    let newDevice = DiscoveredDevice(id: deviceInfo.deviceId, name: deviceInfo.name, rssi: deviceInfo.rssi)
                    
                    if !(self?.discoveredDevices.contains(where: { $0.id == newDevice.id }) ?? true) {
                        self?.discoveredDevices.append(newDevice)
                    }
                }
            }, onError: { [weak self] error in
                self?.connectionState = "Scan failed"
            })
    }
    
    func stopScanning() {
        scanDisposable?.dispose()
        scanDisposable = nil
        if connectedDeviceId == nil && isBluetoothPoweredOn {
            connectionState = "Ready to scan"
        }
    }
    
    func connectToDevice(id: String, name: String) {
        stopScanning()
        isConnecting = true
        connectionState = "Connecting to device..."
        do {
            try api.connectToDevice(id)
            savedDevices[id] = name
        } catch {
            isConnecting = false
            connectionState = "Connection Failed"
        }
    }
    
    func disconnectFromDevice(id: String) {
        do {
            try api.disconnectFromDevice(id)
        } catch {
            connectionState = "Disconnect Failed"
        }
    }
    
    func forgetDevice(id: String) {
        if connectedDeviceId == id {
            disconnectFromDevice(id: id)
        }
        savedDevices.removeValue(forKey: id)
        if savedDevices.isEmpty && isBluetoothPoweredOn {
            startScanning()
        }
    }
    
    func blePowerOn() {
        isBluetoothPoweredOn = true
        
        if !hasAttemptedInitialConnect, let lastId = lastConnectedDeviceId, let name = savedDevices[lastId] {
            hasAttemptedInitialConnect = true
            connectToDevice(id: lastId, name: name)
        } else {
            connectionState = "Ready"
        }
    }
    
    func blePowerOff() {
        isBluetoothPoweredOn = false
        connectedDeviceId = nil
        stopScanning()
        connectionState = "Bluetooth is OFF"
    }
    
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        connectionState = "Connecting to device..."
    }
    
    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        isConnecting = false
        connectedDeviceId = polarDeviceInfo.deviceId
        lastConnectedDeviceId = polarDeviceInfo.deviceId
        connectionState = "Connected: \(polarDeviceInfo.name)"
        discoveredDevices.removeAll()
    }
    
    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        isConnecting = false
        if connectedDeviceId == polarDeviceInfo.deviceId {
            connectedDeviceId = nil
            currentBpm = 0
            connectionState = "Not Connected"
        }
    }
    
    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
        if feature == .feature_hr {
            api.startHrStreaming(identifier)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] hrData in
                    if let sample = hrData.first {
                        self?.currentBpm = Int(sample.hr)
                    }
                })
                .disposed(by: disposeBag)
        }
    }
}
