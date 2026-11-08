import Foundation

struct HomeInsight: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }

    static let mock = HomeInsight(
        title: "Approach play cost you 4 shots",
        detail: "Your last two rounds lost the most strokes between 110m and 150m."
    )
}
