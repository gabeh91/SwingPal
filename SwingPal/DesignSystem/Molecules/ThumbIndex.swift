import SwiftUI

/// The book's thumb index: a strip of hole numbers at the page edge. Dragging
/// along it pages through holes with a tick at each stop; tapping jumps.
/// VoiceOver adjusts it like a stepper.
struct ThumbIndex: View {
    let numbers: [Int]
    @Binding var selection: Int
    var marked: Int? = nil
    @GestureState private var isScrubbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let count = max(numbers.count, 1)
            let rowHeight = proxy.size.height / CGFloat(count)
            VStack(spacing: 0) {
                ForEach(Array(numbers.enumerated()), id: \.offset) { index, number in
                    let selected = index == selection
                    ZStack(alignment: .trailing) {
                        if selected {
                            UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 7, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
                                .fill(Book.ink)
                                .frame(width: isScrubbing && !reduceMotion ? 46 : 38)
                        }
                        HStack(spacing: 2) {
                            if marked == number {
                                Circle().fill(Book.flag).frame(width: 4, height: 4)
                            }
                            Text("\(number)")
                                .font(.system(size: min(13, rowHeight * 0.62), weight: selected ? .bold : .medium).width(.condensed))
                                .monospacedDigit()
                                .foregroundStyle(selected ? Book.paper : Book.pencil)
                        }
                        .padding(.trailing, 8)
                    }
                    .frame(width: 46, height: rowHeight, alignment: .trailing)
                }
            }
            .frame(width: 46)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isScrubbing) { _, s, _ in s = true }
                    .onChanged { value in
                        let index = min(max(Int(value.location.y / rowHeight), 0), count - 1)
                        if index != selection {
                            if reduceMotion { selection = index }
                            else { withAnimation(.snappy(duration: 0.16)) { selection = index } }
                        }
                    }
            )
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isScrubbing)
        }
        .frame(width: 46)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hole index")
        .accessibilityValue(numbers.indices.contains(selection) ? "Hole \(numbers[selection]) of \(numbers.count)" : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = min(selection + 1, numbers.count - 1)
            case .decrement: selection = max(selection - 1, 0)
            @unknown default: break
            }
        }
    }
}
