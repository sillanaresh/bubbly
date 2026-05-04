import SwiftUI

enum BubbleTheme: String, CaseIterable {
    case ocean
    case strawberry
    case mint
    case sunset
    case lavender

    var title: String {
        switch self {
        case .ocean: "Ocean"
        case .strawberry: "Strawberry"
        case .mint: "Mint"
        case .sunset: "Sunset"
        case .lavender: "Lavender"
        }
    }

    var colors: [Color] {
        switch self {
        case .ocean:
            [
                Color(red: 0.94, green: 0.98, blue: 1.00),
                Color(red: 0.44, green: 0.79, blue: 0.95),
                Color(red: 0.31, green: 0.57, blue: 0.88)
            ]
        case .strawberry:
            [
                Color(red: 1.00, green: 0.96, blue: 0.98),
                Color(red: 1.00, green: 0.51, blue: 0.66),
                Color(red: 0.89, green: 0.25, blue: 0.42)
            ]
        case .mint:
            [
                Color(red: 0.94, green: 1.00, blue: 0.97),
                Color(red: 0.45, green: 0.88, blue: 0.72),
                Color(red: 0.20, green: 0.64, blue: 0.55)
            ]
        case .sunset:
            [
                Color(red: 1.00, green: 0.97, blue: 0.88),
                Color(red: 1.00, green: 0.61, blue: 0.38),
                Color(red: 0.88, green: 0.35, blue: 0.40)
            ]
        case .lavender:
            [
                Color(red: 0.98, green: 0.96, blue: 1.00),
                Color(red: 0.66, green: 0.58, blue: 0.94),
                Color(red: 0.45, green: 0.39, blue: 0.78)
            ]
        }
    }

    static func from(id: String) -> BubbleTheme {
        BubbleTheme(rawValue: id) ?? .ocean
    }
}

enum BubbleMood: String, CaseIterable {
    case happy
    case sleepy
    case shy
    case focus

    var title: String {
        switch self {
        case .happy: "Happy"
        case .sleepy: "Sleepy"
        case .shy: "Shy"
        case .focus: "Focus"
        }
    }

    static func from(id: String) -> BubbleMood {
        BubbleMood(rawValue: id) ?? .happy
    }
}

enum BubbleCharacter: String, CaseIterable {
    case bubble
    case kitten
    case puppy
    case dot
    case sprout
    case star

    static let visibleChoices: [BubbleCharacter] = [.bubble, .kitten, .puppy]

    var title: String {
        switch self {
        case .bubble: "Bubbly"
        case .kitten: "Cat"
        case .puppy: "Dog"
        case .dot: "Dot"
        case .sprout: "Sprout"
        case .star: "Star"
        }
    }

    static func from(id: String) -> BubbleCharacter {
        let character = BubbleCharacter(rawValue: id) ?? .bubble
        return visibleChoices.contains(character) ? character : .bubble
    }
}

enum BubbleFeatureMode: String, CaseIterable {
    case carefree
    case chat
    case playground
    case everything

    var title: String {
        switch self {
        case .carefree: "Carefree"
        case .chat: "Chatty"
        case .playground: "Playtime"
        case .everything: "Bubbly Max"
        }
    }

    var enabledActions: [BubbleAction] {
        switch self {
        case .chat:
            return [.chat]
        case .playground:
            return BubbleAction.effectActions
        case .everything:
            return BubbleAction.allCases
        case .carefree:
            return []
        }
    }

    static func from(id: String) -> BubbleFeatureMode {
        BubbleFeatureMode(rawValue: id) ?? .chat
    }
}

enum BubbleAction: String, CaseIterable {
    case chat
    case rain
    case cloud
    case butterflies
    case cannon
    case sparkles

    static let effectActions: [BubbleAction] = [.rain, .cloud, .butterflies, .cannon, .sparkles]

    var title: String {
        switch self {
        case .chat: "Chat"
        case .rain: "Rain"
        case .cloud: "Cloud"
        case .butterflies: "Butterflies"
        case .cannon: "Cannon"
        case .sparkles: "Sparkles"
        }
    }

    var systemImageName: String {
        switch self {
        case .chat: "bubble.left.fill"
        case .rain: "cloud.rain.fill"
        case .cloud: "cloud.fill"
        case .butterflies: "leaf.fill"
        case .cannon: "target"
        case .sparkles: "sparkles"
        }
    }

    var offset: CGSize {
        switch self {
        case .chat: CGSize(width: 45, height: -47)
        case .rain: CGSize(width: -45, height: -47)
        case .cloud: CGSize(width: -61, height: 0)
        case .butterflies: CGSize(width: -42, height: 49)
        case .cannon: CGSize(width: 42, height: 49)
        case .sparkles: CGSize(width: 61, height: 0)
        }
    }

    func offset(for character: BubbleCharacter) -> CGSize {
        switch character {
        case .kitten, .puppy:
            switch self {
            case .chat: CGSize(width: 0, height: -54)
            case .rain: CGSize(width: -58, height: -20)
            case .cloud: CGSize(width: -58, height: 24)
            case .butterflies: CGSize(width: -30, height: 56)
            case .cannon: CGSize(width: 30, height: 56)
            case .sparkles: CGSize(width: 58, height: 24)
            }
        case .bubble, .dot, .sprout, .star:
            offset
        }
    }

    var tint: Color {
        switch self {
        case .chat: Color(red: 0.24, green: 0.50, blue: 0.78)
        case .rain: Color(red: 0.26, green: 0.52, blue: 0.88)
        case .cloud: Color(red: 0.47, green: 0.58, blue: 0.68)
        case .butterflies: Color(red: 0.88, green: 0.42, blue: 0.72)
        case .cannon: Color(red: 0.89, green: 0.45, blue: 0.28)
        case .sparkles: Color(red: 0.72, green: 0.48, blue: 0.92)
        }
    }
}
