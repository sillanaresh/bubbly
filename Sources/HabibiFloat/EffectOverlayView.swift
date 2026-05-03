import SwiftUI

struct EffectOverlayView: View {
    let action: BubbleAction
    let origin: CGPoint

    @State private var animate = false

    var body: some View {
        ZStack {
            switch action {
            case .rain:
                rain
            case .cloud:
                cloud
            case .butterflies:
                butterflies
            case .cannon:
                cannon
            case .sparkles:
                sparkles
            case .chat:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeOut(duration: 1.7)) {
                animate = true
            }
        }
    }

    private var rain: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 0.34, green: 0.65, blue: 0.95).opacity(animate ? 0 : 0.82))
                    .frame(width: 4, height: 18)
                    .rotationEffect(.degrees(10))
                    .position(
                        x: origin.x + CGFloat((index % 11) - 5) * 24,
                        y: origin.y - 120 + CGFloat(index / 11) * 24 + (animate ? 210 : 0)
                    )
            }
        }
    }

    private var cloud: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(animate ? 0 : 0.88))
                    .frame(width: CGFloat([70, 92, 82, 58, 74, 48, 62][index]))
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
                    .position(
                        x: origin.x + CGFloat([-90, -42, 24, 84, -8, 126, -130][index]),
                        y: origin.y - CGFloat([94, 124, 118, 98, 82, 126, 116][index]) - (animate ? 28 : 0)
                    )
            }
        }
    }

    private var butterflies: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "paperplane.fill")
                    .font(.system(size: CGFloat([18, 22, 16, 20, 24, 17][index % 6]), weight: .semibold))
                    .foregroundStyle([Color.pink, Color.purple, Color.orange, Color.mint][index % 4])
                    .opacity(animate ? 0 : 0.86)
                    .rotationEffect(.degrees(animate ? Double(index * 38) : Double(index * 17)))
                    .position(
                        x: origin.x + CGFloat((index % 6) - 3) * 38 + (animate ? CGFloat((index % 3) - 1) * 80 : 0),
                        y: origin.y - CGFloat(30 + (index / 6) * 62) - (animate ? CGFloat(120 + index * 5) : 0)
                    )
            }
        }
    }

    private var cannon: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill([Color.orange, Color.yellow, Color.red, Color.pink][index % 4])
                    .frame(width: CGFloat([9, 13, 7, 11, 15, 8][index % 6]))
                    .opacity(animate ? 0 : 0.92)
                    .position(
                        x: origin.x + cos(CGFloat(index) * .pi / 9) * (animate ? 210 : 28),
                        y: origin.y + sin(CGFloat(index) * .pi / 9) * (animate ? 170 : 22)
                    )
            }
        }
    }

    private var sparkles: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "star.fill")
                    .font(.system(size: CGFloat([14, 18, 22, 16][index % 4]), weight: .bold))
                    .foregroundStyle([Color.yellow, Color.cyan, Color.purple, Color.white][index % 4])
                    .opacity(animate ? 0 : 0.90)
                    .scaleEffect(animate ? 1.8 : 0.45)
                    .position(
                        x: origin.x + cos(CGFloat(index) * .pi / 8) * (animate ? 190 : 42),
                        y: origin.y + sin(CGFloat(index) * .pi / 8) * (animate ? 150 : 32)
                    )
            }
        }
    }
}

