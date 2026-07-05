import SwiftUI
import AppKit

/// リソースバンドル内のPNG（`scripts/make-gesture-icons.swift` 生成）をテンプレート画像として読み込む。
/// `Image(_:bundle:)` はアセットカタログ前提の解決ルールを持つため、
/// アセットカタログ化していない単体PNGはファイルパスから明示的に解決する。
/// SwiftPM は `Resources/Icons/*.png` をバンドル直下にフラット展開するため subdirectory は指定しない。
///
/// - Parameter pointSize: 表示サイズ。元画像は256x256pxで書き出しているため、
///   `NSImage.size` をここで明示的に指定しないと等倍(256pt)のまま扱われる。
///   `MenuBarExtra` は SwiftUI の `.frame()` を経由せず NSImage を直接使うため、
///   SwiftUI側の frame 指定だけでは縮小されない（メニューバーで巨大表示された原因）。
func templateIcon(named name: String, pointSize: CGFloat) -> Image {
    guard let url = resourceBundle.url(forResource: name, withExtension: "png"),
          let nsImage = NSImage(contentsOf: url)
    else {
        return Image(systemName: "questionmark")
    }
    nsImage.size = NSSize(width: pointSize, height: pointSize)
    nsImage.isTemplate = true
    return Image(nsImage: nsImage).renderingMode(.template)
}
