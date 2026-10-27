import AppKit

struct PanelFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var nsRect: NSRect { NSRect(x: x, y: y, width: width, height: height) }

    init(x: Double = 420, y: Double = 260, width: Double = 760, height: Double = 500) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: NSRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}
