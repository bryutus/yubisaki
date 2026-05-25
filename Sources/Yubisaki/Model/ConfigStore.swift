import Foundation
import Combine

struct GlobalPreferences: Codable, Sendable, Equatable {
    var gesturesEnabled: Bool = true
    var launchAtLogin: Bool = false
    var showMenuBar: Bool = true
    var showInDock: Bool = false

    // Migration from future format changes
    private enum CodingKeys: String, CodingKey {
        case gesturesEnabled, launchAtLogin, showMenuBar, showInDock
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gesturesEnabled = try c.decodeIfPresent(Bool.self, forKey: .gesturesEnabled) ?? true
        launchAtLogin   = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)   ?? false
        showMenuBar     = try c.decodeIfPresent(Bool.self, forKey: .showMenuBar)      ?? true
        showInDock      = try c.decodeIfPresent(Bool.self, forKey: .showInDock)       ?? false
    }

    init() {}
}

final class ConfigStore: ObservableObject, @unchecked Sendable {
    static let shared = ConfigStore()

    @Published var globalProfile = AppProfile(bundleID: "global")
    @Published var profiles: [AppProfile] = []
    @Published var preferences = GlobalPreferences()

    private var baseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appending(component: "yubisaki")
    }

    private var profilesURL: URL { baseURL.appending(component: "config.json") }
    private var preferencesURL: URL { baseURL.appending(component: "preferences.json") }
    private var globalProfileURL: URL { baseURL.appending(component: "global.json") }

    func load() {
        loadProfiles()
        loadPreferences()
        loadGlobalProfile()
    }

    func save() {
        saveProfiles()
        savePreferences()
        saveGlobalProfile()
    }

    func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        try? data.write(to: preferencesURL, options: .atomic)
    }

    func binding(for bundleID: String, gesture: GestureType) -> GestureBinding? {
        profiles
            .first { $0.bundleID == bundleID }?
            .bindings
            .first { $0.gesture == gesture && $0.enabled }
    }

    // MARK: - Private

    private func loadGlobalProfile() {
        guard
            let data = try? Data(contentsOf: globalProfileURL),
            let decoded = try? JSONDecoder().decode(AppProfile.self, from: data)
        else { return }
        globalProfile = decoded
    }

    private func saveGlobalProfile() {
        ensureBaseDirectory()
        guard let data = try? JSONEncoder().encode(globalProfile) else { return }
        try? data.write(to: globalProfileURL, options: .atomic)
    }

    private func loadProfiles() {
        ensureBaseDirectory()
        guard
            let data = try? Data(contentsOf: profilesURL),
            let decoded = try? JSONDecoder().decode([AppProfile].self, from: data)
        else { return }
        profiles = decoded
    }

    private func loadPreferences() {
        guard
            let data = try? Data(contentsOf: preferencesURL),
            let decoded = try? JSONDecoder().decode(GlobalPreferences.self, from: data)
        else { return }
        preferences = decoded
    }

    private func saveProfiles() {
        ensureBaseDirectory()
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: profilesURL, options: .atomic)
    }

    private func ensureBaseDirectory() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
