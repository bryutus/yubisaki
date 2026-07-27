import Foundation
import Testing
@testable import Yubisaki

@MainActor
struct ConfigStoreTests {

    // MARK: - テスト補助

    /// 一時ディレクトリを使う独立した `ConfigStore` を生成し、末尾で後始末する。
    /// swift-testing はテストを並列実行するため、テストごとに一意なディレクトリを割り当てる。
    private func withStore(_ body: (ConfigStore, URL) throws -> Void) rethrows {
        let dir = FileManager.default.temporaryDirectory
            .appending(component: "yubisaki-tests")
            .appending(component: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(ConfigStore(baseDirectory: dir), dir)
    }

    private func usablePinchProfile(bundleID: String, gesture: GestureType = .pinchIn) -> AppProfile {
        AppProfile(bundleID: bundleID, bindings: [GestureBinding(gesture: gesture, keyCode: 1)])
    }

    // MARK: - binding(for:gesture:) の解決順序

    @Test func アプリ個別のバインディングがグローバルより優先される() {
        withStore { store, _ in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 5)]
            )
            let appBinding = GestureBinding(gesture: .pinchIn, keyCode: 9)
            store.profiles = [AppProfile(bundleID: "com.example.app", bindings: [appBinding])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == appBinding.id)
            #expect(resolved?.keyCode == 9)
        }
    }

    @Test func アプリ個別に該当ジェスチャーがなければグローバルにフォールバックする() {
        withStore { store, _ in
            let globalBinding = GestureBinding(gesture: .pinchIn, keyCode: 5)
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID, bindings: [globalBinding])
            // アプリプロファイルは別ジェスチャーのみ持つ
            store.profiles = [AppProfile(
                bundleID: "com.example.app",
                bindings: [GestureBinding(gesture: .pinchOut, keyCode: 9)])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == globalBinding.id)
        }
    }

    @Test func アプリプロファイルが無効ならグローバルにフォールバックする() {
        withStore { store, _ in
            let globalBinding = GestureBinding(gesture: .pinchIn, keyCode: 5)
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID, bindings: [globalBinding])
            store.profiles = [AppProfile(
                bundleID: "com.example.app",
                enabled: false,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 9)])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == globalBinding.id)
        }
    }

    @Test func 無効なバインディングは一致対象にならずグローバルにフォールバックする() {
        withStore { store, _ in
            let globalBinding = GestureBinding(gesture: .pinchIn, keyCode: 5)
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID, bindings: [globalBinding])
            store.profiles = [AppProfile(
                bundleID: "com.example.app",
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 9, enabled: false)])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == globalBinding.id)
        }
    }

    @Test func ショートカット未設定のバインディングは一致対象にならずグローバルにフォールバックする() {
        withStore { store, _ in
            let globalBinding = GestureBinding(gesture: .pinchIn, keyCode: 5)
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID, bindings: [globalBinding])
            store.profiles = [AppProfile(
                bundleID: "com.example.app",
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: nil)])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == globalBinding.id)
        }
    }

    @Test func keyCode0のバインディングはAキーとして一致する() {
        withStore { store, _ in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 5)])
            let appBinding = GestureBinding(gesture: .pinchIn, keyCode: 0)
            store.profiles = [AppProfile(bundleID: "com.example.app", bindings: [appBinding])]

            let resolved = store.binding(for: "com.example.app", gesture: .pinchIn)
            #expect(resolved?.id == appBinding.id)
            #expect(resolved?.keyCode == 0)
        }
    }

    @Test func グローバルプロファイルが無効ならnilを返す() {
        withStore { store, _ in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                enabled: false,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 5)])
            store.profiles = []

            #expect(store.binding(for: "com.example.app", gesture: .pinchIn) == nil)
        }
    }

    @Test func グローバルの無効なバインディングは一致せずnilを返す() {
        withStore { store, _ in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 5, enabled: false)])
            store.profiles = []

            #expect(store.binding(for: "com.example.app", gesture: .pinchIn) == nil)
        }
    }

    // MARK: - gestureSnapshot()

    @Test func gesturesEnabledがスナップショットに反映される() {
        withStore { store, _ in
            store.preferences.gesturesEnabled = false
            store.savePreferences()
            #expect(store.gestureSnapshot().gesturesEnabled == false)

            store.preferences.gesturesEnabled = true
            store.savePreferences()
            #expect(store.gestureSnapshot().gesturesEnabled == true)
        }
    }

    @Test func pinchバインディングを持つ有効なプロファイルのbundleIDだけがpinchBoundに入る() {
        withStore { store, _ in
            store.profiles = [
                usablePinchProfile(bundleID: "com.usable.in", gesture: .pinchIn),
                usablePinchProfile(bundleID: "com.usable.out", gesture: .pinchOut),
                // 無効プロファイル
                AppProfile(bundleID: "com.disabled.profile", enabled: false,
                           bindings: [GestureBinding(gesture: .pinchIn, keyCode: 1)]),
                // 無効バインディング
                AppProfile(bundleID: "com.disabled.binding",
                           bindings: [GestureBinding(gesture: .pinchIn, keyCode: 1, enabled: false)]),
                // ショートカット未設定
                AppProfile(bundleID: "com.unset.shortcut",
                           bindings: [GestureBinding(gesture: .pinchIn, keyCode: nil)]),
                // pinch 以外（ホールドタップ）
                AppProfile(bundleID: "com.tip.tap",
                           bindings: [GestureBinding(gesture: .twoHoldTapLeft, keyCode: 1)]),
            ]
            store.saveProfiles()

            #expect(store.gestureSnapshot().pinchBoundBundleIDs == ["com.usable.in", "com.usable.out"])
        }
    }

    @Test func globalHasPinchBindingの真偽がスナップショットに反映される() {
        withStore { store, _ in
            // pinch バインディングなし
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .twoHoldTapLeft, keyCode: 1)])
            store.saveGlobalProfile()
            #expect(store.gestureSnapshot().globalHasPinchBinding == false)

            // 使用可能な pinch バインディングあり
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .pinchOut, keyCode: 1)])
            store.saveGlobalProfile()
            #expect(store.gestureSnapshot().globalHasPinchBinding == true)
        }
    }

    @Test func 無効なグローバルプロファイルはglobalHasPinchBindingがfalse() {
        withStore { store, _ in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                enabled: false,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 1)])
            store.saveGlobalProfile()
            #expect(store.gestureSnapshot().globalHasPinchBinding == false)
        }
    }

    @Test func save呼び出し後にスナップショットが更新される() {
        withStore { store, _ in
            // 初期状態は空
            #expect(store.gestureSnapshot().pinchBoundBundleIDs.isEmpty)

            store.profiles = [usablePinchProfile(bundleID: "com.example.app")]
            store.save()

            #expect(store.gestureSnapshot().pinchBoundBundleIDs == ["com.example.app"])
        }
    }

    // MARK: - 永続化 (round-trip)

    @Test func saveした内容を新しいインスタンスでloadすると復元される() {
        withStore { store, dir in
            store.globalProfile = AppProfile(
                bundleID: AppProfile.globalBundleID,
                bindings: [GestureBinding(gesture: .pinchIn, keyCode: 3)])
            store.profiles = [
                AppProfile(bundleID: "com.example.a",
                           bindings: [GestureBinding(gesture: .pinchOut, keyCode: 4)]),
                AppProfile(bundleID: "com.example.b", enabled: false),
            ]
            store.preferences.gesturesEnabled = false
            store.preferences.hudEnabled = false
            store.preferences.launchAtLogin = true
            store.save()

            let reloaded = ConfigStore(baseDirectory: dir)
            reloaded.load()

            #expect(reloaded.globalProfile.bindings.first?.keyCode == 3)
            #expect(reloaded.profiles.count == 2)
            #expect(reloaded.profiles.first?.bundleID == "com.example.a")
            #expect(reloaded.profiles.first?.bindings.first?.keyCode == 4)
            #expect(reloaded.profiles.last?.enabled == false)
            #expect(reloaded.preferences.gesturesEnabled == false)
            #expect(reloaded.preferences.hudEnabled == false)
            #expect(reloaded.preferences.launchAtLogin == true)
        }
    }

    @Test func 設定ファイルが存在しないディレクトリでloadしてもデフォルト値のまま() {
        withStore { store, _ in
            store.load()
            #expect(store.profiles.isEmpty)
            #expect(store.globalProfile.bundleID == AppProfile.globalBundleID)
            #expect(store.globalProfile.bindings.isEmpty)
            #expect(store.preferences == GlobalPreferences())
        }
    }

    @Test func 壊れたJSONがあってもloadはデフォルト値のままクラッシュしない() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let broken = Data("{ this is not valid json ".utf8)
            try broken.write(to: dir.appending(component: "config.json"))
            try broken.write(to: dir.appending(component: "preferences.json"))
            try broken.write(to: dir.appending(component: "global.json"))

            store.load()

            #expect(store.profiles.isEmpty)
            #expect(store.globalProfile.bundleID == AppProfile.globalBundleID)
            #expect(store.preferences == GlobalPreferences())
        }
    }
}
