import Foundation

// SwiftPM が生成する Bundle.module は Bundle.main.bundleURL 直下（.app なら Contents/ の
// 外側）を探すため、正式な .app バンドル（配布物）では見つからずコード署名も崩れる。
// 配布用 .app では Contents/Resources 配下（署名可能な標準の場所）に置いた同名バンドルを
// 優先し、`swift run` 等の開発時は Bundle.module にフォールバックする。
// ローカライズ文字列・アイコン画像など、パッケージリソース全般の解決に使う。
let resourceBundle: Bundle = {
    if let url = Bundle.main.resourceURL?.appendingPathComponent("yubisaki_Yubisaki.bundle"),
       let bundle = Bundle(url: url) {
        return bundle
    }
    return Bundle.module
}()
