import AppKit

enum ClipboardService {
    struct Snapshot {
        struct Item {
            var values: [(NSPasteboard.PasteboardType, Data)]
        }

        var items: [Item]
        var string: String?
    }

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func snapshot() -> Snapshot {
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems?.map { item in
            Snapshot.Item(values: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        } ?? []
        return Snapshot(items: items, string: pasteboard.string(forType: .string))
    }

    static func restore(_ snapshot: Snapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            if let string = snapshot.string {
                pasteboard.setString(string, forType: .string)
            }
            return
        }
        let restoredItems = snapshot.items.map { item -> NSPasteboardItem in
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in item.values {
                pasteboardItem.setData(data, forType: type)
            }
            return pasteboardItem
        }
        pasteboard.writeObjects(restoredItems)
    }
}
