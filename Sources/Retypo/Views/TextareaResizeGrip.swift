import AppKit
import SwiftUI

/// The bottom-right drag handle of a textarea: drag down for a taller box,
/// up for a shorter one. `height` changes live; `commit` gets the final
/// value once, on release.
struct TextareaResizeGrip: View {
    @Binding var height: CGFloat
    let range: ClosedRange<CGFloat>
    let commit: (CGFloat) -> Void
    @State private var origin: TextareaResize.Origin?

    var body: some View {
        GripLines()
            .stroke(Palette.tertiaryText, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .frame(width: 9, height: 9)
            .padding(4)
            .contentShape(Rectangle())
            .onHover { inside in inside ? NSCursor.resizeUpDown.push() : NSCursor.pop() }
            .gesture(drag)
            .help("Drag to resize")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                let mouseY = NSEvent.mouseLocation.y
                let start = origin ?? TextareaResize.Origin(height: height, mouseY: mouseY)
                origin = start
                height = TextareaResize.height(from: start, mouseY: mouseY, range: range)
            }
            .onEnded { _ in
                origin = nil
                commit(height)
            }
    }
}

/// Drag math for `TextareaResizeGrip`, kept apart so it can be tested.
///
/// It reads the screen-space mouse position instead of the gesture's
/// translation: the panel may grow while the user drags, which moves the
/// view's own coordinate space under the pointer.
enum TextareaResize {
    struct Origin: Equatable {
        let height: CGFloat
        let mouseY: CGFloat
    }

    /// Screen y grows upward, so moving the mouse down makes the box taller.
    static func height(from origin: Origin, mouseY: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        let proposed = origin.height + (origin.mouseY - mouseY)
        return min(max(proposed, range.lowerBound), range.upperBound)
    }
}

/// Two diagonal strokes, the familiar corner mark of a resizable textarea.
private struct GripLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
