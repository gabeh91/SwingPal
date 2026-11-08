import SwiftUI

/// The clubhouse board: shared cards pinned up by day, newest first. People
/// and their numbers lead; nothing counts activity for its own sake.
struct SocialView: View {
    @ObservedObject var appState: AppState
    @StateObject private var nearbyCoordinator = NearbyDiscoveryCoordinator()
    @StateObject private var nfcScanner = NFCFollowScanner()

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPost: SocialPost?
    @State private var isPeopleSearchPresented = false
    @State private var isNearbyPresented = false

    private var posts: [SocialPost] { appState.socialFeedPosts }
    private var palette: SocialPalette { SocialPalette.forColorScheme(colorScheme) }

    var body: some View {
        let model = SocialViewModel(posts: posts)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    connectRows
                    if appState.socialFeedIsLoading && posts.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Checking the board…").font(.subheadline).foregroundStyle(Book.pencil)
                        }
                    } else if posts.isEmpty {
                        emptyBoard(model: model)
                    } else {
                        board
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { await appState.refreshSocialFeed() }
            .task(id: appState.currentUser?.id) { await appState.refreshSocialFeed() }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPost) { post in
                switch post.destinationKind {
                case .analysis:
                    HomeRoundAnalysisDetailView(summary: post.roundSummary)
                case .scorecard:
                    SocialScorecardDetailView(post: post)
                }
            }
            .sheet(isPresented: $isPeopleSearchPresented) {
                PeopleSearchSheet(appState: appState)
            }
            .sheet(isPresented: $isNearbyPresented) {
                NearbyConnectSheet(appState: appState, nearbyCoordinator: nearbyCoordinator, nfcScanner: nfcScanner)
            }
        }
        .tint(Book.stamp)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SwingPal")
                .font(.system(.headline, weight: .heavy).width(.expanded))
            Text("Clubhouse")
                .font(Book.Typeface.display)
                .accessibilityAddTraits(.isHeader)
            Text("Cards shared by you and the golfers you follow.")
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
        }
    }

    private var connectRows: some View {
        VStack(spacing: 0) {
            BookHairline()
            Button { isPeopleSearchPresented = true } label: {
                connectRow("Find golfers", "Search by name or username", "person.badge.plus")
            }
            .buttonStyle(BookRowButtonStyle())
            BookHairline()
            Button { isNearbyPresented = true } label: {
                connectRow("Connect nearby", "Follow someone standing next to you", "dot.radiowaves.left.and.right")
            }
            .buttonStyle(BookRowButtonStyle())
            BookHairline()
        }
    }

    private func connectRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.medium)).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Book.pencil)
        }
        .padding(.vertical, 13)
    }

    private var groupedPosts: [(day: Date, posts: [SocialPost])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: posts) { calendar.startOfDay(for: $0.roundSummary.updatedAt) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.roundSummary.updatedAt > $1.roundSummary.updatedAt })
        }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(groupedPosts, id: \.day) { group in
                VStack(alignment: .leading, spacing: 12) {
                    BookSectionRule(title: dayTitle(group.day))
                    ForEach(group.posts) { post in
                        SocialPostCard(post: post, palette: palette) { selectedPost = post }
                    }
                }
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func emptyBoard(model: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BookSectionRule(title: "The board")
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "pin")
                    .font(.title2)
                    .foregroundStyle(Book.flag)
                    .rotationEffect(.degrees(20))
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.emptyStateTitle).font(.headline)
                    Text(model.emptyStateSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
