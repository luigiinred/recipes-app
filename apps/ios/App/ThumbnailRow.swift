import SwiftUI

/// A list row as the App Store draws one: a rounded square picture, a title over a gray line, and an optional button at its trailing edge.
struct ThumbnailRow<Thumbnail: View, Subtitle: View, Accessory: View>: View {
    let title: String
    var thumbnailSize: CGFloat = 64
    @ViewBuilder let thumbnail: Thumbnail
    @ViewBuilder var subtitle: Subtitle
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: thumbnailSize * 0.22, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.body, weight: .semibold).lineLimit(2)
                subtitle.appFont(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

extension ThumbnailRow where Accessory == EmptyView {
    init(title: String, thumbnailSize: CGFloat = 64, @ViewBuilder thumbnail: () -> Thumbnail, @ViewBuilder subtitle: () -> Subtitle) {
        self.init(title: title, thumbnailSize: thumbnailSize, thumbnail: thumbnail, subtitle: subtitle, accessory: { EmptyView() })
    }
}

/// A titled run of rows, three to a column, that scrolls sideways with the next column peeking in, as App Store shelves do.
struct RowShelf<Item: Identifiable, Row: View>: View {
    /// Nil when the shelf sits under a header of its own.
    var title: String?
    var subtitle: String?
    var margin: CGFloat = 20
    var rowsPerColumn = 3
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    private var columns: [[Item]] {
        stride(from: 0, to: items.count, by: rowsPerColumn).map { Array(items[$0..<min($0 + rowsPerColumn, items.count)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).appFont(.title2, weight: .bold).accessibilityAddTraits(.isHeader)
                    if let subtitle { Text(subtitle).appFont(.subheadline).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, margin)
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: 0) {
                            ForEach(Array(column.enumerated()), id: \.element.id) { index, item in
                                row(item)
                                if index < column.count - 1 { Divider().padding(.leading, 78) }
                            }
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in columns.count > 1 ? width * 0.9 : width }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollDisabled(columns.count < 2)
        }
    }
}
