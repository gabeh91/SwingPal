import SwiftUI

/// The hole's shots, newest first, as written in the margin of the page.
struct FreshLiveRoundShotHistorySheet: View {
    @ObservedObject var state: LiveRoundState

    private var shots: [ShotEvent] { state.displayedHoleSession.shots.reversed() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%02d", state.displayedHoleNumber))
                            .font(.system(size: 34, weight: .bold).width(.condensed))
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Par \(state.displayedHoleSession.par)").font(Book.Typeface.subheading)
                            Text(shots.isEmpty ? "No shots logged" : "\(shots.count) shot\(shots.count == 1 ? "" : "s") logged · newest first")
                                .font(.caption)
                                .foregroundStyle(Book.pencil)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    if shots.isEmpty {
                        Text("Log a shot on this hole and it's written here, with the club, where it went and what's left.")
                            .font(.subheadline)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        BookGroup(ruleInset: 56) {
                            ForEach(shots) { shot in row(for: shot) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Shot history")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }

    private func row(for shot: ShotEvent) -> some View {
        let isPenalty = state.shotHistoryEntryKind(for: shot) == .penalty
        return HStack(alignment: .top, spacing: 14) {
            Text("\(shot.strokeNumber)")
                .font(.system(size: 24, weight: .bold).width(.condensed))
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPenalty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Book.warning)
                    }
                    Text(isPenalty ? "Penalty" : shot.clubName).font(.body.weight(.semibold))
                }
                Text(state.shotHistorySubtitle(for: shot))
                    .font(.subheadline)
                    .foregroundStyle(Book.pencil)
                if let detail = state.shotHistoryDetail(for: shot) {
                    Text(detail).font(.caption).foregroundStyle(Book.pencil)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
