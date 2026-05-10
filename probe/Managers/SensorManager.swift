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
    private var hrDisposable: Disposable?
    private var rssiTimer: Timer?
    
    enum ConnectionQualityLevel: String {
        case unknown = "Unknown"
        case poor = "Poor"
        case fair = "Fair"
        case good = "Good"
        case excellent = "Excellent"
    }
    
    struct ConnectionQualityMetrics {
        var score: Int?
        var level: ConnectionQualityLevel
        var rssi: Int?
        var estimatedPacketLossPercent: Double?
        var artifactPercent: Double?
        var ppgQuality: Int?
        var contactStatus: Bool?
        var rrAvailable: Bool?
        var streamErrorCount: Int
        var lastPacketAge: TimeInterval?
        var supportedStreams: [String]
        var lastUpdatedAt: Date?
        
        static let unknown = ConnectionQualityMetrics(
            score: nil,
            level: .unknown,
            rssi: nil,
            estimatedPacketLossPercent: nil,
            artifactPercent: nil,
            ppgQuality: nil,
            contactStatus: nil,
            rrAvailable: nil,
            streamErrorCount: 0,
            lastPacketAge: nil,
            supportedStreams: [],
            lastUpdatedAt: nil
        )
        
        var scoreText: String {
            score.map(String.init) ?? "--"
        }
        
        var packetLossText: String {
            guard let estimatedPacketLossPercent else { return "--" }
            return String(format: "%.1f%%", estimatedPacketLossPercent)
        }
        
        var artifactText: String {
            guard let artifactPercent else { return "--" }
            return String(format: "%.1f%%", artifactPercent)
        }
        
        var rssiText: String {
            guard let rssi else { return "--" }
            return "\(rssi) dBm"
        }
    }
    
    private struct QualityWindowEvent {
        let receivedPackets: Int
        let missedPackets: Int
        let artifactSamples: Int
        let totalArtifactSamples: Int
    }
    
    private let expectedHrPacketInterval: TimeInterval = 1.0
    private let maxQualityWindowEvents = 120
    private var qualityWindowEvents: [QualityWindowEvent] = []
    private var availableStreamDataTypes: Set<PolarDeviceDataType> = []
    private var latestRssi: Int?
    private var latestPpgQuality: Int?
    private var latestContactStatus: Bool?
    private var latestRRAvailable: Bool?
    private var lastHrPacketDate: Date?
    private var lastStreamPacketDate: Date?
    private var streamErrorCount: Int = 0
    
    var isBluetoothPoweredOn: Bool = false
    var isConnecting: Bool = false
    var connectedDeviceId: String? = nil
    var connectionState: String = "Initializing..."
    var sensorBatteryLevel: Int? = nil
    var connectionQuality: ConnectionQualityMetrics = .unknown
    var availableOnlineStreamTypes: [String] = []
    
    var currentBpm: Int = 0
    
    enum EcgStreamState: Equatable {
        case unavailable
        case initializing
        case streaming
        case stopped
    }
    
    var isEcgAvailable: Bool = false
    var ecgSamples: [Double] = []
    var ecgRecordedSampleCount: Int = 0
    var ecgStreamState: EcgStreamState = .unavailable

    /// Total RR intervals received during the current recording session.
    var rrIntervalRecordedCount: Int = 0
    private var ecgDisposable: Disposable?
    private(set) var ecgFileWriter: EcgFileWriter?
    
    private let maxVisibleEcgSamples = 600
    private let ecgTrimThreshold = 760
    
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
    
    deinit {
        scanDisposable?.dispose()
        hrDisposable?.dispose()
        ecgDisposable?.dispose()
        stopRssiMonitoring()
        api?.cleanup()
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
                guard let self = self, deviceInfo.connectable else { return }
                
                let newDevice = DiscoveredDevice(
                    id: deviceInfo.deviceId,
                    name: self.displayName(for: deviceInfo),
                    rssi: deviceInfo.rssi
                )
                
                if let index = self.discoveredDevices.firstIndex(where: { $0.id == newDevice.id }) {
                    self.discoveredDevices[index] = newDevice
                } else {
                    self.discoveredDevices.append(newDevice)
                }
                
                self.discoveredDevices.sort { $0.rssi > $1.rssi }
            }, onError: { [weak self] error in
                self?.connectionState = "Scan failed"
                self?.registerStreamError(error, source: "Device scan")
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
        resetConnectionTelemetry()
        stopHrStreaming()
        stopEcgStreaming()
        stopRssiMonitoring()
        stopScanning()
        connectionState = "Bluetooth is OFF"
    }
    
    
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        connectionState = "Connecting to device..."
    }
    
    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        let name = displayName(for: polarDeviceInfo)
        
        isConnecting = false
        hasAttemptedInitialConnect = true
        connectedDeviceId = polarDeviceInfo.deviceId
        lastConnectedDeviceId = polarDeviceInfo.deviceId
        savedDevices[polarDeviceInfo.deviceId] = name
        connectionState = "Connected: \(name)"
        discoveredDevices.removeAll()
        resetConnectionTelemetry(initialRssi: polarDeviceInfo.rssi)
        startRssiMonitoring(for: polarDeviceInfo.deviceId)
    }
    
    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        isConnecting = false
        hasAttemptedInitialConnect = true
        if connectedDeviceId == polarDeviceInfo.deviceId {
            connectedDeviceId = nil
            currentBpm = 0
            sensorBatteryLevel = nil
            isEcgAvailable = false
            stopHrStreaming()
            stopEcgStreaming()
            stopRssiMonitoring()
            resetConnectionTelemetry()
            connectionState = "Not Connected"
        }
    }
    
    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
        if feature == .feature_hr {
            startHrStreaming(for: identifier)
            applyAvailableStreams([.hr], identifier: identifier)
        }
        
        if feature == .feature_polar_online_streaming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let id = self.connectedDeviceId else { return }
                        
                self.api.getAvailableOnlineStreamDataTypes(id)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onSuccess: { [weak self] dataTypes in
                        self?.applyAvailableStreams(dataTypes, identifier: id)
                        
                        if dataTypes.contains(.ecg) {
                            self?.isEcgAvailable = true
                            print("ECG Feature detected and ready.")
                        }
                    }, onFailure: { error in
                        print("Discovery failed: \(error.localizedDescription). Falling back to manual check if H10.")
                        if self.savedDevices[id]?.contains("H10") == true {
                            self.applyAvailableStreams([.ecg, .hr], identifier: id)
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
    }
    
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
    }
    
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {
    }
    
    func startEcgStreaming() {
        guard isEcgAvailable, let id = connectedDeviceId else { return }
        guard ecgDisposable == nil else { return }
        ecgStreamState = .initializing
        
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
                self.ecgRecordedSampleCount += newSamples.count
                self.ecgStreamState = .streaming

                // Stream to disk first — display buffer is secondary.
                self.ecgFileWriter?.write(newSamples)
                
                self.ecgSamples.append(contentsOf: newSamples)
                
                if self.ecgSamples.count > self.ecgTrimThreshold {
                    self.ecgSamples.removeFirst(self.ecgSamples.count - self.maxVisibleEcgSamples)
                }
                
                self.lastStreamPacketDate = Date()
                self.recalculateConnectionQuality()
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.ecgDisposable = nil
                self.ecgStreamState = self.isEcgAvailable ? .stopped : .unavailable
                self.registerStreamError(error, source: "ECG")
            })
    }
    
    func stopEcgStreaming(clearSamples: Bool = true) {
        ecgDisposable?.dispose()
        ecgDisposable = nil
        ecgStreamState = isEcgAvailable ? .stopped : .unavailable
        if clearSamples {
            ecgSamples.removeAll(keepingCapacity: true)
        }
    }
    
    func prepareEcgRecordingForSession(sessionId: UUID) {
        ecgRecordedSampleCount = 0
        rrIntervalRecordedCount = 0
        ecgSamples.removeAll(keepingCapacity: true)
        ecgStreamState = isEcgAvailable ? .initializing : .unavailable
        ecgFileWriter = EcgFileWriter(sessionId: sessionId)
    }

    /// Flushes and closes the ECG file, keeping it on disk. Call on the save path.
    func finalizeEcgRecording() {
        ecgFileWriter?.close()
        ecgFileWriter = nil
    }

    /// Closes and deletes the ECG file. Call on the discard path.
    func discardEcgRecording() {
        ecgFileWriter?.delete()
        ecgFileWriter = nil
    }
    
    private func startHrStreaming(for identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        stopHrStreaming()
        
        hrDisposable = api.startHrStreaming(identifier)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] hrData in
                self?.handleHrData(hrData, identifier: identifier)
            }, onError: { [weak self] error in
                self?.registerStreamError(error, source: "HR")
            })
    }
    
    private func stopHrStreaming() {
        hrDisposable?.dispose()
        hrDisposable = nil
    }
    
    private func discoverAvailableStreams(for identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        api.getAvailableOnlineStreamDataTypes(identifier)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] dataTypes in
                self?.applyAvailableStreams(dataTypes, identifier: identifier)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                
                print("Discovery failed: \(error.localizedDescription). Falling back to HR service and known device capabilities.")
                self.applyAvailableStreams(self.knownStreamFallbacks(for: identifier), identifier: identifier)
                self.discoverHrServiceStreams(for: identifier)
            })
            .disposed(by: disposeBag)
    }
    
    private func discoverHrServiceStreams(for identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        api.getAvailableHRServiceDataTypes(identifier: identifier)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] dataTypes in
                self?.applyAvailableStreams(dataTypes, identifier: identifier)
            }, onFailure: { [weak self] error in
                self?.registerStreamError(error, source: "Capability discovery")
            })
            .disposed(by: disposeBag)
    }
    
    private func applyAvailableStreams(_ dataTypes: Set<PolarDeviceDataType>, identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        availableStreamDataTypes.formUnion(dataTypes)
        availableOnlineStreamTypes = streamNames(from: availableStreamDataTypes)
        isEcgAvailable = availableStreamDataTypes.contains(.ecg)
        if !isEcgAvailable && ecgDisposable == nil {
            ecgStreamState = .unavailable
        }
        
        if isEcgAvailable {
            print("ECG Feature detected and ready.")
        }
        
        recalculateConnectionQuality()
    }
    
    private func handleHrData(_ hrData: PolarHrData, identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        let now = Date()
        let missedPackets = estimateMissedHrPackets(now: now)
        lastHrPacketDate = now
        lastStreamPacketDate = now
        
        guard let sample = hrData.first else {
            recordQualityEvent(
                receivedPackets: 1,
                missedPackets: missedPackets,
                artifactSamples: 0,
                totalArtifactSamples: 0
            )
            recalculateConnectionQuality()
            return
        }
        
        currentBpm = Int(sample.hr)
        latestPpgQuality = sample.ppgQuality > 0 ? Int(sample.ppgQuality) : nil
        latestContactStatus = sample.contactStatusSupported ? sample.contactStatus : nil
        latestRRAvailable = sample.rrAvailable

        if sample.rrAvailable && !sample.rrsMs.isEmpty {
            rrIntervalRecordedCount += sample.rrsMs.count
        }
        
        let hasPpgQuality = sample.ppgQuality > 0
        let hasContactQuality = sample.contactStatusSupported
        let hasArtifactSignal = hasPpgQuality || hasContactQuality
        let isPoorPpgQuality = hasPpgQuality && sample.ppgQuality < 50
        let isPoorContact = hasContactQuality && !sample.contactStatus
        let isArtifact = isPoorPpgQuality || isPoorContact
        
        recordQualityEvent(
            receivedPackets: 1,
            missedPackets: missedPackets,
            artifactSamples: hasArtifactSignal && isArtifact ? 1 : 0,
            totalArtifactSamples: hasArtifactSignal ? 1 : 0
        )
        recalculateConnectionQuality()
    }
    
    private func estimateMissedHrPackets(now: Date) -> Int {
        guard let lastHrPacketDate else { return 0 }
        
        let gap = now.timeIntervalSince(lastHrPacketDate)
        guard gap > expectedHrPacketInterval * 1.75 else { return 0 }
        
        return max(0, Int((gap / expectedHrPacketInterval).rounded()) - 1)
    }
    
    private func recordQualityEvent(
        receivedPackets: Int,
        missedPackets: Int,
        artifactSamples: Int,
        totalArtifactSamples: Int
    ) {
        qualityWindowEvents.append(
            QualityWindowEvent(
                receivedPackets: receivedPackets,
                missedPackets: missedPackets,
                artifactSamples: artifactSamples,
                totalArtifactSamples: totalArtifactSamples
            )
        )
        
        if qualityWindowEvents.count > maxQualityWindowEvents {
            qualityWindowEvents.removeFirst(qualityWindowEvents.count - maxQualityWindowEvents)
        }
    }
    
    private func startRssiMonitoring(for identifier: String) {
        stopRssiMonitoring()
        updateRssi(for: identifier)
        
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateRssi(for: identifier)
        }
        RunLoop.main.add(timer, forMode: .common)
        rssiTimer = timer
    }
    
    private func stopRssiMonitoring() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    private func updateRssi(for identifier: String) {
        guard connectedDeviceId == identifier else { return }
        
        do {
            latestRssi = try api.getRSSIValue(identifier)
        } catch {
            print("RSSI update failed: \(error.localizedDescription)")
        }
        
        recalculateConnectionQuality()
    }
    
    private func registerStreamError(_ error: Error, source: String) {
        streamErrorCount += 1
        print("\(source) error: \(error.localizedDescription)")
        recalculateConnectionQuality()
    }
    
    private func resetConnectionTelemetry(initialRssi: Int? = nil) {
        latestRssi = initialRssi
        latestPpgQuality = nil
        latestContactStatus = nil
        latestRRAvailable = nil
        lastHrPacketDate = nil
        lastStreamPacketDate = nil
        streamErrorCount = 0
        qualityWindowEvents.removeAll()
        availableStreamDataTypes.removeAll()
        availableOnlineStreamTypes.removeAll()
        connectionQuality = .unknown
        isEcgAvailable = false
        ecgStreamState = .unavailable
        ecgRecordedSampleCount = 0
        rrIntervalRecordedCount = 0
        ecgSamples.removeAll(keepingCapacity: true)
        ecgFileWriter?.close()
        ecgFileWriter = nil
        
        if initialRssi != nil {
            recalculateConnectionQuality()
        }
    }
    
    private func recalculateConnectionQuality() {
        guard connectedDeviceId != nil else {
            connectionQuality = .unknown
            return
        }
        
        let packetTotals = qualityWindowEvents.reduce((received: 0, missed: 0)) { totals, event in
            (
                received: totals.received + event.receivedPackets,
                missed: totals.missed + event.missedPackets
            )
        }
        let totalPackets = packetTotals.received + packetTotals.missed
        let packetLossPercent = totalPackets > 0
            ? (Double(packetTotals.missed) / Double(totalPackets)) * 100
            : nil
        
        let artifactTotals = qualityWindowEvents.reduce((artifacts: 0, total: 0)) { totals, event in
            (
                artifacts: totals.artifacts + event.artifactSamples,
                total: totals.total + event.totalArtifactSamples
            )
        }
        let artifactPercent = artifactTotals.total > 0
            ? (Double(artifactTotals.artifacts) / Double(artifactTotals.total)) * 100
            : nil
        
        let packetAge = lastStreamPacketDate.map { Date().timeIntervalSince($0) }
        let score = calculateQualityScore(
            packetLossPercent: packetLossPercent,
            artifactPercent: artifactPercent,
            packetAge: packetAge
        )
        
        var streams = availableOnlineStreamTypes
        if latestRRAvailable == true && !streams.contains("RR Intervals") {
            streams.append("RR Intervals")
            streams.sort()
        }

        connectionQuality = ConnectionQualityMetrics(
            score: score,
            level: qualityLevel(for: score),
            rssi: latestRssi,
            estimatedPacketLossPercent: packetLossPercent,
            artifactPercent: artifactPercent,
            ppgQuality: latestPpgQuality,
            contactStatus: latestContactStatus,
            rrAvailable: latestRRAvailable,
            streamErrorCount: streamErrorCount,
            lastPacketAge: packetAge,
            supportedStreams: streams,
            lastUpdatedAt: Date()
        )
    }
    
    private func calculateQualityScore(
        packetLossPercent: Double?,
        artifactPercent: Double?,
        packetAge: TimeInterval?
    ) -> Int? {
        var score = 100.0
        var hasSignal = false
        
        if let latestRssi {
            hasSignal = true
            switch latestRssi {
            case let value where value >= -65:
                score -= 0
            case -75..<(-65):
                score -= 8
            case -85..<(-75):
                score -= 20
            case -95..<(-85):
                score -= 35
            default:
                score -= 50
            }
        }
        
        if let packetLossPercent {
            hasSignal = true
            score -= min(45, packetLossPercent * 2)
        }
        
        if let artifactPercent {
            hasSignal = true
            score -= min(35, artifactPercent * 1.5)
        }
        
        if latestContactStatus == false {
            hasSignal = true
            score -= 25
        }
        
        if let packetAge {
            hasSignal = true
            if packetAge > 5 {
                score -= min(35, (packetAge - 5) * 4)
            }
        }
        
        if streamErrorCount > 0 {
            hasSignal = true
            score -= min(20, Double(streamErrorCount * 4))
        }
        
        guard hasSignal else { return nil }
        return Int(max(0, min(100, score)).rounded())
    }
    
    private func qualityLevel(for score: Int?) -> ConnectionQualityLevel {
        guard let score else { return .unknown }
        
        switch score {
        case 85...:
            return .excellent
        case 70..<85:
            return .good
        case 50..<70:
            return .fair
        default:
            return .poor
        }
    }
    
    private func displayName(for deviceInfo: PolarDeviceInfo) -> String {
        deviceInfo.name.isEmpty ? "Polar \(deviceInfo.deviceId)" : deviceInfo.name
    }
    
    private func streamNames(from dataTypes: Set<PolarDeviceDataType>) -> [String] {
        dataTypes.map(streamName(for:)).sorted()
    }
    
    private func knownStreamFallbacks(for identifier: String) -> Set<PolarDeviceDataType> {
        guard let deviceName = savedDevices[identifier]?.uppercased() else { return [] }
        
        if deviceName.contains("H10") {
            return [.ecg, .hr]
        }
        
        return []
    }
    
    private func streamName(for dataType: PolarDeviceDataType) -> String {
        switch dataType {
        case .ecg:
            return "ECG"
        case .acc:
            return "ACC"
        case .ppg:
            return "PPG"
        case .ppi:
            return "PPI"
        case .gyro:
            return "Gyro"
        case .magnetometer:
            return "Magnetometer"
        case .hr:
            return "HR"
        case .temperature:
            return "Temperature"
        case .pressure:
            return "Pressure"
        case .skinTemperature:
            return "Skin Temp"
        }
    }
}
