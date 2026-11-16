import SwiftUI

enum ClubStyle {
    static let background = Color(red: 0.025, green: 0.065, blue: 0.055)
    static let panel = Color(red: 0.055, green: 0.12, blue: 0.10)
    static let gold = Color(red: 0.87, green: 0.74, blue: 0.46)
    static let ivory = Color(red: 0.97, green: 0.95, blue: 0.88)
    static let muted = Color(red: 0.58, green: 0.67, blue: 0.61)
    static let green = Color(red: 0.13, green: 0.42, blue: 0.30)
}

struct ClubButton: View {
    var title: String
    var icon: String? = nil
    var gold = true
    var action: () -> Void
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .foregroundStyle(gold ? ClubStyle.background : ClubStyle.ivory)
            .background(gold ? ClubStyle.gold : ClubStyle.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ClubStyle.gold.opacity(gold ? 0 : 0.22)))
            .opacity(enabled ? 1 : 0.35)
        }.buttonStyle(.plain)
    }
}

struct CircleTool: View {
    var icon: String
    var label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .foregroundStyle(ClubStyle.ivory).frame(width: 46, height: 46)
                .background(.black.opacity(0.35), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12)))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct SchoolChipButton: View {
    static let diameter: CGFloat = 98.8
    static let startSpacing: CGFloat = 24
    var title: String
    var animated: Bool
    var action: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shimmering: Bool { animated && scenePhase == .active && !reduceMotion }
    private var designScale: CGFloat { Self.diameter / 76 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("chip_texture").resizable().scaledToFit()
                if shimmering {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4)
                        let progress = min(phase / 1.1, 1)
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.48), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 24 * designScale, height: 120 * designScale)
                            .rotationEffect(.degrees(25))
                            .offset(x: (-75 + 150 * progress) * designScale)
                            .frame(width: Self.diameter, height: Self.diameter)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                }
                Text(title)
                    .font(.system(size: 13 * designScale, weight: .bold, design: .rounded))
                    .foregroundStyle(ClubStyle.ivory)
                    .shadow(color: .black, radius: 3 * designScale)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, 10 * designScale)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .shadow(color: ClubStyle.gold.opacity(reduceMotion ? 0.3 : 0.18), radius: 9 * designScale)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("schoolEntry")
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(2.5).foregroundStyle(ClubStyle.gold).lineLimit(1).minimumScaleFactor(0.6)
    }
}

// Both faces rotate together; visibility changes at the edge, never mid-face.
private struct CardFaces: AnimatableModifier {
    var angle: Double
    var asset: String
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                Image(asset).resizable().scaledToFit().opacity(angle < 90 ? 1 : 0)
                Image("card_back").resizable().scaledToFit()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(angle >= 90 ? 1 : 0)
            }
        }
        .overlay(LinearGradient(colors: [.clear, .white.opacity(0.22 * sin(angle * .pi / 180)), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

struct CardView: View {
    var card: PlayingCard?
    var hidden = false
    var width: CGFloat = 64
    var accessibilityText: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Color.clear.frame(width: width, height: width * 1.45)
            .modifier(CardFaces(angle: hidden || card == nil ? 180 : 0, asset: card?.asset ?? "card_back"))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.46), value: hidden)
            .shadow(color: .black.opacity(0.34), radius: 6, x: 1, y: 5)
            .accessibilityLabel(accessibilityText)
    }
}

private struct DealtCard: View {
    var card: PlayingCard
    var hidden: Bool
    var width: CGFloat
    var delay: Double
    var animate: Bool
    var source: CGPoint?
    var label: String
    @State private var landed = false
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        // visualEffect may run outside the main actor; capture values, not @State.
        let moving = animate && !landed && !reduceMotion
        let opacity = animate && !landed ? 0.0 : 1.0
        CardView(card: card, hidden: hidden || (animate && !revealed), width: width, accessibilityText: label)
            .shadow(color: .black.opacity(landed ? 0 : 0.25), radius: landed ? 0 : 14, y: landed ? 0 : 12)
            .visualEffect { content, geometry in
                let frame = geometry.frame(in: .global)
                return content
                    .rotationEffect(.degrees(moving ? -18 : 0))
                    .scaleEffect(moving ? 0.55 : 1)
                    .offset(x: moving ? (source?.x ?? frame.midX + 120) - frame.midX : 0,
                            y: moving ? (source?.y ?? frame.midY - 100) - frame.midY : 0)
                    .opacity(opacity)
            }
            .task(id: animate) {
                guard animate else { landed = true; revealed = true; return }
                do {
                    try await Task.sleep(for: .seconds(delay))
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.44, dampingFraction: 0.86)) { landed = true }
                    try await Task.sleep(for: .seconds(reduceMotion ? 0.12 : 0.26))
                    revealed = true
                } catch { return }
            }
    }
}

struct HandView: View {
    var hand: CardHand
    var hideHole = false
    var width: CGFloat = 64
    var spanish = false
    var animateDeals = false
    var dealer = false
    var source: CGPoint? = nil
    var availableWidth: CGFloat? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var spacing: CGFloat {
        let original = hand.cards.count > 4 ? -width * 0.55 : -width * 0.24
        guard let availableWidth, hand.cards.count > 1 else { return original }
        // Overlap more on long hands rather than shrinking their ranks and suits.
        let fitted = (max(width, availableWidth - 20) - width) / CGFloat(hand.cards.count - 1) - width
        return min(original, fitted)
    }
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(hand.cards.enumerated()), id: \.element.id) { index, card in
                let hidden = hideHole && index == 1
                // Initial cards alternate player/dealer. Dealer draws follow the hole-card flip.
                let delay = index < 2 ? Double(index) * 0.24 + (dealer ? 0.12 : 0) : (dealer ? 0.46 + Double(index - 2) * 0.18 : 0)
                DealtCard(card: card, hidden: hidden, width: width, delay: delay,
                          animate: animateDeals, source: source,
                          label: hidden ? (spanish ? "Carta oculta" : "Hidden card") : "\(card.label) \(card.symbol)")
                    .rotationEffect(.degrees(reduceMotion ? 0 : rotation(index)))
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .identity, removal: .offset(x: -100, y: -24).combined(with: .scale(scale: 0.8)).combined(with: .opacity)))
            }
        }.animation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.86), value: hand.cards.count)
    }
    private func rotation(_ index: Int) -> Double {
        let angle = Double(index) * 3 - Double(hand.cards.count - 1) * 1.5
        return availableWidth == nil ? angle : max(-6, min(6, angle))
    }
}

struct ProfileAvatar: View {
    var data: Data?
    var bot: Int? = nil
    var size: CGFloat = 46
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let bot {
                Image("avatar_\(bot)").resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(ClubStyle.green.gradient)
                    Image(systemName: "person.fill").font(.system(size: size * 0.4)).foregroundStyle(ClubStyle.gold)
                }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().strokeBorder(ClubStyle.gold.opacity(0.35), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

extension View {
    func clubPanel() -> some View {
        self.padding(18).background(ClubStyle.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.06)))
    }
}
