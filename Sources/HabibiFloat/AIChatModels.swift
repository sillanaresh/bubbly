import Foundation

enum AIChatRole: String, Codable, Equatable {
    case system
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: AIChatRole
    var content: String

    init(id: UUID = UUID(), role: AIChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct AIChatWireMessage: Codable, Equatable {
    let role: AIChatRole
    let content: String
}

struct AIChatResult: Equatable {
    let message: String
    let model: String?
    let remainingToday: Int?
}

enum AIChatProviderMode: String, CaseIterable {
    case sponsored
    case openRouterKey
    case offline

    // Keep Advanced/BYOK support in code for a future release, but hide it from v1.
    static let userSelectable: [AIChatProviderMode] = [.sponsored]

    var title: String {
        switch self {
        case .sponsored: "Bubbly Free"
        case .openRouterKey: "Advanced"
        case .offline: "Offline"
        }
    }
}

struct AIChatStatus: Equatable {
    let mode: AIChatProviderMode
    let detail: String
}

enum AIChatError: LocalizedError, Equatable {
    case missingSponsoredEndpoint
    case missingOpenRouterKey
    case offline
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSponsoredEndpoint:
            "Bubbly Free chat is not configured yet."
        case .missingOpenRouterKey:
            "Add your OpenRouter key to use direct chat."
        case .offline:
            "Chat is offline right now."
        case .invalidResponse:
            "Bubbly had trouble answering. Please try again."
        case .requestFailed(let message):
            message
        }
    }
}
