import Foundation

final class AIChatSettingsStore {
    private enum Key {
        static let providerMode = "habibiFloat.chat.providerMode"
        static let deviceID = "habibiFloat.chat.deviceID"
        static let sponsoredEndpoint = "habibiFloat.chat.sponsoredEndpoint"
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

            return nil
        }
        set {
            if let newValue {
                defaults.set(newValue.absoluteString, forKey: Key.sponsoredEndpoint)
            } else {
                defaults.removeObject(forKey: Key.sponsoredEndpoint)
            }
        }
    }
}
