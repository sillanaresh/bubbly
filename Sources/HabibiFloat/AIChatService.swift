import Foundation

@MainActor
final class AIChatService {
    private let settings: AIChatSettingsStore
    private let keyStore: KeychainOpenRouterKeyStore
    private let session: URLSession

    init(
        settings: AIChatSettingsStore,
        keyStore: KeychainOpenRouterKeyStore,
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.keyStore = keyStore
        self.session = session
    }

    func status(hasOpenRouterKey: Bool) -> AIChatStatus {
        switch settings.providerMode {
        case .sponsored:
            if settings.sponsoredEndpoint == nil {
                return AIChatStatus(mode: .offline, detail: "Sponsored backend not configured")
            }
            return AIChatStatus(mode: .sponsored, detail: "30 sponsored messages per day")
        case .openRouterKey:
            if hasOpenRouterKey {
                return AIChatStatus(mode: .openRouterKey, detail: "Direct OpenRouter connection")
            }
            return AIChatStatus(mode: .offline, detail: "OpenRouter key required")
        case .offline:
            return AIChatStatus(mode: .offline, detail: "Network chat disabled")
        }
    }

    func send(messages: [AIChatMessage]) async throws -> AIChatResult {
        let wireMessages = messages.map { AIChatWireMessage(role: $0.role, content: $0.content) }

        switch settings.providerMode {
        case .sponsored:
            guard let endpoint = settings.sponsoredEndpoint else {
                throw AIChatError.missingSponsoredEndpoint
            }
            return try await sendSponsored(messages: wireMessages, endpoint: endpoint)
        case .openRouterKey:
            guard let key = try keyStore.readKey(), !key.isEmpty else {
                throw AIChatError.missingOpenRouterKey
            }
            return try await sendOpenRouter(messages: wireMessages, apiKey: key)
        case .offline:
            throw AIChatError.offline
        }
    }

    private func sendSponsored(messages: [AIChatWireMessage], endpoint: URL) async throws -> AIChatResult {
        let payload = SponsoredRequest(
            deviceId: settings.deviceID,
            messages: messages,
            clientVersion: appVersion
        )
        let response: SponsoredResponse = try await postJSON(payload, to: endpoint, headers: [:])
        return AIChatResult(message: response.message, model: response.model, remainingToday: response.remainingToday)
    }

    private func sendOpenRouter(messages: [AIChatWireMessage], apiKey: String) async throws -> AIChatResult {
        let payload = OpenRouterRequest(
            model: "openai/gpt-4o-mini",
            messages: messages,
            maxTokens: 700
        )
        let response: OpenRouterResponse = try await postJSON(
            payload,
            to: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "HTTP-Referer": "https://habibi.local",
                "X-Title": "Habibi Float"
            ]
        )

        guard let message = response.choices.first?.message.content, !message.isEmpty else {
            throw AIChatError.invalidResponse
        }

        return AIChatResult(message: message, model: response.model, remainingToday: nil)
    }

    private func postJSON<Payload: Encodable, Response: Decodable>(
        _ payload: Payload,
        to url: URL,
        headers: [String: String]
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw AIChatError.requestFailed("Chat is offline right now.")
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AIChatError.invalidResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(ChatErrorResponse.self, from: data) {
                throw AIChatError.requestFailed(errorResponse.error)
            }
            throw AIChatError.requestFailed("Chat is having trouble right now.")
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AIChatError.invalidResponse
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

private struct SponsoredRequest: Encodable {
    let deviceId: String
    let messages: [AIChatWireMessage]
    let clientVersion: String
}

private struct SponsoredResponse: Decodable {
    let message: String
    let model: String?
    let remainingToday: Int?
}

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [AIChatWireMessage]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        let message: AssistantMessage
    }

    struct AssistantMessage: Decodable {
        let content: String
    }

    let model: String?
    let choices: [Choice]
}

private struct ChatErrorResponse: Decodable {
    let error: String
    let code: String?
}
