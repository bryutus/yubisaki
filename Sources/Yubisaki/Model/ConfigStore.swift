import Foundation

final class ConfigStore: @unchecked Sendable {
    static let shared = ConfigStore()

    private(set) var profiles: [AppProfile] = []

    private var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appending(components: "yubisaki", "config.json")
    }

    func load() {
        guard
            let data = try? Data(contentsOf: configURL),
            let decoded = try? JSONDecoder().decode([AppProfile].self, from: data)
        else { return }
        profiles = decoded
    }

    func save() {
        let url = configURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func binding(for bundleID: String, gesture: GestureType) -> GestureBinding? {
        profiles
            .first { $0.bundleID == bundleID }?
            .bindings
            .first { $0.gesture == gesture }
    }

    func setBinding(_ binding: GestureBinding, for bundleID: String) {
        if let pi = profiles.firstIndex(where: { $0.bundleID == bundleID }) {
            if let bi = profiles[pi].bindings.firstIndex(where: { $0.gesture == binding.gesture }) {
                profiles[pi].bindings[bi] = binding
            } else {
                profiles[pi].bindings.append(binding)
            }
        } else {
            profiles.append(AppProfile(bundleID: bundleID, bindings: [binding]))
        }
        save()
    }

    func removeBinding(for bundleID: String, gesture: GestureType) {
        guard let pi = profiles.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        profiles[pi].bindings.removeAll { $0.gesture == gesture }
        if profiles[pi].bindings.isEmpty {
            profiles.remove(at: pi)
        }
        save()
    }
}
