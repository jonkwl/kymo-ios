import Foundation
import SwiftData

@Model
final class SavedSession {
    var id: UUID
    var sport: String
    var title: String
    var colorName: String
    var note: String = ""
    var rpe: Int?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var averageBpm: Int?
    var maxBpm: Int?
    var lapCount: Int = 0
    var distanceMeters: Double?

    // Whether RR intervals were received during this session.
    var hasRRIntervals: Bool = false
    // Total number of RR intervals received during the session.
    var rrIntervalCount: Int = 0

    // Whether a valid ECG file exists for this session.
    var hasEcg: Bool = false
    // Total number of ECG samples written to disk during the session.
    var ecgSampleCount: Int = 0

    // Binary-packed HR timeline: each sample is 6 bytes — Float32 elapsed seconds + Int16 bpm (-1 = no signal).
    var hrSamplesData: Data = Data()

    // JSON-encoded array of `LapRecord`.
    var lapsData: Data = Data()

    init(
        id: UUID,
        sport: String,
        title: String,
        colorName: String,
        note: String,
        rpe: Int?,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        averageBpm: Int?,
        maxBpm: Int?,
        lapCount: Int,
        distanceMeters: Double?,
        hasRRIntervals: Bool,
        rrIntervalCount: Int,
        hasEcg: Bool,
        ecgSampleCount: Int,
        hrSamplesData: Data,
        lapsData: Data
    ) {
        self.id = id
        self.sport = sport
        self.title = title
        self.colorName = colorName
        self.note = note
        self.rpe = rpe
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.averageBpm = averageBpm
        self.maxBpm = maxBpm
        self.lapCount = lapCount
        self.distanceMeters = distanceMeters
        self.hasRRIntervals = hasRRIntervals
        self.rrIntervalCount = rrIntervalCount
        self.hasEcg = hasEcg
        self.ecgSampleCount = ecgSampleCount
        self.hrSamplesData = hrSamplesData
        self.lapsData = lapsData
    }
}

// MARK: - Serialization helpers

extension SavedSession {

    // MARK: Lap record

    struct LapRecord: Codable {
        let number: Int
        let startTime: Double
        let endTime: Double
        let duration: Double
        let averageBpm: Int?
        let averagePaceSecondsPerKilometer: Double?
        let distanceMeters: Double?
    }

    // MARK: Encoding

    // Encodes HR samples as a compact binary blob.
    // Layout per sample: [Float32 elapsedSeconds (4 bytes)][Int16 bpm (2 bytes)], little-endian.
    // bpm == -1 signals no reading (nil in the source model).
    static func encodeHRSamples(
        _ samples: ContiguousArray<SessionManager.HeartRateSample>
    ) -> Data {
        var data = Data(capacity: samples.count * 6)
        for sample in samples {
            var elapsed = Float32(sample.elapsedTime)
            var bpm = Int16(sample.bpm ?? -1)
            withUnsafeBytes(of: &elapsed) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &bpm) { data.append(contentsOf: $0) }
        }
        return data
    }

    // Encodes lap metrics as JSON.
    static func encodeLaps(_ laps: [SessionManager.LapMetrics]) -> Data {
        let records = laps.map { lap in
            LapRecord(
                number: lap.number,
                startTime: lap.startTime,
                endTime: lap.endTime,
                duration: lap.duration,
                averageBpm: lap.averageBpm,
                averagePaceSecondsPerKilometer: lap.averagePaceSecondsPerKilometer,
                distanceMeters: lap.distanceMeters
            )
        }
        return (try? JSONEncoder().encode(records)) ?? Data()
    }

    // MARK: Decoding

    func decodedHRSamples() -> [(elapsed: TimeInterval, bpm: Int?)] {
        let stride = 6
        guard hrSamplesData.count % stride == 0 else { return [] }
        var results: [(elapsed: TimeInterval, bpm: Int?)] = []
        results.reserveCapacity(hrSamplesData.count / stride)

        hrSamplesData.withUnsafeBytes { ptr in
            var offset = 0
            while offset + stride <= hrSamplesData.count {
                // Records are 6 bytes each (Float32 + Int16), so offsets ≥ 1 are not naturally
                // aligned for Float32. Use loadUnaligned to avoid SIGBUS / UB on all builds.
                let elapsed = ptr.loadUnaligned(fromByteOffset: offset, as: Float32.self)
                let bpmRaw = ptr.loadUnaligned(fromByteOffset: offset + 4, as: Int16.self)
                results.append((
                    elapsed: TimeInterval(elapsed),
                    bpm: bpmRaw == -1 ? nil : Int(bpmRaw)
                ))
                offset += stride
            }
        }
        return results
    }

    func decodedLaps() -> [LapRecord] {
        (try? JSONDecoder().decode([LapRecord].self, from: lapsData)) ?? []
    }

    // MARK: Display

    /// Matches the save sheet: a custom title differs from the sport name.
    var hasCustomTitle: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) != sport
    }

    /// List / hero icon: tag for custom titles, otherwise the sport icon.
    var sessionDisplayIconSystemName: String {
        hasCustomTitle ? "tag.fill" : (Sport(rawValue: sport)?.icon ?? "heart.fill")
    }

    // MARK: ECG file URL

    // URL of the ECG binary file for this session, if it exists.
    var ecgFileURL: URL? {
        guard hasEcg,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = documents
            .appendingPathComponent("sessions")
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent("ecg.f32")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
