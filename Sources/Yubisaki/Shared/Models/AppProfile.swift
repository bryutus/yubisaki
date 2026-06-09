struct AppProfile: Codable, Sendable, Identifiable {
    var id: String { bundleID }
    var bundleID: String
    var enabled: Bool
    var bindings: [GestureBinding]

    init(bundleID: String, enabled: Bool = true, bindings: [GestureBinding] = []) {
        self.bundleID = bundleID
        self.enabled = enabled
        self.bindings = bindings
    }

    // MARK: - Codable (migration from v1 format: no enabled)

    private enum CodingKeys: String, CodingKey {
        case bundleID, enabled, bindings
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self,              forKey: .bundleID)
        enabled  = try c.decodeIfPresent(Bool.self,       forKey: .enabled) ?? true
        bindings = try c.decode([GestureBinding].self,    forKey: .bindings)
    }
}
