import Foundation

// NSBundle のロケール解決は Locale.current（地域ロケール）を参照するため、
// 表示言語（AppleLanguages）が日本語でも英語リージョン設定だと en.lproj が
// 選ばれてしまう。Locale.preferredLanguages で lproj を直接選ぶことで回避する。
// Bundle 生成はアプリ起動中に変わらないためモジュールレベルでキャッシュする。
private let _localizedBundle: Bundle = {
    let lang = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
    // 同梱していない言語（ja/en 以外）は英語にフォールバックする
    let url = resourceBundle.url(forResource: lang, withExtension: "lproj")
           ?? resourceBundle.url(forResource: "en", withExtension: "lproj")
    return url.flatMap { Bundle(url: $0) } ?? resourceBundle
}()

func L(_ key: String) -> String {
    _localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
}
