import CoreNFC
import Foundation

/// Reads NDEF tags (URI or text) that contain a UUID or a `swingpal` / `https` follow link.
@MainActor
final class NFCFollowScanner: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published private(set) var isScanning = false
    @Published private(set) var parsedUserId: UUID?

    private var session: NFCNDEFReaderSession?

    var isSupported: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func clearParsed() {
        parsedUserId = nil
    }

    func startScan() {
        guard isSupported else {
            return
        }
        let newSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        newSession.alertMessage = "Hold the top of your iPhone near the tag."
        session = newSession
        isScanning = true
        newSession.begin()
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            self.session = nil
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        var found: UUID?
        for message in messages {
            for record in message.records {
                if let id = parseRecord(record) {
                    found = id
                    break
                }
            }
            if found != nil {
                break
            }
        }
        Task { @MainActor in
            self.parsedUserId = found
            self.isScanning = false
            self.session = nil
        }
    }

    private nonisolated func parseRecord(_ record: NFCNDEFPayload) -> UUID? {
        let data = record.payload
        if let s = String(data: data, encoding: .utf8),
           let id = FollowDeepLink.userId(fromPlainText: s) {
            return id
        }
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else {
            return nil
        }
        let remainder = Data(bytes.dropFirst())
        if let s = String(data: remainder, encoding: .utf8),
           let id = FollowDeepLink.userId(fromPlainText: s) {
            return id
        }
        return nil
    }
}
