import SwiftUI

struct BubbleView: View {
    @ObservedObject var visualState: BubbleVisualState
    @State private var pop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 4.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let breath = visualState.isPaused ? 1 : 1 + sin(time * visualState.mood.breathRate) * visualState.mood.breathAmount
            let bob = visualState.isPaused ? 0 : sin(time * visualState.mood.bobRate) * visualState.mood.bobAmount
            let blinkHeight = visualState.isPaused ? 14 : visualState.mood.eyeHeight(at: time)
            let pausedTint = visualState.isPaused ? 0.72 : visualState.mood.saturation
            let bodyWidth = visualState.character.bodySize.width
            let bodyHeight = visualState.character.bodySize.height

            ZStack {
                CharacterBody(character: visualState.character, colors: visualState.theme.colors)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .scaleEffect(x: breath * (pop ? 1.08 : 1.0), y: (2 - breath) * (pop ? 0.94 : 1.0))

                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: visualState.character.highlightSize.width, height: visualState.character.highlightSize.height)
                    .offset(visualState.character.highlightOffset)

                visualState.character.accent
                    .foregroundStyle(visualState.theme.colors.last ?? .blue)

                HStack(spacing: 28) {
                    Eye(height: blinkHeight)
                    Eye(height: blinkHeight)
                }
                .offset(visualState.mood.eyeOffset)

                HStack(spacing: 38) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.44, blue: 0.64).opacity(0.34))
                        .frame(width: 18, height: 12)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.44, blue: 0.64).opacity(0.34))
                        .frame(width: 18, height: 12)
                }
                .offset(y: 18)

                Smile()
                    .stroke(
                        Color(red: 0.08, green: 0.17, blue: 0.28).opacity(0.88),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: visualState.mood.smileSize.width, height: visualState.mood.smileSize.height)
                    .offset(visualState.mood.smileOffset)

                if visualState.isPaused {
                    PauseBadge()
                        .frame(width: 38, height: 38)
                        .offset(x: 44, y: -46)
                }

                if visualState.featureMode.showsChatBadge {
                    ChatBadge(isOpen: visualState.isChatOpen)
                        .frame(width: 38, height: 38)
                        .offset(x: 45, y: -47)
                }
            }
            .saturation(pausedTint)
            .frame(width: 132, height: 132)
            .offset(y: bob)
            .animation(.spring(response: 0.24, dampingFraction: 0.5), value: pop)
        }
        .frame(width: 144, height: 144)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onChange(of: visualState.reactionPulse) { _, _ in
            guard !visualState.isPaused else {
                return
            }

            pop = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                pop = false
            }
        }
    }

}

private struct ChatBadge: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.16), radius: 5, y: 2)

            Circle()
                .fill(isOpen ? Color(red: 0.30, green: 0.66, blue: 0.92) : Color.white.opacity(0.94))
                .padding(4)

            Image(systemName: isOpen ? "bubble.left.and.bubble.right.fill" : "bubble.left.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOpen ? Color.white : Color(red: 0.24, green: 0.50, blue: 0.78))
        }
        .accessibilityLabel("Open chat")
    }
}

private struct Eye: View {
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(Color(red: 0.06, green: 0.13, blue: 0.22))
            .frame(width: 14, height: height)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(height > 8 ? 0.88 : 0))
                    .frame(width: 4, height: 4)
                    .offset(x: 3, y: 3)
            }
    }
}

private struct CharacterBody: View {
    let character: BubbleCharacter
    let colors: [Color]

    var body: some View {
        let gradient = RadialGradient(
            colors: colors,
            center: .topLeading,
            startRadius: 8,
            endRadius: 96
        )

        switch character {
        case .bubble, .dot, .sprout:
            Circle()
                .fill(gradient)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.56), lineWidth: 4)
                )
        case .star:
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.56), lineWidth: 4)
                )
        }
    }
}

private extension BubbleMood {
    var breathRate: Double {
        switch self {
        case .happy: 2.0
        case .sleepy: 1.1
        case .shy: 1.7
        case .focus: 0.9
        }
    }

    var breathAmount: Double {
        switch self {
        case .happy: 0.025
        case .sleepy: 0.018
        case .shy: 0.014
        case .focus: 0.008
        }
    }

    var bobRate: Double {
        switch self {
        case .happy: 2.4
        case .sleepy: 1.0
        case .shy: 1.5
        case .focus: 0.7
        }
    }

    var bobAmount: CGFloat {
        switch self {
        case .happy: 4
        case .sleepy: 2
        case .shy: 2.5
        case .focus: 1
        }
    }

    var saturation: Double {
        switch self {
        case .happy: 1.0
        case .sleepy: 0.70
        case .shy: 0.88
        case .focus: 0.82
        }
    }

    var eyeOffset: CGSize {
        switch self {
        case .happy: CGSize(width: 0, height: -8)
        case .sleepy: CGSize(width: 0, height: -3)
        case .shy: CGSize(width: -2, height: -6)
        case .focus: CGSize(width: 0, height: -9)
        }
    }

    var smileOffset: CGSize {
        switch self {
        case .happy: CGSize(width: 0, height: 19)
        case .sleepy: CGSize(width: 0, height: 18)
        case .shy: CGSize(width: -4, height: 18)
        case .focus: CGSize(width: 0, height: 18)
        }
    }

    var smileSize: CGSize {
        switch self {
        case .happy: CGSize(width: 30, height: 18)
        case .sleepy: CGSize(width: 22, height: 9)
        case .shy: CGSize(width: 18, height: 12)
        case .focus: CGSize(width: 18, height: 7)
        }
    }

    func eyeHeight(at time: TimeInterval) -> CGFloat {
        switch self {
        case .happy:
            let cycle = time.truncatingRemainder(dividingBy: 4.7)
            return cycle > 4.48 ? 3 : 19
        case .sleepy:
            return 4
        case .shy:
            let cycle = time.truncatingRemainder(dividingBy: 5.5)
            return cycle > 5.2 ? 3 : 15
        case .focus:
            return 12
        }
    }
}

private extension BubbleCharacter {
    var bodySize: CGSize {
        switch self {
        case .bubble: CGSize(width: 132, height: 132)
        case .dot: CGSize(width: 118, height: 118)
        case .sprout: CGSize(width: 126, height: 126)
        case .star: CGSize(width: 122, height: 122)
        }
    }

    var highlightSize: CGSize {
        switch self {
        case .bubble: CGSize(width: 46, height: 30)
        case .dot: CGSize(width: 38, height: 24)
        case .sprout: CGSize(width: 42, height: 26)
        case .star: CGSize(width: 34, height: 22)
        }
    }

    var highlightOffset: CGSize {
        switch self {
        case .bubble: CGSize(width: -31, height: -35)
        case .dot: CGSize(width: -26, height: -30)
        case .sprout: CGSize(width: -28, height: -32)
        case .star: CGSize(width: -20, height: -28)
        }
    }

    @ViewBuilder var accent: some View {
        switch self {
        case .bubble, .dot:
            EmptyView()
        case .sprout:
            HStack(spacing: -3) {
                Capsule()
                    .frame(width: 18, height: 32)
                    .rotationEffect(.degrees(-34))
                Capsule()
                    .frame(width: 18, height: 32)
                    .rotationEffect(.degrees(34))
            }
            .opacity(0.78)
            .offset(y: -72)
        case .star:
            Image(systemName: "sparkle")
                .font(.system(size: 28, weight: .bold))
                .opacity(0.78)
                .offset(x: 40, y: -42)
        }
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 3))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.minY + 3),
            control: CGPoint(x: rect.midX, y: rect.maxY - 1)
        )
        return path
    }
}

private struct PauseBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.78))
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.16, green: 0.31, blue: 0.48))
                    .frame(width: 5, height: 15)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.16, green: 0.31, blue: 0.48))
                    .frame(width: 5, height: 15)
            }
        }
    }
}
