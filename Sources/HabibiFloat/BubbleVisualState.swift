import Foundation

@MainActor
final class BubbleVisualState: ObservableObject {
    @Published var reactionPulse = 0
    @Published var isPaused = false

    func react() {
        reactionPulse += 1
    }
}
