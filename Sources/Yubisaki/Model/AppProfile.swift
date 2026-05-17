struct AppProfile: Codable, Sendable, Identifiable {
    var id: String { bundleID }
    var bundleID: String
    var bindings: [GestureBinding]
}
