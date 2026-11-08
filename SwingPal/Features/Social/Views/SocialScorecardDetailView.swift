import SwiftUI

/// A shared card, read-only: the player's totals as the book records them.
struct SocialScorecardDetailView: View {
    let post: SocialPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    BookNote(post.roundSummary.updatedAt.formatted(date: .complete, time: .omitted))
                    Text(post.playerName)
                        .font(Book.Typeface.display)
                    Text(post.courseName)
                        .font(.title3)
                        .foregroundStyle(Book.pencil)
                }
                VStack(spacing: 0) {
                    BookHairline(color: Book.ink.opacity(0.85))
                    HStack(spacing: 0) {
                        figure("Strokes", "\(post.roundSummary.totalStrokes)", first: true)
                        figure("Putts", "\(post.roundSummary.totalPutts)")
                        figure("Penalties", "\(post.roundSummary.totalPenalties)")
                    }
                    BookHairline()
                    row("Status", post.roundSummary.status == .finished ? "Finished" : "Saved to resume")
                    row("Progress", "Hole \(post.roundSummary.holeNumber) of \(post.roundSummary.totalHoleCount)")
                    row("Golfers", "\(post.roundSummary.playerCount)")
                }
                if !post.highlight.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        BookSectionRule(title: "Notes")
                        Text(post.highlight).font(.headline)
                        Text(post.subtitle).font(.subheadline).foregroundStyle(Book.pencil)
                        ForEach(post.metadataPills, id: \.self) { pill in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("—").foregroundStyle(Book.pencil)
                                Text(pill).font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Book.paper.ignoresSafeArea())
        .foregroundStyle(Book.ink)
        .navigationTitle("Shared card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func figure(_ title: String, _ value: String, first: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 42, weight: .bold).width(.condensed)).monospacedDigit()
            BookNote(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.leading, first ? 0 : 12)
        .overlay(alignment: .leading) { if !first { Rectangle().fill(Book.rule).frame(width: 1) } }
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(Book.pencil)
                Spacer()
                Text(value)
            }
            .font(.subheadline)
            .padding(.vertical, 11)
            BookHairline()
        }
        .accessibilityElement(children: .combine)
    }
}
