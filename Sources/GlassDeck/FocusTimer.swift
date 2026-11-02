import AppKit

/// A countdown that survives the panel being closed.
///
/// Every other tab in the deck flips something and forgets about it. Focus is
/// the first control with a *duration*, which means the state has to live
/// somewhere that outlives the view: the popover closes, the tab switches, the
/// window goes behind something else — the session keeps running and the menu
/// bar keeps counting.
///
/// Remaining time is derived from a wall-clock `deadline`, never accumulated
/// from tick callbacks. A tick can be late, coalesced or skipped entirely while
/// the Mac sleeps; a deadline cannot drift.
final class FocusTimer {

    static let shared = FocusTimer()

    /// Posted on every tick and every phase change. Carries the whole state, so
    /// observers never have to ask a second question.
    static let changed = Notification.Name("GlassDeckFocusChanged")
    /// Posted once, when the deadline is reached.
    static let finished = Notification.Name("GlassDeckFocusFinished")

    enum Phase: String {
        case idle, running, paused, finished
    }

    /// The lengths worth offering. Four chips fit on one row; anything more is
    /// a settings screen nobody asked for.
    static let durations = [15, 25, 45, 60]

    private static let durationKey = "GlassDeck.focusMinutes"

    private(set) var phase: Phase = .idle
    /// The length of the session in seconds, as chosen by the user.
    private(set) var duration: TimeInterval = 25 * 60
    /// Seconds left, recomputed from `deadline` on every read.
    private(set) var remaining: TimeInterval = 25 * 60

    private var timer: Timer?
    /// Absolute moment the session ends. The single source of truth while
    /// running; `nil` when paused or idle.
    private var deadline: Date?

    private init() {
        let stored = UserDefaults.standard.integer(forKey: Self.durationKey)
        let minutes = Self.durations.contains(stored) ? stored : 25
        duration = TimeInterval(minutes * 60)
        remaining = duration
    }

    // MARK: - Derived values

    var minutes: Int { Int((duration / 60).rounded()) }

    /// 0…1, how much of the session is behind us. Drives the ring.
    var progress: Double {
        guard duration > 0 else { return 0 }
        let done = duration - remaining
        return min(max(done / duration, 0), 1)
    }

    var isActive: Bool { phase == .running || phase == .paused }

    /// "24:59" — always two digits, so the menu bar does not jitter when the
    /// minutes drop from 10 to 9.
    var remainingText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Controls

    /// Pick a length. Only legal when nothing is in flight: silently resizing a
    /// running session would be a great way to make someone miss a meeting.
    @discardableResult
    func setDuration(minutes: Int) -> Bool {
        guard !isActive, Self.durations.contains(minutes) else { return false }
        duration = TimeInterval(minutes * 60)
        remaining = duration
        phase = .idle
        UserDefaults.standard.set(minutes, forKey: Self.durationKey)
        postChanged()
        return true
    }

    /// Start from scratch, or resume a paused session.
    func start() {
        if phase == .paused {
            // Resume from what is left, not from the top.
            deadline = Date().addingTimeInterval(remaining)
        } else {
            remaining = duration
            deadline = Date().addingTimeInterval(duration)
        }
        phase = .running
        schedule()
        postChanged()
    }

    func pause() {
        guard phase == .running else { return }
        remaining = max(0, deadline?.timeIntervalSinceNow ?? remaining)
        deadline = nil
        stopTimer()
        phase = .paused
        postChanged()
    }

    /// Pause if running, resume if paused. What the big button does.
    func toggle() {
        switch phase {
        case .running: pause()
        case .paused: start()
        case .idle, .finished: start()
        }
    }

    /// Back to the top of the chosen length, not running.
    func reset() {
        stopTimer()
        deadline = nil
        phase = .idle
        remaining = duration
        postChanged()
    }

    // MARK: - Ticking

    private func schedule() {
        stopTimer()
        // Half-second ticks: the label only prints whole seconds, but the extra
        // resolution keeps the ring from visibly stepping.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common so the countdown keeps going while a menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard phase == .running, let deadline = deadline else { return }
        let left = deadline.timeIntervalSinceNow
        if left <= 0 {
            finish()
            return
        }
        // Only republish when the displayed second actually changes: the label
        // prints whole seconds, so a 0.5 s tick would redraw the menu bar twice
        // as often as anything on screen actually moves.
        let before = Int(remaining.rounded(.up))
        remaining = left
        if Int(left.rounded(.up)) != before {
            postChanged()
        }
    }

    private func finish() {
        stopTimer()
        deadline = nil
        remaining = 0
        phase = .finished
        postChanged()

        // Three cheap signals, because a silent timer is a timer people ignore:
        // a chime, a Dock bounce, and a notification the deck can show.
        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.informationalRequest)
        NotificationCenter.default.post(name: Self.finished, object: nil)
    }

    private func postChanged() {
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    #if DEBUG
    /// Layout-harness hook: pretend `seconds` have already elapsed, so a
    /// screenshot can show a partly eaten ring without waiting 8 minutes.
    /// Compiled out of release builds.
    func debugFastForward(seconds: TimeInterval) {
        guard phase == .running, let deadline = deadline else { return }
        self.deadline = deadline.addingTimeInterval(-seconds)
        tick()
    }
    #endif
}

// MARK: - Ring

/// The countdown as a ring: a track, an arc that eats it, and the time in the
/// middle. Hand-drawn because an NSProgressIndicator is a bar and a bar next to
/// a big number looks like a download.
final class FocusRingView: NSView {

    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    /// Big centre line: "24:59".
    var timeText: String = "25:00" {
        didSet { timeLabel.stringValue = timeText }
    }

    /// Small line under the time: "Focusing" / "Paused" / "Done".
    var caption: String = "" {
        didSet { captionLabel.stringValue = caption }
    }

    /// Accent of the arc. Dims while paused so the state is readable at a
    /// glance without reading the caption.
    var isPaused: Bool = false {
        didSet { needsDisplay = true }
    }

    private let timeLabel = NSTextField(labelWithString: "25:00")
    private let captionLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timeLabel.textColor = .labelColor
        timeLabel.alignment = .center

        captionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.alignment = .center

        let column = NSStackView(views: [timeLabel, captionLabel])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 0
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            column.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 168, height: 168)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let lineWidth: CGFloat = 9
        let inset = lineWidth / 2 + 1
        let side = min(bounds.width, bounds.height) - inset * 2
        guard side > 20 else { return }

        let rect = NSRect(x: bounds.midX - side / 2,
                          y: bounds.midY - side / 2,
                          width: side,
                          height: side)

        // Track
        let track = NSBezierPath(ovalIn: rect)
        track.lineWidth = lineWidth
        NSColor.secondaryLabelColor.withAlphaComponent(0.14).setStroke()
        track.stroke()

        // Progress arc, clockwise from twelve o'clock.
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return }

        let arc = NSBezierPath()
        let start = 90.0
        let end = 90.0 - 360.0 * clamped
        arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY),
                      radius: side / 2,
                      startAngle: CGFloat(start),
                      endAngle: CGFloat(end),
                      clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round

        let accent = isPaused ? NSColor.systemOrange : NSColor.controlAccentColor
        accent.setStroke()
        arc.stroke()
    }
}
