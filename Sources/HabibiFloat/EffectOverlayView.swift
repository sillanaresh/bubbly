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
            ForEach(0..<130, id: \.self) { index in
                let x = random(index, 11) * size.width
                let drift = signedRandom(index, 12) * 90
                let startY = -80 - random(index, 13) * size.height * 0.95
                let endY = size.height + 90 + random(index, 14) * 180

                Capsule()
                    .fill(Color(red: 0.34, green: 0.65, blue: 0.95).opacity(animate ? 0.04 : Double(0.36 + random(index, 15) * 0.42)))
                    .frame(width: CGFloat(1.5 + random(index, 16) * 2.4), height: CGFloat(18 + random(index, 17) * 34))
                    .rotationEffect(.degrees(10 + Double(signedRandom(index, 18) * 8)))
                    .blur(radius: index.isMultiple(of: 4) ? 0.5 : 0)
                    .position(
                        x: x + (animate ? drift : -drift * 0.18),
                        y: animate ? endY : startY
                    )
            }
        }
    }

    private func cloud(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<28, id: \.self) { index in
                let cluster = index / 5
                let clusterX = random(cluster, 22) * size.width
                let clusterY = size.height * (0.10 + random(cluster, 23) * 0.42)
                let localX = signedRandom(index, 24) * CGFloat(90 + cluster * 8)
                let localY = signedRandom(index, 25) * CGFloat(34 + cluster * 3)

                Circle()
                    .fill(Color.white.opacity(animate ? 0 : 0.70))
                    .frame(width: CGFloat(46 + random(index, 26) * 74))
                    .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
                    .position(
                        x: clusterX + localX + (animate ? 90 + random(index, 27) * 80 : -40),
                        y: clusterY + localY - (animate ? 18 + random(index, 28) * 36 : 0)
                    )
            }
        }
    }

    private func butterflies(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<28, id: \.self) { index in
                let startX = random(index, 31) * size.width
                let startY = size.height * (0.32 + random(index, 32) * 0.58)
                let driftX = signedRandom(index, 33) * 190
                let lift = CGFloat(120 + random(index, 34) * 260)

                Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "paperplane.fill")
                    .font(.system(size: CGFloat(14 + random(index, 35) * 14), weight: .semibold))
                    .foregroundStyle([Color.pink, Color.purple, Color.orange, Color.mint][index % 4])
                    .opacity(animate ? 0 : 0.86)
                    .rotationEffect(.degrees(animate ? Double(index * 28) + Double(signedRandom(index, 36) * 90) : Double(signedRandom(index, 37) * 80)))
                    .position(
                        x: startX + (animate ? driftX : 0),
                        y: startY - (animate ? lift : 0)
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
                let x = random(index, 51) * size.width
                let y = size.height * (0.10 + random(index, 52) * 0.78)

                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "star.fill")
                    .font(.system(size: CGFloat(12 + random(index, 53) * 18), weight: .bold))
                    .foregroundStyle([Color.yellow, Color.cyan, Color.purple, Color.white][index % 4])
                    .opacity(animate ? 0 : 0.90)
                    .scaleEffect(animate ? CGFloat(1.4 + random(index, 54) * 0.9) : CGFloat(0.35 + random(index, 55) * 0.35))
                    .position(
                        x: x,
                        y: y
                    )
            }
        }
    }

    private func random(_ index: Int, _ salt: Double) -> CGFloat {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return CGFloat(value - floor(value))
    }

    private func signedRandom(_ index: Int, _ salt: Double) -> CGFloat {
        random(index, salt) * 2 - 1
    }
}
