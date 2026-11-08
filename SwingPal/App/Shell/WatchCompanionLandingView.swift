import SwiftUI

/// The Watch companion: connection state first, then what it can do now.
struct WatchCompanionLandingView: View {
    let model: WatchCompanionLandingModel
    let onOpenRound: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "applewatch.side.right")
                            .font(.system(size: 44, weight: .light))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Watch").font(Book.Typeface.display)
                            HStack(spacing: 6) {
                                Circle().fill(model.canOpenLiveRound ? Book.stamp : Book.pencil).frame(width: 7, height: 7)
                                Text(model.connectionBadge).font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    VStack(alignment: .leading, spacing: 0) {
                        BookHairline()
                        row("Status", model.setupTitle)
                        row("Changes", model.mutationSourceText)
                    }
                    Text(model.setupDetail)
                        .font(.body)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("On your wrist: hole, distance, club, quick shot and hole finish. Changes are confirmed on iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onOpenRound) {
                        HStack {
                            Text(model.primaryActionTitle)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(BookStampButtonStyle())
                }
                .padding(22)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .tint(Book.stamp)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(Book.pencil)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .padding(.vertical, 12)
            BookHairline()
        }
        .accessibilityElement(children: .combine)
    }
}
