import SwiftUI

struct WatchLiePickerView: View {
    let selection: RoundCompanionSurface
    let onPick: (RoundCompanionSurface) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach([RoundCompanionSurface.tee, .fairway, .rough, .bunker], id: \.self) { surface in
                    Button { onPick(surface) } label: {
                        Label(WatchBookLabels.surface(surface), systemImage: WatchBookLabels.surfaceSymbol(surface))
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 10)
                            .watchChoice(isSelected: surface == selection)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(surface == selection ? .isSelected : [])
                }
            }
        }
        .navigationTitle("Lie")
        .watchPaper()
    }
}
