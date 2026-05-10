import Foundation

final class EcgFileWriter {

    let sessionId: UUID

    // Absolute URL of the ECG binary file. Valid for the lifetime of this object.
    let fileURL: URL

    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.probe.ecgwriter", qos: .utility)

    // MARK: Init

    init?(sessionId: UUID) {
        self.sessionId = sessionId

        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let sessionDir = documents
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        } catch {
            print("EcgFileWriter: could not create session directory: \(error)")
            return nil
        }

        let url = sessionDir.appendingPathComponent("ecg.f32")
        FileManager.default.createFile(atPath: url.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: url) else {
            print("EcgFileWriter: could not open file handle at \(url.path)")
            return nil
        }

        self.fileURL = url
        self.fileHandle = handle
    }

    // MARK: Writing

    // Converts samples from Double to Float32 and appends them to the file asynchronously.
    // Safe to call from any thread; work is serialized on the internal queue.
    func write(_ samples: [Double]) {
        guard !samples.isEmpty else { return }

        var bytes = Data(capacity: samples.count * 4)
        for sample in samples {
            var f = Float32(sample)
            withUnsafeBytes(of: &f) { bytes.append(contentsOf: $0) }
        }

        // Capture handle before dispatching so a concurrent close cannot nil it mid-write.
        guard let handle = fileHandle else { return }
        queue.async {
            handle.write(bytes)
        }
    }

    // MARK: Lifecycle

    // Flushes all pending writes and closes the file handle. The file is kept on disk.
    // Blocks the caller until in-flight writes have completed.
    func close() {
        queue.sync {
            try? self.fileHandle?.synchronize()
            try? self.fileHandle?.close()
            self.fileHandle = nil
        }
    }

    // Closes the file and removes the entire session directory from disk.
    // Use this on the discard path.
    func delete() {
        close()
        let sessionDir = fileURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: sessionDir)
    }

    deinit {
        // Best-effort close if the writer was dropped without an explicit close().
        try? fileHandle?.close()
    }
}