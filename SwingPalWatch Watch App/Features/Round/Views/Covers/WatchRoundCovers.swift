import SwiftUI

struct WatchNoRoundView: View {
    let link: WatchCompanionLink

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("––").font(WatchBook.Typeface.folio).foregroundStyle(WatchBook.pencil)
            Text("No round in progress").font(WatchBook.Typeface.heading)
            Text("Start a round on your iPhone. The hole, the green and your club appear here.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            if link == .unavailable {
                WatchBookNote("iPhone not connected", color: WatchBook.warning)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

struct WatchIncompatibleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath").font(.title3)
            Text("Update SwingPal").font(WatchBook.Typeface.heading)
            Text("The Watch and iPhone apps are different versions. Update both from the App Store.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

struct WatchRoundCompleteView: View {
    let model: WatchRoundPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WatchBookNote("Card complete")
            Text(model.roundToParText).font(WatchBook.Typeface.figure)
            Text(model.courseText).font(WatchBook.Typeface.heading).lineLimit(2)
            Text("Review and save the round on your iPhone.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}
