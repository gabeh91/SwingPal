import SwiftUI

/// Book-edge tabs: labels on a rule, the selected one underlined in ink.
struct BookTabs: View {
    let titles: [String]
    @Binding var selection: String
    @Namespace private var underline

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(titles, id: \.self) { title in
                    let selected = title == selection
                    Button { selection = title } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.subheadline.weight(selected ? .bold : .medium))
                                .foregroundStyle(selected ? Book.ink : Book.pencil)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 2)
                                if selected {
                                    Rectangle().fill(Book.ink).frame(height: 2)
                                        .matchedGeometryEffect(id: "underline", in: underline)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { BookHairline().offset(y: -8) }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
