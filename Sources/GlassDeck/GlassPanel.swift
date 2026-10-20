import AppKit

/// A Liquid Glass surface.
///
/// On macOS 26+ this wraps the native `NSGlassEffectView` (true Liquid Glass —
/// refractive, self-lit rim, live background sampling). On earlier systems it
/// falls back to a frosted `NSVisualEffectView` so the app still looks clean.
///
/// Put your content into `contentView`, NOT directly onto this view — that is
/// the only place guaranteed to sit inside the glass layer.
final class GlassPanel: NSView {

    /// The container to add your subviews to.
    let contentView: NSView

    private let backing: NSView

    /// Optional tint applied to the glass.
    var tintColor: NSColor? {
        didSet { applyTint() }
    }

    /// The glass corner radius.
    var glassCornerRadius: CGFloat = 24 {
        didSet { applyCornerRadius() }
    }

    init() {
        contentView = NSView()

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 24
            backing = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 24
            effect.layer?.masksToBounds = true
            backing = effect
        }

        super.init(frame: .zero)

        addSubview(backing)
        backing.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *), let glass = backing as? NSGlassEffectView {
            glass.contentView = contentView
        } else {
            backing.addSubview(contentView)
            contentView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: backing.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: backing.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: backing.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: backing.bottomAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            backing.leadingAnchor.constraint(equalTo: leadingAnchor),
            backing.trailingAnchor.constraint(equalTo: trailingAnchor),
            backing.topAnchor.constraint(equalTo: topAnchor),
            backing.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyTint() {
        if #available(macOS 26.0, *), let glass = backing as? NSGlassEffectView {
            glass.tintColor = tintColor
        }
    }

    private func applyCornerRadius() {
        if #available(macOS 26.0, *), let glass = backing as? NSGlassEffectView {
            glass.cornerRadius = glassCornerRadius
        } else {
            backing.layer?.cornerRadius = glassCornerRadius
        }
    }

    // MARK: - Glass Hover / Press Animation

    /// A subtle overlay that brightens on hover and dims on press, giving the
    /// capsule a tactile, "liquid" feel without breaking the glass aesthetic.
    private var hoverOverlay: NSView?
    private var hoverSheen: CAGradientLayer?

    /// A slow, looping light sweep across the panel. Subtle enough to read as
    /// the glass catching ambient light, not as a loading animation. Call this
    /// on the one big surface (the deck itself), not on every capsule.
    func startAmbientSheen() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = glassCornerRadius
        let sweep = CAGradientLayer()
        sweep.colors = [
            NSColor.clear.cgColor,
            NSColor.white.withAlphaComponent(0.055).cgColor,
            NSColor.clear.cgColor,
        ]
        sweep.startPoint = CGPoint(x: 0, y: 0)
        sweep.endPoint = CGPoint(x: 1, y: 1)
        sweep.locations = [-0.7, -0.4, -0.1]
        sweep.frame = bounds
        layer?.addSublayer(sweep)

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.7, -0.4, -0.1]
        anim.toValue = [1.1, 1.4, 1.7]
        anim.duration = 9
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweep.add(anim, forKey: "ambientSheen")
        ambientSheen = sweep
    }

    private var ambientSheen: CAGradientLayer?

    override func layout() {
        super.layout()
        ambientSheen?.frame = bounds
        hoverSheen?.frame = hoverOverlay?.bounds ?? .zero
    }

    /// Attach a hover-highlight + press-scale animation to this glass capsule.
    func addGlassHoverAnimation() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = glassCornerRadius

        // Transparent highlight overlay that fades in on hover. It sits above
        // the content but must NOT intercept clicks — so it ignores hit testing.
        let overlay = PassThroughView()
        overlay.wantsLayer = true
        let sheen = CAGradientLayer()
        sheen.colors = [
            NSColor.white.withAlphaComponent(0.16).cgColor,
            NSColor.white.withAlphaComponent(0.04).cgColor,
            NSColor.clear.cgColor,
        ]
        sheen.locations = [0, 0.55, 1]
        sheen.startPoint = CGPoint(x: 0, y: 1)
        sheen.endPoint = CGPoint(x: 1, y: 0)
        overlay.layer?.addSublayer(sheen)
        self.hoverSheen = sheen
        overlay.layer?.opacity = 0
        overlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlay)
        contentView.addConstraints([
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        hoverOverlay = overlay

        // The gradient layer needs an explicit frame; keep it in sync.
        DispatchQueue.main.async { [weak overlay] in
            guard let overlay = overlay else { return }
            overlay.layoutSubtreeIfNeeded()
            sheen.frame = overlay.bounds
        }

        // Tracking area for hover enter/exit.
        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    public override func mouseEntered(with event: NSEvent) {
        animateOverlay(to: 1.0)
    }

    public override func mouseExited(with event: NSEvent) {
        animateOverlay(to: 0.0)
    }

    private func animateOverlay(to opacity: Float) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            hoverOverlay?.layer?.opacity = opacity
        }
    }
}

/// A view that ignores mouse events entirely, letting clicks pass through to
/// whatever sits beneath it. Used for hover overlays.
final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
