import SwiftUI

/// 設定パネル等で使う角丸カード装飾（背景色・角丸クリップ・境界線）。
/// `BindingsView` のバインディング一覧コンテナと `GeneralSettingsView.FormGroupView` で
/// 見た目が重複していたため共通化した。
private struct FormCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator.opacity(0.6), lineWidth: 0.5)
            )
    }
}

extension View {
    /// 角丸カード装飾（背景色・角丸クリップ・境界線）を適用する。
    func formCardStyle() -> some View {
        modifier(FormCardStyle())
    }
}

/// カード内の行と行を区切る水平セパレータ。
struct FormRowDivider: View {
    var body: some View {
        Color(nsColor: .separatorColor)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}
