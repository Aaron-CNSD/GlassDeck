import AppKit

// MARK: - Model

/// One runnable entry in the command palette.
///
/// The palette is not a second UI for the deck — it is the same commands,
/// flattened into a single list so a keyboard can reach a switch that lives
/// two tabs away without a mouse.
struct PaletteItem {

    enum Group {
        case toggle, action, jump

        var tint: NSColor {
            switch self {
            case .toggle: return .controlAccentColor
            case .action: return .systemOrange
            case .jump: return .systemTeal
            }
        }
    }

    let id: String
    let title: String
    /// Short note shown next to the title: the group, plus live state for a switch.
    let detail: String
    let symbol: String
    let group: Group
    /// Extra search words: the English id and the synonyms someone might type
    /// in a language the panel is not currently displayed in.
    let keywords: [String]
    let perform: () -> Void
}

// MARK: - Ranking

/// The search behind the palette.
///
/// Deliberately boring and predictable: an exact title beats a prefix, a
/// prefix beats a word prefix, a word prefix beats a substring, and a keyword
/// hit beats a loose subsequence. Ties break on the shorter title, because the
/// shorter title is the more specific command.
enum PaletteRanker {

    /// Fold case, diacritics and full-width forms so "ＤＡＲＫ" and "dark" agree.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Score one item against an already-normalized query. 0 means "no match".
    static func score(_ item: PaletteItem, query q: String) -> Int {
        guard !q.isEmpty else { return 1 }

        let title = normalize(item.title)
        if title == q { return 1000 }
        if title.hasPrefix(q) { return 900 }

        let words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.contains(where: { $0.hasPrefix(q) }) { return 780 }
        if title.contains(q) { return 640 }

        // Initials: "dm" reaches "Dark Mode", "et" reaches "Empty Trash".
        let initials = words.compactMap { $0.first.map(String.init) }.joined()
        if initials.count >= 2, initials.hasPrefix(q) { return 560 }

        for keyword in item.keywords {
            let word = normalize(keyword)
            if word == q { return 520 }
            if word.hasPrefix(q) { return 460 }
            if word.contains(q) { return 340 }
        }

        // The right-hand note is part of the text on screen, so it counts too:
        // typing "动作" or "action" lists every action.
        if normalize(item.detail).contains(q) { return 240 }
        if isSubsequence(q, of: title) { return 140 }
        return 0
    }

    /// Filter and sort `items`. An empty query keeps the caller's order and
    /// every item, so an empty search box is a browsable menu rather than a
    /// blank stare.
    static func rank(_ items: [PaletteItem], query: String, limit: Int) -> [PaletteItem] {
        let q = normalize(query)
        guard !q.isEmpty else { return items }

        let scored: [(item: PaletteItem, score: Int)] = items.compactMap { item in
            let value = score(item, query: q)
            return value > 0 ? (item, value) : nil
        }

        let ordered = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.item.title.count != rhs.item.title.count {
                return lhs.item.title.count < rhs.item.title.count
            }
            return lhs.item.title < rhs.item.title
        }

        return ordered.prefix(limit).map { $0.item }
    }

    /// True when every character of `needle` appears in `haystack`, in order.
    static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        let hay = Array(haystack)
        var cursor = 0
        for character in needle {
            var matched = false
            while cursor < hay.count {
                let candidate = hay[cursor]
                cursor += 1
                if candidate == character { matched = true; break }
            }
            if !matched { return false }
        }
        return true
    }
}

// MARK: - Synonyms

/// Words the UI itself never prints.
///
/// Glass Deck ships in five languages but people type in whichever one they
/// think in, and they think in the English name of the macOS setting half the
/// time. The switch id already carries that name; this adds the rest.
enum PaletteAliases {

    static func words(forToggle id: String) -> [String] {
        switch id {
        case "darkmode":
            return ["dark", "dark mode", "theme", "appearance", "night", "深色", "外观"]
        case "hiddenfiles":
            return ["hidden files", "dotfiles", "隐藏文件", "dot"]
        case "pathbar":
            return ["path bar", "path", "breadcrumb", "路径栏"]
        case "desktopicons":
            return ["desktop icons", "desktop", "桌面图标", "clean desktop"]
        case "keepawake":
            return ["awake", "caffeine", "sleep", "keep awake", "insomnia", "防休眠", "常亮"]
        case "mute":
            return ["mute", "volume", "silent", "audio", "静音", "音量"]
        case "autohidedock":
            return ["dock", "auto hide", "自动隐藏", "程序坞"]
        case "menubar":
            return ["menu bar", "menubar", "菜单栏", "menu"]
        case "scroll":
            return ["scroll", "scrolling", "natural", "滚动", "自然滚动"]
        case "statusbar":
            return ["status bar", "statusbar", "状态栏"]
        case "extensions":
            return ["extensions", "file extension", "后缀", "扩展名"]
        default:
            return []
        }
    }
}

// MARK: - Palette view

/// The ⌘K overlay: one search field, one ranked list, keyboard first.
///
/// Everything about it is deliberately quiet — no tabs, no filters, no chips.
/// Type three letters, press return, done. The list is rebuilt from the live
/// command set on every open, so a switch says "On" only if it really is.
final class CommandPaletteView: NSView {

    /// Called after the palette hides itself, so the deck can tidy up behind it.
    var onDismiss: (() -> Void)?

    private(set) var searchField = NSSearchField()

    private let card = NSView()
    private let iconView = NSImageView()
    private let listStack = NSStackView()
    private let scroll = NSScrollView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")

    private var allItems: [PaletteItem] = []
    private var shown: [PaletteItem] = []
    private var rows: [PaletteRowView] = []
    private var selection = 0

    /// How many matches a typed query shows before it asks for one more character.
    private let resultLimit = 8

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        build()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("CommandPaletteView is created in code only")
    }

    // MARK: Construction

    private func build() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 18
        card.layer?.cornerCurve = .continuous
        card.layer?.masksToBounds = true
        // Opaque on purpose: the panel behind it is glass, and a search field
        // you have to read through two layers of transparency is a toy.
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.22
        card.layer?.shadowRadius = 24
        card.layer?.shadowOffset = CGSize(width: 0, height: -8)
        addSubview(card)

        iconView.image = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = L.t(.palettePlaceholder)
        searchField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.target = self
        searchField.action = #selector(queryChanged(_:))

        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor

        listStack.orientation = .vertical
        listStack.spacing = 2
        listStack.alignment = .leading
        listStack.translatesAutoresizingMaskIntoConstraints = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(listStack)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.stringValue = L.t(.paletteHint)

        // An opaque footer: the list scrolls underneath it, and half a row
        // peeking out from under the hint reads as a rendering bug.
        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.wantsLayer = true
        footer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let footerDivider = NSView()
        footerDivider.translatesAutoresizingMaskIntoConstraints = false
        footerDivider.wantsLayer = true
        footerDivider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor

        footer.addSubview(footerDivider)
        footer.addSubview(hintLabel)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.stringValue = L.t(.paletteEmpty)
        emptyLabel.isHidden = true

        [iconView, searchField, divider, scroll, footer, emptyLabel].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 52),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -44),
            card.heightAnchor.constraint(equalToConstant: 336),
            card.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -76),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            searchField.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),

            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            divider.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            divider.heightAnchor.constraint(equalToConstant: 1),

            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -2),

            footer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 28),

            footerDivider.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            footerDivider.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            footerDivider.topAnchor.constraint(equalTo: footer.topAnchor),
            footerDivider.heightAnchor.constraint(equalToConstant: 1),

            hintLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 14),
            hintLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),

            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scroll.widthAnchor, constant: -20),

            listStack.topAnchor.constraint(equalTo: doc.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            listStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        setAccessibilityLabel(L.t(.paletteTitle))
    }

    // MARK: Presentation

    /// Show the palette with a freshly built command list.
    func present(items: [PaletteItem], query: String = "") {
        allItems = items
        searchField.stringValue = query
        searchField.placeholderString = L.t(.palettePlaceholder)
        hintLabel.stringValue = L.t(.paletteHint)
        emptyLabel.stringValue = L.t(.paletteEmpty)
        selection = 0
        shown = query.isEmpty
            ? items
            : PaletteRanker.rank(items, query: query, limit: resultLimit)
        rebuildRows()
        isHidden = false
    }

    func focusSearch() {
        window?.makeFirstResponder(searchField)
    }

    func close() {
        guard !isHidden else { return }
        isHidden = true
        window?.makeFirstResponder(nil)
        onDismiss?()
    }

    // MARK: Behaviour

    @objc private func queryChanged(_ sender: NSSearchField) {
        shown = PaletteRanker.rank(allItems, query: sender.stringValue, limit: resultLimit)
        selection = 0
        rebuildRows()
    }

    /// Keys the palette claims while it is open. Anything else (letters, ⌘A…)
    /// falls through to the search field.
    func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:                    // esc
            close()
            return true
        case 126:                   // ↑
            move(by: -1)
            return true
        case 125:                   // ↓
            move(by: 1)
            return true
        case 116:                   // page up
            move(by: -5)
            return true
        case 121:                   // page down
            move(by: 5)
            return true
        case 36, 76:                // return, enter
            activateSelection()
            return true
        default:
            return false
        }
    }

    private func move(by delta: Int) {
        guard !shown.isEmpty else { return }
        selection = min(max(selection + delta, 0), shown.count - 1)
        applySelection(animated: true)
    }

    func activateSelection() {
        guard shown.indices.contains(selection) else { return }
        let item = shown[selection]
        close()
        item.perform()
    }

    private func activate(_ item: PaletteItem) {
        close()
        item.perform()
    }

    /// Clicking the dimmed backdrop is a cancel, not a mis-click.
    override func mouseDown(with event: NSEvent) {
        close()
    }

    // MARK: Rows

    private func rebuildRows() {
        // `removeFromSuperview` alone leaves the view in the stack's
        // arrangement, which keeps the old rows drawing behind the new ones.
        for row in listStack.arrangedSubviews {
            listStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        rows.removeAll()

        for item in shown {
            let row = PaletteRowView(item: item)
            row.onClick = { [weak self] in self?.activate(item) }
            listStack.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: listStack.widthAnchor),
                row.heightAnchor.constraint(equalToConstant: 40),
            ])
            rows.append(row)
        }

        emptyLabel.isHidden = !shown.isEmpty
        applySelection(animated: false)
    }

    private func applySelection(animated: Bool) {
        for (index, row) in rows.enumerated() {
            row.setHighlighted(index == selection, animated: animated)
        }
        guard rows.indices.contains(selection) else { return }
        layoutSubtreeIfNeeded()
        rows[selection].scrollToVisible(rows[selection].bounds)
    }
}

// MARK: - Row

/// One clickable line: tinted symbol tile, title, group note, and a return
/// glyph that only appears on the row that return would run.
final class PaletteRowView: NSView {

    var onClick: (() -> Void)?

    private let item: PaletteItem
    private let tile = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let returnGlyph = NSTextField(labelWithString: "↩")

    init(item: PaletteItem) {
        self.item = item
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous

        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.wantsLayer = true
        tile.layer?.cornerRadius = 7
        tile.layer?.cornerCurve = .continuous
        tile.layer?.backgroundColor = item.group.tint.withAlphaComponent(0.14).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: item.title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iconView.contentTintColor = item.group.tint

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = item.title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.stringValue = item.detail
        detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        returnGlyph.translatesAutoresizingMaskIntoConstraints = false
        returnGlyph.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        returnGlyph.textColor = .controlAccentColor
        returnGlyph.isHidden = true

        tile.addSubview(iconView)
        [tile, titleLabel, detailLabel, returnGlyph].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            tile.centerYAnchor.constraint(equalTo: centerYAnchor),
            tile.widthAnchor.constraint(equalToConstant: 26),
            tile.heightAnchor.constraint(equalToConstant: 26),

            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: returnGlyph.leadingAnchor, constant: -6),

            returnGlyph.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            returnGlyph.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("PaletteRowView is created in code only")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    #if DEBUG
    /// Debug hook for the offscreen harness: what this row actually says, so
    /// a query can be checked against the match it produced.
    func describeForCheck() -> String {
        "\(item.title)[\(item.detail)]"
    }
    #endif

    func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let background = highlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : NSColor.clear
        returnGlyph.isHidden = !highlighted

        guard animated else {
            layer?.backgroundColor = background.cgColor
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        layer?.backgroundColor = background.cgColor
    }
}
