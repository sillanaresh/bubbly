import Foundation

final class AIChatSettingsStore {
    private static let defaultSponsoredEndpoint = URL(string: "https://habibi-float-api.habibi-float.workers.dev/v1/chat")
    static let defaultOpenRouterModel = "openrouter/free"

    private enum Key {
        static let providerMode = "habibiFloat.chat.providerMode"
        static let deviceID = "habibiFloat.chat.deviceID"
        static let sponsoredEndpoint = "habibiFloat.chat.sponsoredEndpoint"
        static let openRouterModel = "habibiFloat.chat.openRouterModel"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var providerMode: AIChatProviderMode {
        get {
            let rawValue = defaults.string(forKey: Key.providerMode) ?? AIChatProviderMode.sponsored.rawValue
            return AIChatProviderMode(rawValue: rawValue) ?? .sponsored
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.providerMode)
        }
    }

    var deviceID: String {
        if let stored = defaults.string(forKey: Key.deviceID), !stored.isEmpty {
            return stored
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: Key.deviceID)
        return generated
    }

    var sponsoredEndpoint: URL? {
        get {
            if let stored = defaults.string(forKey: Key.sponsoredEndpoint), let url = URL(string: stored) {
                return url
            }

            if let value = Bundle.main.object(forInfoDictionaryKey: "HabibiChatBackendURL") as? String {
                return URL(string: value)
            }

            return Self.defaultSponsoredEndpoint
        }
        set {
            if let newValue {
                defaults.set(newValue.absoluteString, forKey: Key.sponsoredEndpoint)
            } else {
                defaults.removeObject(forKey: Key.sponsoredEndpoint)
            }
        }
    }

    var openRouterModel: String {
        get {
            let stored = defaults.string(forKey: Key.openRouterModel)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : Self.defaultOpenRouterModel
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? Self.defaultOpenRouterModel : trimmed, forKey: Key.openRouterModel)
        }
    }
}
