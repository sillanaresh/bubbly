import Foundation

@MainActor
final class BubbleVisualState: ObservableObject {
    @Published var reactionPulse = 0
    @Published var isPaused = false
    @Published var isChatOpen = false
    @Published var theme: BubbleTheme = .ocean
    @Published var mood: BubbleMood = .happy
    @Published var character: BubbleCharacter = .bubble

    func react() {
        reactionPulse += 1
    }
}
