import SwiftUI

/// The app's photo card, App Store style: the photo fills a rounded card, and a blurred band at its foot
/// carries an optional kicker, the title, and a line of detail.
struct PhotoCard<Photo: View, Detail: View>: View {
    var kicker: String?
    let title: String
    var aspectRatio: CGFloat = 4 / 3
    @ViewBuilder let photo: Photo
    @ViewBuilder var detail: Detail

    static var cornerRadius: CGFloat { 24 }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { photo }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if let kicker, !kicker.isEmpty {
                        Text(kicker).appFont(.caption, weight: .bold).textCase(.uppercase).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                    }
                    Text(title).appFont(.title3, weight: .bold).lineLimit(2).foregroundStyle(.white)
                    detail.foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                    }
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)], startPoint: .top, endPoint: .bottom))
                }
                .environment(\.colorScheme, .dark)
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

extension PhotoCard where Detail == EmptyView {
    init(kicker: String? = nil, title: String, aspectRatio: CGFloat = 4 / 3, @ViewBuilder photo: () -> Photo) {
        self.init(kicker: kicker, title: title, aspectRatio: aspectRatio, photo: photo, detail: { EmptyView() })
    }
}
