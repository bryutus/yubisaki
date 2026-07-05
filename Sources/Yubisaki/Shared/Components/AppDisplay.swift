import AppKit
import SwiftUI

/// bundleID からアプリの表示名・アイコンを解決する。NSWorkspace の解決結果はメイン上でキャッシュ
/// する（body 評価ごとの再解決を避ける）。"global" は特別扱いし、yubisaki自身のアプリアイコンを表示する。
@MainActor
enum AppDisplay {
    static let globalBundleID = "global"

    private static var urlCache: [String: URL?] = [:]
    private static var iconCache: [String: NSImage] = [:]

    static func name(for bundleID: String) -> String {
        if bundleID == globalBundleID { return L("sidebar.allApps") }
        return url(for: bundleID)?.deletingPathExtension().lastPathComponent ?? bundleID
    }

    static func icon(for bundleID: String) -> NSImage? {
        if bundleID == globalBundleID { return appIcon }
        if let cached = iconCache[bundleID] { return cached }
        guard let url = url(for: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = icon
        return icon
    }

    /// 「すべてのアプリ」行にはyubisaki自身のアプリアイコンを表示する
    private static let appIcon: NSImage? = {
        guard let url = resourceBundle.url(forResource: "AppIcon", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private static func url(for bundleID: String) -> URL? {
        if let cached = urlCache[bundleID] { return cached }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        urlCache[bundleID] = url
        return url
    }
}

/// アプリアイコン。"global" はyubisaki自身のアイコン、解決できない場合はプレースホルダを表示する。
/// サイドバー行と詳細ヘッダーで共用する。
struct AppIconView: View {
    let bundleID: String
    var size: CGFloat = 20
    var cornerRadius: CGFloat = 4

    var body: some View {
        if let icon = AppDisplay.icon(for: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.quaternary)
                    .frame(width: size, height: size)
                Image(systemName: "hand.draw")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
