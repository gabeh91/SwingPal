import SwiftUI

/// The hole index: every hole of the course as a page to look ahead or back at.
/// Every hole of the round on one page: the running totals, then each hole
/// with its par, what's on the card and how it was played.
struct FreshLiveRoundHoleInspectorSheet: View {
    @ObservedObject var state: LiveRoundState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if state.roundConfirmedHoleCount > 0 {
                        roundTotals
                    }
                    BookGroup("Holes") {
                        ForEach(Array(state.holeInspectionEntries.enumerated()), id: \.element.id) { index, entry in
                            Button { state.inspectHole(at: index) } label: { row(for: entry) }
                                .buttonStyle(BookRowButtonStyle())
                                .accessibilityHint("Shows this hole on the map")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Hole index")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }

    private var roundTotals: some View {
        let firs = state.roundFairwaysInRegulation
        let girs = state.roundGreensInRegulation
        return HStack(spacing: 0) {
            figure(state.roundScoreToParDisplay, label: "To par")
            divider
            figure(firs.applicable > 0 ? "\(firs.hit)/\(firs.applicable)" : "–", label: "Fairways")
            divider
            figure(girs.applicable > 0 ? "\(girs.hit)/\(girs.applicable)" : "–", label: "Greens")
            divider
            figure("\(state.roundTotalPutts)", label: "Putts")
        }
        .padding(.vertical, 12)
        .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
    }

    private func figure(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Book.Typeface.figure)
            Text(label.uppercased()).font(Book.Typeface.noteSmall).foregroundStyle(Book.pencil)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Book.rule).frame(width: 1, height: 34).accessibilityHidden(true)
    }

    private func row(for entry: LiveRoundState.HoleInspectionEntry) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", entry.number))
                .font(.system(size: 26, weight: .bold).width(.condensed))
                .monospacedDigit()
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Par \(entry.par)").font(.body.weight(.medium))
                    if entry.isActive {
                        Text("PLAYING").font(Book.Typeface.noteSmall).foregroundStyle(Book.stamp)
                    } else if entry.isDisplayed {
                        Text("ON THE MAP").font(Book.Typeface.noteSmall).foregroundStyle(Book.stamp)
                    }
                }
                Text(detail(for: entry)).font(.caption).foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 8)
            ScoreMark(score: entry.score, par: entry.par, size: 32)
                .opacity(entry.isConfirmed || entry.score == nil ? 1 : 0.55)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func detail(for entry: LiveRoundState.HoleInspectionEntry) -> String {
        guard entry.score != nil else {
            return entry.isActive ? "Your hole now" : "Not played yet"
        }
        var parts: [String] = []
        if let fairway = entry.fairwayHit { parts.append(fairway ? "Fairway" : "Missed fairway") }
        if let green = entry.greenInRegulation { parts.append(green ? "Green in reg." : "Missed green") }
        if let putts = entry.putts { parts.append("\(putts) putt\(putts == 1 ? "" : "s")") }
        if entry.wasEditedAfterConfirmation {
            parts.append("Corrected")
        } else if !entry.isConfirmed {
            parts.append("Not on the card yet")
        }
        return parts.isEmpty ? "On the card" : parts.joined(separator: " · ")
    }
}
