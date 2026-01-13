import Carbon
import Foundation

struct HotKeyDefinition {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
}

final class HotKeyManager {
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private let handler: (UInt32) -> Void

    init(definitions: [HotKeyDefinition], handler: @escaping (UInt32) -> Void) {
        self.handler = handler

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                manager.handler(hotKeyID.id)
            }

            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, userData, &handlerRef)

        for def in definitions {
            var ref: EventHotKeyRef?
            var hotKeyID = EventHotKeyID(signature: OSType(0x54524E53), id: def.id) // 'TRNS'
            RegisterEventHotKey(def.keyCode, def.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if let ref {
                hotKeyRefs.append(ref)
            }
        }
    }

    deinit {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
