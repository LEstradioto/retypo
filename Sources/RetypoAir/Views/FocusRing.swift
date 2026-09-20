import SwiftUI

@MainActor
final class SettingsFocusCoordinator: ObservableObject {
    @Published var focusedID: String?
    private var order: [String] = []
    private var actions: [String: () -> Bool] = [:]

    func setOrder(_ ids: [String]) {
        var seen = Set<String>()
        order = ids.filter { seen.insert($0).inserted }
        if let focusedID, order.contains(focusedID) {
            return
        }
        focusedID = order.first
    }

    func focusFirst() {
        focusedID = order.first
    }

    // Programmatic focus for the modes/shortcut editors (header
    // popover); focusFirst/advance cover the rest.
    // periphery:ignore
    func focus(_ id: String) {
        if order.contains(id) {
            focusedID = id
        }
    }

    func advance(reverse: Bool) {
        guard !order.isEmpty else { return }
        guard let focusedID, let index = order.firstIndex(of: focusedID) else {
            self.focusedID = reverse ? order.last : order.first
            return
        }
        let delta = reverse ? -1 : 1
        self.focusedID = order[(index + delta + order.count) % order.count]
    }

    func registerAction(_ id: String, action: @escaping () -> Bool) {
        actions[id] = action
    }

    func unregisterAction(_ id: String) {
        actions[id] = nil
    }

    func activateFocused() -> Bool {
        guard let focusedID, let action = actions[focusedID] else { return false }
        return action()
    }
}

struct SettingsFocusStyle: ViewModifier {
    @EnvironmentObject private var coordinator: SettingsFocusCoordinator
    @FocusState private var isNativeFocused: Bool
    var id: String
    var radius: CGFloat = 8
    var keyboardFocusable: Bool = false
    var activate: (() -> Bool)?

    private var isVisuallyFocused: Bool {
        coordinator.focusedID == id || isNativeFocused
    }

    func body(content: Content) -> some View {
        let view = content
            .id(id)
            .focused($isNativeFocused)
            .onAppear(perform: handleAppear)
            .onDisappear { coordinator.unregisterAction(id) }
            .onChange(of: coordinator.focusedID, perform: handleFocusedIDChange)
            .onChange(of: isNativeFocused, perform: handleNativeFocusChange)
            .overlay(focusOverlay)

        if keyboardFocusable { view.focusable(true) } else { view }
    }

    private var focusOverlay: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(isVisuallyFocused ? Color.retypoAccent : Color.clear, lineWidth: 1.6)
    }

    private func handleAppear() {
        isNativeFocused = coordinator.focusedID == id
        if let activate { coordinator.registerAction(id, action: activate) }
    }

    private func handleFocusedIDChange(_ nextID: String?) {
        isNativeFocused = nextID == id
        if nextID == id, let activate {
            coordinator.registerAction(id, action: activate)
        }
    }

    private func handleNativeFocusChange(_ focused: Bool) {
        if focused, coordinator.focusedID != id {
            coordinator.focusedID = id
        }
    }
}

extension View {
    func settingsFocus(_ id: String, radius: CGFloat = 8, keyboardFocusable: Bool = false, activate: (() -> Bool)? = nil) -> some View {
        modifier(SettingsFocusStyle(id: id, radius: radius, keyboardFocusable: keyboardFocusable, activate: activate))
    }
}
