import Foundation

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var selectedMode: AIChatProviderMode
    @Published var status: AIChatStatus
    @Published var hasOpenRouterKey = false
    @Published var keyDraft = ""
    @Published var endpointDraft = ""
    @Published var modelDraft = ""
    @Published var modelDetail: String?
    @Published var remainingToday: Int?

    private let settings: AIChatSettingsStore
    private let keyStore: KeychainOpenRouterKeyStore
    private let service: AIChatService

    init(
        settings: AIChatSettingsStore,
        keyStore: KeychainOpenRouterKeyStore,
        service: AIChatService
    ) {
        self.settings = settings
        self.keyStore = keyStore
        self.service = service
        self.selectedMode = settings.providerMode
        self.endpointDraft = settings.sponsoredEndpoint?.absoluteString ?? ""
        self.modelDraft = settings.openRouterModel
        let storedKeyExists = (try? keyStore.readKey()?.isEmpty == false) ?? false
        self.hasOpenRouterKey = storedKeyExists
        self.status = service.status(hasOpenRouterKey: storedKeyExists)
    }

    func selectMode(_ mode: AIChatProviderMode) {
        guard AIChatProviderMode.userSelectable.contains(mode) else {
            return
        }

        selectedMode = mode
        settings.providerMode = mode
        refreshStatus()
    }

    func saveEndpoint() {
        let trimmed = endpointDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.sponsoredEndpoint = trimmed.isEmpty ? nil : URL(string: trimmed)
        refreshStatus()
    }

    func saveOpenRouterKey() {
        do {
            try keyStore.saveKey(keyDraft)
            hasOpenRouterKey = try keyStore.readKey()?.isEmpty == false
            keyDraft = ""
            errorMessage = nil
            refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveOpenRouterModel() {
        settings.openRouterModel = modelDraft
        modelDraft = settings.openRouterModel
        errorMessage = nil
        refreshStatus()
    }

    func removeOpenRouterKey() {
        do {
            try keyStore.deleteKey()
            hasOpenRouterKey = false
            keyDraft = ""
            refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else {
            return
        }

        inputText = ""
        errorMessage = nil
        let userMessage = AIChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isSending = true

        do {
            let result = try await service.send(messages: requestMessages())
            messages.append(AIChatMessage(role: .assistant, content: result.message))
            modelDetail = result.model
            remainingToday = result.remainingToday
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
        refreshStatus()
    }

    func clearHistory() {
        messages.removeAll()
        errorMessage = nil
        modelDetail = nil
        remainingToday = nil
    }

    private func requestMessages() -> [AIChatMessage] {
        let recent = messages.suffix(20)
        return Array(recent)
    }

    private func refreshStatus() {
        status = service.status(hasOpenRouterKey: hasOpenRouterKey)
    }
}
