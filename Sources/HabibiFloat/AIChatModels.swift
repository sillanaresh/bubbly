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

    var title: String {
        switch self {
        case .sponsored: "Sponsored"
        case .openRouterKey: "Your OpenRouter Key"
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
            "Sponsored chat is not configured yet."
        case .missingOpenRouterKey:
            "Add your OpenRouter key to use direct chat."
        case .offline:
            "Chat is offline right now."
        case .invalidResponse:
            "Chat returned an unexpected response."
        case .requestFailed(let message):
            message
        }
    }
}
