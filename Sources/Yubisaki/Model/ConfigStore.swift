import Foundation
import Combine

final class ConfigStore: ObservableObject, @unchecked Sendable {
    static let shared = ConfigStore()

    @Published var profiles: [AppProfile] = []

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
}
