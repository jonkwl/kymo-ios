import Foundation

enum FITExportError: Error {
    case encodingFailed
}

struct FITExporter {

    // MARK: - Local Message Types
    // Using distinct local types instead of redefining localType 0 prevents file bloat
    private enum LocalType: UInt8 {
        case fileId   = 0
        case event    = 1
        case record   = 2
        case hrv      = 3
        case lap      = 4
        case session  = 5
        case activity = 6
    }

    // MARK: - Public entry point

    static func fitData(for session: SavedSession) throws -> Data {
        var body = Data()

        let startTimestamp = fitTimestamp(from: session.startedAt)
        let endTimestamp   = fitTimestamp(from: session.endedAt)
        let hrSamples      = session.decodedHRSamples()
        let rrValues       = session.decodedRRIntervals()
        let laps           = session.decodedLaps()

        // ── file_id (global 0) ───────────────────────────────────────────────
        body.append(defMsg(localType: LocalType.fileId.rawValue, global: 0, fields: [
            (0, 1, BaseType.enum_.rawValue),    // type
            (1, 2, BaseType.uint16.rawValue),   // manufacturer
            (2, 2, BaseType.uint16.rawValue),   // product
            (4, 4, BaseType.uint32.rawValue),   // time_created
        ]))
        body.append(dataMsg(localType: LocalType.fileId.rawValue, values: [
            uint8(4),                           // type = activity
            uint16(255),                        // manufacturer = development
            uint16(0),                          // product
            uint32(startTimestamp),             // time_created
        ]))

        // ── event: timer start (global 21) ───────────────────────────────────
        body.append(defMsg(localType: LocalType.event.rawValue, global: 21, fields: [
            (253, 4, BaseType.uint32.rawValue), // timestamp
            (0,   1, BaseType.enum_.rawValue),  // event
            (1,   1, BaseType.enum_.rawValue),  // event_type
        ]))
        body.append(dataMsg(localType: LocalType.event.rawValue, values: [
            uint32(startTimestamp),
            uint8(0),  // event = timer
            uint8(0),  // event_type = start
        ]))

        // ── record × N (1 Hz HR) (global 20) ─────────────────────────────────
        if !hrSamples.isEmpty {
            body.append(defMsg(localType: LocalType.record.rawValue, global: 20, fields: [
                (253, 4, BaseType.uint32.rawValue), // timestamp
                (3,   1, BaseType.uint8.rawValue),  // heart_rate
            ]))
            for sample in hrSamples {
                let ts = startTimestamp + UInt32(max(0, sample.elapsed))
                let hr = sample.bpm.map { UInt8(clamping: $0) } ?? 0xFF
                body.append(dataMsg(localType: LocalType.record.rawValue, values: [uint32(ts), uint8(hr)]))
            }
        }

        // ── hrv messages (global 78) ─────────────────────────────────────────
        if !rrValues.isEmpty {
            let batchSize = 5
            let converted: [UInt16] = rrValues.map { rrMs in
                UInt16(clamping: Int(round(Double(rrMs) / 1000.0 * 1024.0)))
            }

            let fullBatchCount = converted.count / batchSize
            if fullBatchCount > 0 {
                body.append(defMsg(localType: LocalType.hrv.rawValue, global: 78, fields: [
                    (0, UInt8(batchSize * 2), BaseType.uint16.rawValue),
                ]))
                for i in 0 ..< fullBatchCount {
                    let slice = converted[(i * batchSize) ..< (i * batchSize + batchSize)]
                    body.append(dataMsg(localType: LocalType.hrv.rawValue, values: slice.map { uint16($0) }))
                }
            }

            let remainder = converted.count % batchSize
            if remainder > 0 {
                let padded = Array(converted.suffix(remainder))
                    + Array(repeating: UInt16(0xFFFF), count: batchSize - remainder)
                
                // Reusing the same definition since we padded it to match batchSize
                if fullBatchCount == 0 {
                    body.append(defMsg(localType: LocalType.hrv.rawValue, global: 78, fields: [
                        (0, UInt8(batchSize * 2), BaseType.uint16.rawValue),
                    ]))
                }
                body.append(dataMsg(localType: LocalType.hrv.rawValue, values: padded.map { uint16($0) }))
            }
        }

        // ── lap × M (global 19) ──────────────────────────────────────────────
        if !laps.isEmpty {
            body.append(defMsg(localType: LocalType.lap.rawValue, global: 19, fields: [
                (254, 2, BaseType.uint16.rawValue),  // message_index (REQUIRED for laps)
                (253, 4, BaseType.uint32.rawValue),  // timestamp (lap end)
                (2,   4, BaseType.uint32.rawValue),  // start_time
                (7,   4, BaseType.uint32.rawValue),  // total_elapsed_time (ms)
                (8,   4, BaseType.uint32.rawValue),  // total_timer_time (ms)
                (9,   4, BaseType.uint32.rawValue),  // total_distance (cm)
                (16,  1, BaseType.uint8.rawValue),   // avg_heart_rate
                (24,  1, BaseType.enum_.rawValue),   // lap_trigger
                (0,   1, BaseType.enum_.rawValue),   // event
                (1,   1, BaseType.enum_.rawValue),   // event_type
            ]))
            
            for (index, lap) in laps.enumerated() {
                let lapEnd   = startTimestamp + UInt32(max(0, lap.endTime))
                let lapStart = startTimestamp + UInt32(max(0, lap.startTime))
                let elapsed  = UInt32(max(0, lap.duration) * 1000)
                let dist: UInt32 = lap.distanceMeters.map { UInt32($0 * 100) } ?? 0xFFFFFFFF
                let avgHR    = lap.averageBpm.map { UInt8(clamping: $0) } ?? 0xFF
                
                body.append(dataMsg(localType: LocalType.lap.rawValue, values: [
                    uint16(UInt16(index)), // message_index
                    uint32(lapEnd),
                    uint32(lapStart),
                    uint32(elapsed),
                    uint32(elapsed),       // total_timer_time = total_elapsed_time
                    uint32(dist),
                    uint8(avgHR),
                    uint8(0),              // lap_trigger = manual
                    uint8(9),              // event = lap
                    uint8(1),              // event_type = stop
                ]))
            }
        }

        // ── session (global 18) ──────────────────────────────────────────────
        let totalDistCm: UInt32 = session.distanceMeters.map { UInt32($0 * 100) } ?? 0xFFFFFFFF
        let sessionMs    = UInt32(max(0, session.durationSeconds) * 1000)
        let avgHR        = session.averageBpm.map { UInt8(clamping: $0) } ?? 0xFF
        let maxHR        = session.maxBpm.map { UInt8(clamping: $0) } ?? 0xFF
        let sportCode    = fitSportCode(for: Sport(rawValue: session.sport))
        let numLaps      = UInt16(laps.count)

        body.append(defMsg(localType: LocalType.session.rawValue, global: 18, fields: [
            (254, 2, BaseType.uint16.rawValue),  // message_index
            (253, 4, BaseType.uint32.rawValue),  // timestamp
            (2,   4, BaseType.uint32.rawValue),  // start_time
            (5,   1, BaseType.enum_.rawValue),   // sport
            (6,   1, BaseType.enum_.rawValue),   // sub_sport
            (7,   4, BaseType.uint32.rawValue),  // total_elapsed_time (ms)
            (8,   4, BaseType.uint32.rawValue),  // total_timer_time (ms)
            (9,   4, BaseType.uint32.rawValue),  // total_distance (cm)
            (16,  1, BaseType.uint8.rawValue),   // avg_heart_rate
            (17,  1, BaseType.uint8.rawValue),   // max_heart_rate
            (25,  2, BaseType.uint16.rawValue),  // num_laps
            (26,  2, BaseType.uint16.rawValue),  // first_lap_index (REQUIRED if laps exist)
            (0,   1, BaseType.enum_.rawValue),   // event
            (1,   1, BaseType.enum_.rawValue),   // event_type
        ]))
        body.append(dataMsg(localType: LocalType.session.rawValue, values: [
            uint16(0),          // message_index
            uint32(endTimestamp),
            uint32(startTimestamp),
            uint8(sportCode),
            uint8(0),           // sub_sport = generic
            uint32(sessionMs),
            uint32(sessionMs),  // total_timer_time = total_elapsed_time
            uint32(totalDistCm),
            uint8(avgHR),
            uint8(maxHR),
            uint16(numLaps),
            uint16(0),          // first_lap_index = 0
            uint8(8),           // event = session
            uint8(1),           // event_type = stop
        ]))

        // ── activity (global 34) ─────────────────────────────────────────────
        body.append(defMsg(localType: LocalType.activity.rawValue, global: 34, fields: [
            (253, 4, BaseType.uint32.rawValue),  // timestamp
            (0,   4, BaseType.uint32.rawValue),  // total_timer_time (ms)
            (1,   2, BaseType.uint16.rawValue),  // num_sessions
            (2,   1, BaseType.enum_.rawValue),   // type
            (3,   1, BaseType.enum_.rawValue),   // event
            (4,   1, BaseType.enum_.rawValue),   // event_type
        ]))
        body.append(dataMsg(localType: LocalType.activity.rawValue, values: [
            uint32(endTimestamp),
            uint32(sessionMs),
            uint16(1),   // num_sessions
            uint8(0),    // type = manual
            uint8(26),   // event = activity
            uint8(1),    // event_type = stop
        ]))

        return buildFile(body: body)
    }

    // MARK: - File assembly

    private static func buildFile(body: Data) -> Data {
        let dataSize = UInt32(body.count)
        let protocolVersion: UInt8 = 0x20
        let profileVersion: UInt16 = 2132  // FIT profile 21.32

        var header = Data(capacity: 14)
        header.append(14)                              // header size
        header.append(protocolVersion)
        header.append(contentsOf: uint16(profileVersion))
        header.append(contentsOf: uint32(dataSize))
        header.append(contentsOf: [0x2E, 0x46, 0x49, 0x54]) // ".FIT"
        
        let headerCRC = crc16(header)
        header.append(contentsOf: uint16(headerCRC))

        var file = header
        file.append(body)
        
        let fileCRC = crc16(file)
        file.append(contentsOf: uint16(fileCRC))
        
        return file
    }

    // MARK: - Message builders

    private static func defMsg(
        localType: UInt8,
        global: UInt16,
        fields: [(fieldNum: UInt8, size: UInt8, baseType: UInt8)]
    ) -> Data {
        var d = Data()
        d.append(0x40 | (localType & 0x0F))     // definition header
        d.append(0)                             // reserved
        d.append(0)                             // architecture: little-endian
        d.append(contentsOf: uint16(global))
        d.append(UInt8(fields.count))
        for f in fields {
            d.append(f.fieldNum)
            d.append(f.size)
            d.append(f.baseType)
        }
        return d
    }

    private static func dataMsg(localType: UInt8, values: [Data]) -> Data {
        var d = Data()
        d.append(localType & 0x0F)
        for v in values { 
            d.append(contentsOf: v) 
        }
        return d
    }

    // MARK: - Base type helpers

    private enum BaseType: UInt8 {
        case enum_  = 0x00
        case uint8  = 0x02
        case uint16 = 0x84
        case uint32 = 0x86
    }

    private static func uint8(_ v: UInt8) -> Data { Data([v]) }

    private static func uint16(_ v: UInt16) -> Data {
        var x = v.littleEndian
        return withUnsafeBytes(of: &x) { Data($0) }
    }

    private static func uint32(_ v: UInt32) -> Data {
        var x = v.littleEndian
        return withUnsafeBytes(of: &x) { Data($0) }
    }

    // MARK: - FIT timestamp

    // FIT epoch: 1989-12-31T00:00:00Z
    private static let fitEpoch: TimeInterval = {
        var c = DateComponents()
        c.year = 1989; c.month = 12; c.day = 31
        c.hour = 0; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!.timeIntervalSince1970
    }()

    private static func fitTimestamp(from date: Date) -> UInt32 {
        let seconds = date.timeIntervalSince1970 - fitEpoch
        return UInt32(max(0, seconds))
    }

    // MARK: - Sport mapping

    private static func fitSportCode(for sport: Sport?) -> UInt8 {
        guard let sport else { return 0 }
        switch sport {
        case .running, .jogging, .trailRunning, .roadRunning, .crossCountryRunning,
             .ultraRunning, .treadmillRunning, .obstacleCourseRacing:
            return 1  // running
        case .cycling, .indoorCycling, .mountainBiking, .roadCycling, .gravelCycling,
             .electricBiking, .spinning:
            return 2  // cycling
        case .swimming, .poolSwimming, .openWaterSwimming:
            return 5  // swimming
        case .walking, .nordicWalking:
            return 11 // walking
        case .hiking:
            return 17 // hiking
        case .rowing, .indoorRowing:
            return 15 // rowing
        case .yoga:
            return 57 // yoga
        default:
            return 0  // generic
        }
    }

    // MARK: - CRC-16 (FIT variant, poly 0x1021)

    private static func crc16(_ data: Data) -> UInt16 {
        let table: [UInt16] = [
            0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
            0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
        ]
        var crc: UInt16 = 0
        for byte in data {
            var tmp = table[Int(crc & 0x0F)]
            crc = (crc >> 4) & 0x0FFF
            crc ^= tmp ^ table[Int(byte & 0x0F)]
            tmp = table[Int(crc & 0x0F)]
            crc = (crc >> 4) & 0x0FFF
            crc ^= tmp ^ table[Int((byte >> 4) & 0x0F)]
        }
        return crc
    }
}
