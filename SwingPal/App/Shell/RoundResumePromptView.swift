import SwiftUI

/// A round is already open: the page you left, and two clear ways forward.
struct RoundResumePromptView: View {
    let activeRoundTitle: String?
    let onResume: () -> Void
    let onDiscardAndStartNew: () -> Void
    let onDismiss: () -> Void
    @State private var isConfirmingDiscard = false

    private var roundLabel: String { activeRoundTitle ?? "Your round" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle().fill(Book.flag).frame(width: 7, height: 7)
                            BookNote("Round in progress", color: Book.ink)
                        }
                        Text(roundLabel)
                            .font(Book.Typeface.display)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Your card is saved where you left it. Pick it back up, or clear it and start a new round.")
                            .font(.body)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 12) {
                        Button(action: onResume) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Resume round").font(.headline)
                                    Text("Back to the hole you were on").font(.subheadline).opacity(0.78)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                            }
                        }
                        .buttonStyle(BookStampButtonStyle())
                        Button { isConfirmingDiscard = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Discard and start new").font(.headline)
                                    Text("Clears the unfinished card").font(.subheadline).foregroundStyle(Book.pencil)
                                }
                                Spacer()
                                Image(systemName: "trash")
                            }
                        }
                        .buttonStyle(BookStampButtonStyle(prominent: false))
                        Button("Not now", action: onDismiss)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Book.pencil)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(22)
                .padding(.top, 20)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Discard \(roundLabel)?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard round", role: .destructive, action: onDiscardAndStartNew)
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The unfinished card and its shots are removed.")
            }
        }
        .tint(Book.stamp)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Book.paper)
    }
}
