import Foundation
import MultipeerConnectivity

/// Discovers other open SwingPal apps on local Bluetooth / Wi‑Fi using Bonjour.
/// **Phone‑to‑phone “tap”**: iOS does not expose generic NFC peer exchange between two arbitrary apps.
/// When both people open **Nearby** in SwingPal and hold phones close, this coordinator finds peers so we can offer a follow prompt—matching the intended UX without unsupported NFC APIs.
@MainActor
final class NearbyDiscoveryCoordinator: NSObject, ObservableObject {
    /// Bonjour / Multipeer service id (≤15 ASCII chars).
    static let serviceType = "swingpal-follow"
    private static let discoveryUserKey = "u"

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerId = MCPeerID(displayName: "SwingPal-\(UUID().uuidString.prefix(8))")

    private var myUserId: UUID?

    @Published private(set) var isRunning = false
    /// Most recently discovered other user (not `myUserId`). May update while browsing.
    @Published var discoveredUserId: UUID?

    func start(myUserId: UUID) {
        stop()
        self.myUserId = myUserId

        let info = [Self.discoveryUserKey: myUserId.uuidString]
        let adv = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: info, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let br = MCNearbyServiceBrowser(peer: peerId, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br

        isRunning = true
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        isRunning = false
    }

    private func handleDiscoveryInfo(_ info: [String: String]?) {
        guard let raw = info?[Self.discoveryUserKey],
              let uuid = UUID(uuidString: raw),
              uuid != myUserId
        else {
            return
        }
        discoveredUserId = uuid
    }
}

extension NearbyDiscoveryCoordinator: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Discovery-only: we don’t establish a Multipeer session; invitations are declined.
        invitationHandler(false, nil)
    }
}

extension NearbyDiscoveryCoordinator: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            self.handleDiscoveryInfo(info)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
