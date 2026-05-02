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
    case dot
    case sprout
    case star

    var title: String {
        switch self {
        case .bubble: "Bubble"
        case .dot: "Dot"
        case .sprout: "Sprout"
        case .star: "Star"
        }
    }

    static func from(id: String) -> BubbleCharacter {
        BubbleCharacter(rawValue: id) ?? .bubble
    }
}
