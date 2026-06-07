import Foundation
import os

/// ジェスチャー判定ホットパス（CGEventTap スレッド）から読むための最小スナップショット。
/// `ConfigStore` の `@Observable` 状態には触れず、これだけをロック越しに参照する。
struct GestureSnapshot: Sendable {
    var gesturesEnabled = true
    // 現在検出可能なジェスチャー(pinchIn/Out)に使用可能なバインディングを持つ、有効なプロファイルの bundleID。
    // ここに無いアプリでは pinch を消費せず、ネイティブのピンチズームを温存する。
    var pinchBoundBundleIDs: Set<String> = []
    var globalHasPinchBinding = false
}

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

/// 並行アクセス方針:
/// - `@Observable` な状態（`globalProfile` / `profiles` / `preferences`）はメインスレッド専用
///   （SwiftUI と `AppDelegate`）。これらをオフメインから読み書きしてはならない。
/// - CGEventTap スレッドなどメイン外から必要な値は `gestureSnapshot()` 経由でのみ参照する。
///   スナップショットは `OSAllocatedUnfairLock` で保護され、状態更新時に `refreshGestureSnapshot()`
///   で再生成される。この2点で `@unchecked Sendable` の安全性を担保する。
@Observable
final class ConfigStore: @unchecked Sendable {
    static let shared = ConfigStore()

    var globalProfile = AppProfile(bundleID: "global")
    var profiles: [AppProfile] = []
    var preferences = GlobalPreferences()

    @ObservationIgnored
    private let gestureSnapshotLock = OSAllocatedUnfairLock(initialState: GestureSnapshot())

    /// メイン外（CGEventTap スレッド）から安全に読めるジェスチャー判定用スナップショット。
    func gestureSnapshot() -> GestureSnapshot {
        gestureSnapshotLock.withLock { $0 }
    }

    /// 現在のメインスレッド状態からスナップショットを作り直す。状態変更後にメインから呼ぶ。
    private func refreshGestureSnapshot() {
        func hasUsablePinchBinding(_ profile: AppProfile) -> Bool {
            profile.enabled && profile.bindings.contains {
                ($0.gesture == .pinchIn || $0.gesture == .pinchOut) && $0.enabled && $0.keyCode != 0
            }
        }
        let snapshot = GestureSnapshot(
            gesturesEnabled: preferences.gesturesEnabled,
            pinchBoundBundleIDs: Set(profiles.filter(hasUsablePinchBinding).map(\.bundleID)),
            globalHasPinchBinding: hasUsablePinchBinding(globalProfile)
        )
        gestureSnapshotLock.withLock { $0 = snapshot }
    }

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
        refreshGestureSnapshot()
    }

    func save() {
        saveProfiles()
        savePreferences()
        saveGlobalProfile()
        refreshGestureSnapshot()
    }

    func savePreferences() {
        refreshGestureSnapshot()
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        try? data.write(to: preferencesURL, options: .atomic)
    }

    func binding(for bundleID: String, gesture: GestureType) -> GestureBinding? {
        // keyCode == 0 は「ショートカット未設定」。発火させると virtualKey 0 = 'A' を送って
        // しまうため、未設定のバインディングは一致対象から除外する。
        if let b = profiles.first(where: { $0.bundleID == bundleID && $0.enabled })?
            .bindings.first(where: { $0.gesture == gesture && $0.enabled && $0.keyCode != 0 }) {
            return b
        }
        guard globalProfile.enabled else { return nil }
        return globalProfile.bindings.first { $0.gesture == gesture && $0.enabled && $0.keyCode != 0 }
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
