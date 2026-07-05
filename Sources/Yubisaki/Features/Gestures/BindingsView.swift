import SwiftUI
import AppKit

struct BindingsView: View {
    @Binding var profile: AppProfile
    @State private var selectedBindingID: UUID?

    private var usedGestures: Set<GestureType> { Set(profile.bindings.map(\.gesture)) }

    /// 発火する順序（`ConfigStore.binding(for:gesture:)` は先勝ち）で、
    /// 既に先に有効なバインディングがあるために発火しないバインディングの id。
    /// Picker は新規の重複割り当てを防ぐが、config.json の手動編集等で
    /// 既存データに重複が紛れ込んだ場合はここで可視化する。
    private var shadowedBindingIDs: Set<UUID> {
        var seenGestures: Set<GestureType> = []
        var shadowed: Set<UUID> = []
        for binding in profile.bindings where binding.enabled && binding.keyCode != 0 {
            if seenGestures.contains(binding.gesture) {
                shadowed.insert(binding.id)
            } else {
                seenGestures.insert(binding.gesture)
            }
        }
        return shadowed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AppHeaderView(
                    bundleID: profile.bundleID,
                    isGlobalProfile: profile.bundleID == "global",
                    enabled: $profile.enabled
                )

                VStack(spacing: 0) {
                    ColumnHeaderRow()
                    Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                    if profile.bindings.isEmpty {
                        Text(L("gestures.noBindings"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach($profile.bindings) { $binding in
                            BindingRowView(
                                binding: $binding,
                                usedGestures: usedGestures,
                                isShadowed: shadowedBindingIDs.contains(binding.id),
                                isSelected: selectedBindingID == binding.id,
                                onSelect: { selectedBindingID = binding.id }
                            )
                            Color(nsColor: .separatorColor).frame(height: 0.5).padding(.horizontal, 16)
                        }
                    }
                }
                .opacity(profile.enabled ? 1.0 : 0.55)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator.opacity(0.6), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BindingsFooter(profile: $profile, selectedBindingID: $selectedBindingID)
                .padding(.horizontal, 8)
        }
    }
}

// MARK: - App Header

private struct AppHeaderView: View {
    let bundleID: String
    let isGlobalProfile: Bool
    @Binding var enabled: Bool

    private var toggleLabel: String {
        isGlobalProfile ? L("gestures.gesturesEnabled") : L("gestures.enabledForApp")
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleID: bundleID, size: 44, cornerRadius: 10)
            Text(AppDisplay.name(for: bundleID))
                .font(.headline)
            Spacer()
            Text(toggleLabel)
                .font(.callout)
            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Column Header Row

private struct ColumnHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 14, height: 1)
            Color.clear.frame(width: 14, height: 1)
            Color.clear.frame(width: 34, height: 1)
            Text(L("gestures.column.gesture"))
                .frame(width: 200, alignment: .leading)
            Text(L("gestures.column.shortcut"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption2.weight(.bold))
        .tracking(0.3)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 28)
    }
}

// MARK: - Binding Row

private struct BindingRowView: View {
    @Binding var binding: GestureBinding
    var usedGestures: Set<GestureType>
    var isShadowed: Bool
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $binding.enabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 14)

            Group {
                if isShadowed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help(L("gestures.conflict"))
                        .accessibilityLabel(L("gestures.conflict"))
                }
            }
            .frame(width: 14)

            // ジェスチャーアイコンは16px前後のメニュー行では潰れて視認できないため、
            // Picker内はテキストのみにし、選択中のジェスチャーだけを別枠で大きく表示する。
            templateIcon(named: binding.gesture.iconName, pointSize: 34)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)

            Picker("", selection: $binding.gesture) {
                ForEach(GestureGroup.allCases, id: \.self) { group in
                    Section(group.displayName) {
                        ForEach(
                            GestureType.allCases.filter { $0.group == group },
                            id: \.self
                        ) { gesture in
                            Text(gesture.displayName)
                                .tag(gesture)
                                .disabled(gesture != binding.gesture && usedGestures.contains(gesture))
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 178)

            KeyRecorderView(keyCode: $binding.keyCode, modifierFlags: $binding.modifierFlags)
                .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 28)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
    }
}

// MARK: - Bindings Footer

private struct BindingsFooter: View {
    @Binding var profile: AppProfile
    @Binding var selectedBindingID: UUID?

    private var allGesturesUsed: Bool {
        Set(profile.bindings.map(\.gesture)).count >= GestureType.allCases.count
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: addBinding) { Image(systemName: "plus") }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(allGesturesUsed)
                .accessibilityLabel(L("gestures.addBinding"))

            Button(action: deleteSelected) { Image(systemName: "minus") }
                .buttonStyle(.plain)
                .padding(6)
                .disabled(selectedBindingID == nil)
                .accessibilityLabel(L("gestures.deleteBinding"))

            Spacer()
        }
        .padding(.leading, 8)
        .frame(height: 36)
    }

    private func addBinding() {
        let used = Set(profile.bindings.map(\.gesture))
        guard let gesture = GestureType.allCases.first(where: { !used.contains($0) }) else { return }
        let newBinding = GestureBinding(gesture: gesture, enabled: false)
        profile.bindings.append(newBinding)
        selectedBindingID = newBinding.id
    }

    private func deleteSelected() {
        guard let id = selectedBindingID else { return }
        profile.bindings.removeAll { $0.id == id }
        selectedBindingID = nil
    }
}
