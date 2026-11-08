import SwiftUI

struct NearbyConnectSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var nearbyCoordinator: NearbyDiscoveryCoordinator
    @ObservedObject var nfcScanner: NFCFollowScanner

    @Environment(\.dismiss) private var dismiss

    private var canLook: Bool { appState.currentUser.flatMap { UUID(uuidString: $0.id) } != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Follow someone standing next to you")
                            .font(Book.Typeface.heading)
                        Text("Open this on both phones and tap Start looking. SwingPal finds the other phone over Bluetooth and Wi‑Fi.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if nearbyCoordinator.isRunning {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking for SwingPal close by…").font(.subheadline)
                        }
                    }

                    Button {
                        toggleNearby()
                    } label: {
                        HStack {
                            Text(nearbyCoordinator.isRunning ? "Stop looking" : "Start looking")
                            Spacer(minLength: 12)
                            Image(systemName: nearbyCoordinator.isRunning ? "stop.fill" : "dot.radiowaves.left.and.right")
                        }
                    }
                    .buttonStyle(BookStampButtonStyle(prominent: !nearbyCoordinator.isRunning))
                    .disabled(!canLook)

                    if !canLook {
                        Text("Sign in to find golfers nearby.")
                            .font(.footnote)
                            .foregroundStyle(Book.pencil)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        BookNote("NFC tags")
                        Text("iPhones can't swap details by tapping together, but you can scan a tag programmed with a SwingPal follow link (swingpal://follow/…).")
                            .font(.footnote)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                        if nfcScanner.isSupported {
                            Button {
                                nfcScanner.startScan()
                            } label: {
                                HStack {
                                    Text("Scan a tag")
                                    Spacer(minLength: 12)
                                    Image(systemName: "sensor.tag.radiowaves.forward")
                                }
                            }
                            .buttonStyle(BookStampButtonStyle(prominent: false))
                            .disabled(nfcScanner.isScanning)
                        } else {
                            Text("This device can't read NFC tags.")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .bookSheetChrome()
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        nearbyCoordinator.stop()
                        dismiss()
                    }
                }
            }
            .onChange(of: nearbyCoordinator.discoveredUserId) { _, uid in
                guard let uid else { return }
                appState.presentFollowInvite(userId: uid, displayName: nil)
            }
            .onChange(of: nfcScanner.parsedUserId) { _, uid in
                guard let uid else { return }
                appState.presentFollowInvite(userId: uid, displayName: nil)
                nfcScanner.clearParsed()
            }
            .onDisappear {
                nearbyCoordinator.stop()
            }
        }
        .presentationBackground(Book.paper)
    }

    private func toggleNearby() {
        guard let uidString = appState.currentUser?.id,
              let uid = UUID(uuidString: uidString)
        else {
            return
        }
        if nearbyCoordinator.isRunning {
            nearbyCoordinator.stop()
        } else {
            nearbyCoordinator.start(myUserId: uid)
        }
    }
}
