import SwiftUI

/// Page one: the hole, the green readings beside it, and the club in hand
/// over the stamp that logs a shot.
struct WatchHolePage: View {
    let model: WatchRoundPresentation
    @ObservedObject var store: WatchRoundCompanionStore
    @Binding var path: [WatchRoundRoute]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 4) {
                greenReadings
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let sketch = model.snapshot?.sketch {
                    WatchHoleSketchView(sketch: sketch)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity)
            if let status = model.statusLine {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(model.isStale ? WatchBook.warning : WatchBook.pencil)
                    .lineLimit(2)
                    .padding(.bottom, 2)
            }
            WatchBookHairline()
            dock
        }
        .padding(.horizontal, 4)
    }

    /// The folio: hole number, par and the round so far.
    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(model.folioText)
                .font(WatchBook.Typeface.folio)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.parText).font(WatchBook.Typeface.heading)
                Text("\(model.roundToParText) · \(model.strokeText)")
                    .font(.caption2)
                    .foregroundStyle(WatchBook.pencil)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hole \(model.snapshot?.holeNumber ?? 0), \(model.parText). Round \(model.roundToParText). \(model.strokeText)")
    }

    /// Centre, front and back, written beside the drawing as the book does.
    private var greenReadings: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(model.centreText)
                    .font(WatchBook.Typeface.figure)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(model.isStale ? WatchBook.pencil : WatchBook.ink)
                if model.hasYardage {
                    Text(model.unitSuffix)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WatchBook.pencil)
                }
            }
            WatchBookNote(model.yardageNote)
            if model.hasYardage {
                HStack(spacing: 8) {
                    Text("F \(model.frontText)")
                    Text("B \(model.backText)")
                }
                .font(WatchBook.Typeface.smallFigure)
                .padding(.top, 2)
                if let playsLike = model.playsLikeText {
                    Text(playsLike)
                        .font(.system(.footnote, weight: .bold).width(.condensed))
                        .foregroundStyle(WatchBook.flag)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.yardageAccessibilityLabel)
    }

    /// The equipment line: the club code and its carry, then the stamp.
    private var dock: some View {
        HStack(spacing: 6) {
            Button { path.append(.club) } label: {
                HStack(alignment: .center, spacing: 5) {
                    Text(model.clubCode)
                        .font(WatchBook.Typeface.clubCode)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    VStack(alignment: .leading, spacing: 0) {
                        if let carry = model.carryText {
                            Text(carry).font(.caption2.weight(.semibold)).monospacedDigit()
                        }
                        if let source = model.carrySourceText {
                            Text(source).font(.caption2).foregroundStyle(WatchBook.pencil)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isInspectingOnPhone)
            .accessibilityLabel("Choose club. \(model.snapshot?.selectedClubName ?? ""), \(model.carryText ?? ""), \(model.carrySourceText ?? "")")

            if model.isInspectingOnPhone {
                Button {
                    store.send(.returnToLiveHole)
                } label: {
                    Label("Hole \(model.snapshot?.holeNumber ?? 0)", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.bold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(WatchStampButtonStyle())
                .frame(width: 82)
                .accessibilityLabel("Back to the live hole")
            } else {
                Button {
                    path.append(model.snapshot?.shotContext == .putt ? .putt : .shot)
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "figure.golf").font(.system(size: 16, weight: .semibold))
                        Text("Log").font(.caption2.weight(.bold))
                    }
                }
                .buttonStyle(WatchStampButtonStyle())
                .frame(width: 62)
                .disabled(!model.canRecordShots)
                .accessibilityLabel(model.logShotTitle)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}
