import Foundation

// NSBundle のロケール解決は Locale.current（地域ロケール）を参照するため、
// 表示言語（AppleLanguages）が日本語でも英語リージョン設定だと en.lproj が
// 選ばれてしまう。Locale.preferredLanguages で lproj を直接選ぶことで回避する。
func L(_ key: String) -> String {
    let lang = Locale.preferredLanguages.first
        .map { String($0.prefix(2)) } ?? "ja"
    let url = Bundle.module.url(forResource: lang, withExtension: "lproj")
           ?? Bundle.module.url(forResource: "ja", withExtension: "lproj")
    let bundle = url.flatMap { Bundle(url: $0) } ?? Bundle.module
    return bundle.localizedString(forKey: key, value: key, table: "Localizable")
}
