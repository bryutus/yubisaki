import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "yubisaki", category: "ConfigStore")

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
    var showInDock: Bool = false
    var hudEnabled: Bool = true

    // Migration from future format changes
    private enum CodingKeys: String, CodingKey {
        case gesturesEnabled, launchAtLogin, showInDock, hudEnabled
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gesturesEnabled = try c.decodeIfPresent(Bool.self, forKey: .gesturesEnabled) ?? true
        launchAtLogin   = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)   ?? false
        showInDock      = try c.decodeIfPresent(Bool.self, forKey: .showInDock)       ?? false
        hudEnabled      = try c.decodeIfPresent(Bool.self, forKey: .hudEnabled)       ?? true
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

    var globalProfile = AppProfile(bundleID: AppProfile.globalBundleID)
    var profiles: [AppProfile] = []
    var preferences = GlobalPreferences()

    /// 設定ファイルの保存先ベースディレクトリ。既定は
    /// `~/Library/Application Support/yubisaki`。テストでは一時ディレクトリを注入する。
    @ObservationIgnored
    private let baseURL: URL

    /// - Parameter baseDirectory: 設定ファイルの保存先。省略時は Application Support 配下。
    init(baseDirectory: URL = ConfigStore.defaultBaseDirectory) {
        self.baseURL = baseDirectory
    }

    private static var defaultBaseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appending(component: "yubisaki")
    }

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
                ($0.gesture == .pinchIn || $0.gesture == .pinchOut) && $0.isUsable
            }
        }
        let snapshot = GestureSnapshot(
            gesturesEnabled: preferences.gesturesEnabled,
            pinchBoundBundleIDs: Set(profiles.filter(hasUsablePinchBinding).map(\.bundleID)),
            globalHasPinchBinding: hasUsablePinchBinding(globalProfile)
        )
        gestureSnapshotLock.withLock { $0 = snapshot }
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
    }

    // 変更箇所だけ書き込めるよう、粒度別の保存も公開する。いずれもスナップショットを更新する。
    func savePreferences() {
        refreshGestureSnapshot()
        do {
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: preferencesURL, options: .atomic)
        } catch {
            logger.error("Failed to save preferences: \(error, privacy: .public)")
        }
    }

    func saveProfiles() {
        refreshGestureSnapshot()
        ensureBaseDirectory()
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesURL, options: .atomic)
        } catch {
            logger.error("Failed to save profiles: \(error, privacy: .public)")
        }
    }

    func saveGlobalProfile() {
        refreshGestureSnapshot()
        ensureBaseDirectory()
        do {
            let data = try JSONEncoder().encode(globalProfile)
            try data.write(to: globalProfileURL, options: .atomic)
        } catch {
            logger.error("Failed to save global profile: \(error, privacy: .public)")
        }
    }

    func binding(for bundleID: String, gesture: GestureType) -> GestureBinding? {
        // keyCode == 0 は「ショートカット未設定」。発火させると virtualKey 0 = 'A' を送って
        // しまうため、未設定のバインディングは一致対象から除外する。
        if let b = profiles.first(where: { $0.bundleID == bundleID && $0.enabled })?
            .bindings.first(where: { $0.gesture == gesture && $0.isUsable }) {
            return b
        }
        guard globalProfile.enabled else { return nil }
        return globalProfile.bindings.first { $0.gesture == gesture && $0.isUsable }
    }

    // MARK: - Private

    private func loadGlobalProfile() {
        guard let data = try? Data(contentsOf: globalProfileURL) else { return }
        do {
            globalProfile = try JSONDecoder().decode(AppProfile.self, from: data)
            logger.debug("Loaded global profile (\(self.globalProfile.bindings.count) bindings)")
        } catch {
            logger.error("Failed to decode global profile: \(error, privacy: .public)")
        }
    }

    private func loadProfiles() {
        ensureBaseDirectory()
        guard let data = try? Data(contentsOf: profilesURL) else { return }
        do {
            profiles = try JSONDecoder().decode([AppProfile].self, from: data)
            logger.debug("Loaded \(self.profiles.count) app profiles")
        } catch {
            logger.error("Failed to decode profiles: \(error, privacy: .public)")
        }
    }

    private func loadPreferences() {
        guard let data = try? Data(contentsOf: preferencesURL) else { return }
        do {
            preferences = try JSONDecoder().decode(GlobalPreferences.self, from: data)
            logger.debug("Loaded preferences (gesturesEnabled: \(self.preferences.gesturesEnabled))")
        } catch {
            logger.error("Failed to decode preferences: \(error, privacy: .public)")
        }
    }

    private func ensureBaseDirectory() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
