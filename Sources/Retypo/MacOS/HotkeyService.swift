import AppKit
import Carbon

final class HotkeyService {
    enum Action {
        case togglePanel
    }

    private let handler: (Action) -> Void
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    init(handler: @escaping (Action) -> Void) {
        self.handler = handler
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            guard let action = HotkeyService.action(from: event) else { return noErr }
            DebugLog.log("hotkey fired action=\(action)")
            service.handler(action)
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)

        let signature = OSType(UInt32(ascii: "RTYP"))
        register(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey), id: 1, signature: signature)
    }

    deinit {
        for hotKeyRef in hotKeyRefs { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, signature: OSType) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
        }
        DebugLog.log("hotkey register id=\(id) keyCode=\(keyCode) modifiers=\(modifiers) status=\(status)")
    }

    private static func action(from event: EventRef?) -> Action? {
        guard let event else { return nil }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return nil }
        return hotKeyID.id == 1 ? .togglePanel : nil
    }
}

private extension UInt32 {
    init(ascii string: String) {
        self = string.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
