import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Color {
    /// The warm page color behind the mascots: cream by day, a dark cocoa by night.
    static var paper: Color {
        #if os(iOS)
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1) })
        #else
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.11, green: 0.09, blue: 0.08, alpha: 1) : NSColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1) })
        #endif
    }
}

private struct PaperBackground: ViewModifier {
    @Environment(\.appearance) private var appearance

    func body(content: Content) -> some View {
        content.background((appearance.canvas ?? Color.paper).ignoresSafeArea())
    }
}

extension View {
    func paperBackground() -> some View { modifier(PaperBackground()) }
}

/// A full-width rounded button in the accent color, or a quiet outline.
struct PaperButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.accent))
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// A mascot with a message, for screens with nothing on them yet.
struct MascotEmptyState<Actions: View>: View {
    let mascot: Mascot
    let title: String
    var message: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 10) {
            MascotView(mascot: mascot, height: 130)
            Text(title).font(.system(.title3, weight: .bold)).multilineTextAlignment(.center)
            if let message {
                Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            actions.padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension MascotEmptyState where Actions == EmptyView {
    init(mascot: Mascot, title: String, message: String? = nil) {
        self.init(mascot: mascot, title: title, message: message) { EmptyView() }
    }
}

/// The tomato in the middle with its friends on either side.
struct MascotCluster: View {
    var height: CGFloat = 170

    var body: some View {
        HStack(alignment: .bottom, spacing: -height * 0.12) {
            MascotView(mascot: .potato, height: height * 0.62)
            MascotView(mascot: .tomatoWave, height: height)
                .zIndex(1)
            VStack(spacing: -height * 0.06) {
                MascotView(mascot: .lemon, height: height * 0.5)
                MascotView(mascot: .chili, height: height * 0.5)
            }
        }
    }
}

/// The tomato tossing veggies with what it is doing underneath: import steps, a title and a way out.
struct ImportLoadingView: View {
    let title: String
    var subtitle: String?
    @ObservedObject var model: ImportProgressModel
    var cancel: (() -> Void)?
    var mascotHeight: CGFloat = 170
    /// Holds one wok frame for previews and snapshots.
    var mascotFrame: Int?

    var body: some View {
        VStack(spacing: 18) {
            TomatoWokLoader(height: mascotHeight, frame: mascotFrame)
            VStack(spacing: 6) {
                Text(title).font(.system(.title2, weight: .bold)).multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2)
                }
            }
            ImportProgressView(model: model)
                .padding(18)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let cancel {
                Button("Cancel", action: cancel).buttonStyle(PaperButtonStyle(prominent: false))
            }
        }
        .frame(maxWidth: 380)
        .padding(24)
    }
}
