import Foundation
import PolarBleSdk
import RxSwift
import CoreBluetooth
import Observation

@Observable
class BluetoothManager: PolarBleApiObserver, PolarBleApiPowerStateObserver, PolarBleApiDeviceFeaturesObserver {
    
    private var api: PolarBleApi!
    private let disposeBag = DisposeBag()
    
    var connectionState: String = "No Sensor Detected"
    var isConnected: Bool = false
    var currentBpm: Int = 0
    
    struct DiscoveredDevice: Identifiable {
        let id: String
        let name: String
        let rssi: Int
    }
    var discoveredDevices: [DiscoveredDevice] = []
    
    init() {
        api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: [
            .feature_hr,
            .feature_polar_online_streaming
        ])
        
        api.observer = self
        api.powerStateObserver = self
        api.deviceFeaturesObserver = self
    }
    
    func startScanning() {
        discoveredDevices.removeAll()
        connectionState = "Scanning for Polar devices..."
        
        api.searchForDevice()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] deviceInfo in
                if deviceInfo.name.contains("H10") {
                    let newDevice = DiscoveredDevice(id: deviceInfo.deviceId, name: deviceInfo.name, rssi: deviceInfo.rssi)
                    if !(self?.discoveredDevices.contains(where: { $0.id == newDevice.id }) ?? true) {
                        self?.discoveredDevices.append(newDevice)
                    }
                }
            }, onError: { error in
                print("Scan Error: \(error)")
            })
            .disposed(by: disposeBag)
    }
    
    func connectToDevice(id: String) {
        connectionState = "Connecting to \(id)..."
        do {
            try api.connectToDevice(id)
        } catch {
            print("Failed to connect: \(error)")
            connectionState = "Connection Failed"
        }
    }
    
    func disconnectFromDevice(id: String) {
        do {
            try api.disconnectFromDevice(id)
        } catch {
            print("Failed to disconnect: \(error)")
        }
    }
    
    // MARK: - Polar API Callbacks
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        connectionState = "Connecting..."
    }
    
    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        isConnected = true
        connectionState = "Polar H10 Connected"
        discoveredDevices.removeAll()
    }
    
    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        isConnected = false
        connectionState = "No Sensor Detected"
        currentBpm = 0
    }
    
    func blePowerOn() {
        print("BLE Hardware ist bereit")
    }
    
    func blePowerOff() {
        connectionState = "Bluetooth is turned OFF"
        isConnected = false
    }
    
    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
        print("Feature ready: \(feature)")
        
        if feature == .feature_hr {
            api.startHrStreaming(identifier)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onNext: { [weak self] hrData in
                        if let sample = hrData.first {
                            self?.currentBpm = Int(sample.hr)
                        }
                    }, onError: { error in
                        print("HR Stream Error: \(error)")
                    })
                    .disposed(by: disposeBag)
        }
    }
}
