import SwiftUI

struct EffectOverlayView: View {
    let action: BubbleAction
    let origin: CGPoint

    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                switch action {
                case .rain:
                    rain(in: size)
                case .cloud:
                    cloud(in: size)
                case .butterflies:
                    butterflies(in: size)
                case .cannon:
                    cannon(in: size)
                case .sparkles:
                    sparkles(in: size)
                case .chat:
                    EmptyView()
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeInOut(duration: action == .rain ? 2.0 : 1.7)) {
                animate = true
            }
        }
    }

    private func rain(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<90, id: \.self) { index in
                let column = CGFloat(index % 18)
                let row = CGFloat(index / 18)
                let x = (column + 0.35 + CGFloat((index * 7) % 5) * 0.09) * size.width / 18
                let startY = -80 - row * 58 - CGFloat((index * 13) % 41)
                let endY = size.height + 120 + row * 18

                Capsule()
                    .fill(Color(red: 0.34, green: 0.65, blue: 0.95).opacity(animate ? 0.10 : 0.72))
                    .frame(width: CGFloat([2, 3, 2.5, 3.5][index % 4]), height: CGFloat([24, 34, 28, 40][index % 4]))
                    .rotationEffect(.degrees(12))
                    .blur(radius: index.isMultiple(of: 4) ? 0.5 : 0)
                    .position(
                        x: x,
                        y: animate ? endY : startY
                    )
            }
        }
    }

    private func cloud(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let cluster = CGFloat(index % 6)
                let band = CGFloat(index / 6)
                Circle()
                    .fill(Color.white.opacity(animate ? 0 : 0.70))
                    .frame(width: CGFloat([70, 96, 82, 58, 74, 112][index % 6]))
                    .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
                    .position(
                        x: size.width * (0.12 + cluster * 0.16) + (animate ? 80 : -60),
                        y: size.height * (0.18 + band * 0.18) - (animate ? 28 : 0)
                    )
            }
        }
    }

    private func butterflies(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let column = CGFloat(index % 8)
                let row = CGFloat(index / 8)
                Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "paperplane.fill")
                    .font(.system(size: CGFloat([18, 22, 16, 20, 24, 17][index % 6]), weight: .semibold))
                    .foregroundStyle([Color.pink, Color.purple, Color.orange, Color.mint][index % 4])
                    .opacity(animate ? 0 : 0.86)
                    .rotationEffect(.degrees(animate ? Double(index * 38) : Double(index * 17)))
                    .position(
                        x: size.width * (0.08 + column * 0.12) + (animate ? CGFloat((index % 3) - 1) * 90 : 0),
                        y: size.height * (0.78 - row * 0.22) - (animate ? CGFloat(180 + index * 3) : 0)
                    )
            }
        }
    }

    private func cannon(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<34, id: \.self) { index in
                Circle()
                    .fill([Color.orange, Color.yellow, Color.red, Color.pink][index % 4])
                    .frame(width: CGFloat([9, 13, 7, 11, 15, 8][index % 6]))
                    .opacity(animate ? 0 : 0.92)
                    .position(
                        x: origin.x + cos(CGFloat(index) * .pi / 17) * (animate ? min(size.width, 760) * 0.42 : 28),
                        y: origin.y + sin(CGFloat(index) * .pi / 17) * (animate ? min(size.height, 520) * 0.42 : 22)
                    )
            }
        }
    }

    private func sparkles(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<34, id: \.self) { index in
                let column = CGFloat(index % 10)
                let row = CGFloat(index / 10)
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "star.fill")
                    .font(.system(size: CGFloat([14, 18, 22, 16][index % 4]), weight: .bold))
                    .foregroundStyle([Color.yellow, Color.cyan, Color.purple, Color.white][index % 4])
                    .opacity(animate ? 0 : 0.90)
                    .scaleEffect(animate ? 1.8 : 0.45)
                    .position(
                        x: size.width * (0.06 + column * 0.10),
                        y: size.height * (0.18 + row * 0.18)
                    )
            }
        }
    }
}
