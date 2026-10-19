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
}
