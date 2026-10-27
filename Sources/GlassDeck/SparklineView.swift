import AppKit

/// A tiny self-scrolling line chart.
///
/// A ring buffer of normalized 0...1 samples drawn as a stroked line with a
/// soft gradient underneath. No dependencies, no timers: the caller decides how
/// often to push, and the view just redraws.
final class SparklineView: NSView {

    private let capacity: Int
    private(set) var samples: [Double] = []

    var accentColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    /// Floor for the vertical scale, so a nearly idle machine draws a low
    /// gentle line instead of an amplified flat-line-turned-seismograph.
    var minimumScale: Double = 0.04

    init(capacity: Int = 60) {
        self.capacity = capacity
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    func push(_ value: Double) {
        samples.append(max(0, min(1, value)))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        needsDisplay = true
    }

    func reset() {
        samples.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard samples.count > 1 else { return }

        let rect = bounds.insetBy(dx: 1.5, dy: 1.5)
        guard rect.width > 2, rect.height > 2 else { return }

        let scale = max(samples.max() ?? 0, minimumScale)
        let step = rect.width / CGFloat(max(capacity - 1, 1))
        let startX = rect.maxX - CGFloat(samples.count - 1) * step

        func point(_ index: Int) -> NSPoint {
            let x = startX + CGFloat(index) * step
            let raw = rect.minY + CGFloat(samples[index] / scale) * rect.height
            return NSPoint(x: x, y: min(raw, rect.maxY))
        }

        let line = NSBezierPath()
        line.lineWidth = 1.6
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        line.move(to: point(0))
        for index in 1..<samples.count {
            line.line(to: point(index))
        }

        // Fill first so the stroke sits on top of the gradient edge.
        if let area = line.copy() as? NSBezierPath {
            area.line(to: NSPoint(x: point(samples.count - 1).x, y: rect.minY))
            area.line(to: NSPoint(x: point(0).x, y: rect.minY))
            area.close()
            if let gradient = NSGradient(
                colors: [accentColor.withAlphaComponent(0.24),
                         accentColor.withAlphaComponent(0.0)]
            ) {
                gradient.draw(in: area, angle: -90)
            }
        }

        accentColor.setStroke()
        line.stroke()
    }
}
