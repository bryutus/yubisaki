import SwiftUI
import AppKit

/// ジェスチャー検出時に表示するHUDの中身。
struct HUDView: View {
    let icon: Image
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 12) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(HUDVisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .fixedSize()
    }
}

/// macOS標準の音量/輝度HUDと同じ `.hudWindow` マテリアルをSwiftUIから使うためのラッパー。
private struct HUDVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
