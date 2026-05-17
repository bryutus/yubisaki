struct AppProfile: Codable, Sendable {
    var bundleID: String
    var bindings: [GestureBinding]
}
