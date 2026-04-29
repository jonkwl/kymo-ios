import Foundation
import PolarBleSdk
import RxSwift
import CoreBluetooth
import Observation

@Observable
class SensorManager: PolarBleApiObserver, PolarBleApiPowerStateObserver, PolarBleApiDeviceFeaturesObserver, PolarBleApiDeviceInfoObserver {
    
    @ObservationIgnored
    private var api: PolarBleApi!
    
    private let disposeBag = DisposeBag()
    private var scanDisposable: Disposable?
    
    var isBluetoothPoweredOn: Bool = false
    var isConnecting: Bool = false
    var connectedDeviceId: String? = nil
    var connectionState: String = "Initializing..."
    var sensorBatteryLevel: Int? = nil
    
    var currentBpm: Int = 0
    
    var isEcgAvailable: Bool = false
    var ecgSamples: [Double] = []
    private var ecgDisposable: Disposable?
    
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
    
    var hasAttemptedInitialConnect = false
    
    var isConnected: Bool {
        return connectedDeviceId != nil
    }
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "SavedPolarSensors") as? [String: String] {
            self.savedDevices = saved
        }
        
        api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: [
            .feature_hr,
            .feature_polar_online_streaming,
            .feature_battery_info,
            .feature_device_info
        ])

        api.observer = self
        api.powerStateObserver = self
        api.deviceFeaturesObserver = self
        api.deviceInfoObserver = self
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
            hasAttemptedInitialConnect = true
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                
            self.isBluetoothPoweredOn = true
                
            if !self.hasAttemptedInitialConnect,
                let lastId = self.lastConnectedDeviceId,
                let name = self.savedDevices[lastId] {
                self.connectToDevice(id: lastId, name: name)
            } else {
                self.connectionState = "Ready"
                self.hasAttemptedInitialConnect = true
            }
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
        hasAttemptedInitialConnect = true
        connectedDeviceId = polarDeviceInfo.deviceId
        lastConnectedDeviceId = polarDeviceInfo.deviceId
        connectionState = "Connected: \(polarDeviceInfo.name)"
        discoveredDevices.removeAll()
    }
    
    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        isConnecting = false
        hasAttemptedInitialConnect = true
        if connectedDeviceId == polarDeviceInfo.deviceId {
            connectedDeviceId = nil
            currentBpm = 0
            sensorBatteryLevel = nil
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
        
        if feature == .feature_polar_online_streaming {
            // delay for ble services to have time for registration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let id = self.connectedDeviceId else { return }
                        
                self.api.getAvailableOnlineStreamDataTypes(id)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onSuccess: { [weak self] dataTypes in
                        if dataTypes.contains(.ecg) {
                            self?.isEcgAvailable = true
                            print("ECG Feature detected and ready.")
                        }
                    }, onFailure: { error in
                        print("Discovery failed: \(error.localizedDescription). Falling back to manual check if H10.")
                        // h10 ecg fallback
                        if self.savedDevices[id]?.contains("H10") == true {
                            self.isEcgAvailable = true
                        }
                    })
                    .disposed(by: self.disposeBag)
            }
        }
    }
    
    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        self.sensorBatteryLevel = Int(batteryLevel)
    }
    
    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: PolarBleSdk.BleBasClient.ChargeState) {
        // protocol
    }
    
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        // protocol
    }
    
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {
        // protocol
    }
    
    func startEcgStreaming() {
        guard isEcgAvailable, let id = connectedDeviceId else { return }
        
        stopEcgStreaming()
        
        ecgDisposable = api.requestStreamSettings(id, feature: .ecg)
            .asObservable()
            .flatMap { [weak self] settings -> Observable<PolarEcgData> in
                guard let self = self else { return Observable.empty() }
                return self.api.startEcgStreaming(id, settings: settings.maxSettings())
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] polarEcgData in
                guard let self = self else { return }
                
                let newSamples = polarEcgData.map { Double($0.voltage) }
                
                self.ecgSamples.append(contentsOf: newSamples)
                
                if self.ecgSamples.count > 600 {
                    self.ecgSamples.removeFirst(self.ecgSamples.count - 600)
                }
            }, onError: { error in
                print("ECG Error: \(error)")
            })
    }
    
    func stopEcgStreaming() {
        ecgDisposable?.dispose()
        ecgDisposable = nil
        ecgSamples.removeAll()
    }
}
