import SwiftUI

struct BubbleView: View {
    @ObservedObject var visualState: BubbleVisualState
    @State private var pop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let breath = visualState.isPaused ? 1 : 1 + sin(time * 2.0) * 0.025
            let bob = visualState.isPaused ? 0 : sin(time * 2.4) * 4
            let blinkHeight = visualState.isPaused ? 14 : Self.eyeHeight(at: time)
            let pausedTint = visualState.isPaused ? 0.72 : 1

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.94, green: 0.98, blue: 1.00),
                                Color(red: 0.44, green: 0.79, blue: 0.95),
                                Color(red: 0.31, green: 0.57, blue: 0.88)
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 96
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.56), lineWidth: 4)
                            .blur(radius: 0.3)
                    )
                    .scaleEffect(x: breath * (pop ? 1.08 : 1.0), y: (2 - breath) * (pop ? 0.94 : 1.0))

                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: 46, height: 30)
                    .blur(radius: 1)
                    .offset(x: -31, y: -35)

                HStack(spacing: 28) {
                    Eye(height: blinkHeight)
                    Eye(height: blinkHeight)
                }
                .offset(y: -8)

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
                    .frame(width: 30, height: 18)
                    .offset(y: 19)

                if visualState.isPaused {
                    PauseBadge()
                        .frame(width: 38, height: 38)
                        .offset(x: 44, y: -46)
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

    private static func eyeHeight(at time: TimeInterval) -> CGFloat {
        let cycle = time.truncatingRemainder(dividingBy: 4.7)
        return cycle > 4.48 ? 3 : 19
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
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
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
