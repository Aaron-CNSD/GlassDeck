import AppKit

/// The single source of truth for every switch the app can flip.
///
/// Both the full deck and the compact panel read from here, so a toggle can
/// never exist in one surface and be missing from the other.
enum ToggleLibrary {

    static var all: [Toggle] {
        [
            Toggle(id: "darkmode", title: L.t(.darkMode), symbol: "moon.fill",
                   isOn: { SystemController.isDarkMode },
                   setState: { SystemController.setDarkMode($0) }),
            Toggle(id: "hiddenfiles", title: L.t(.hiddenFiles), symbol: "eye.slash.fill",
                   isOn: { SystemController.showHiddenFiles },
                   setState: { SystemController.setShowHiddenFiles($0) }),
            Toggle(id: "pathbar", title: L.t(.pathBar), symbol: "point.topleft.down.curvedto.point.bottomright.up",
                   isOn: { SystemController.showPathBar },
                   setState: { SystemController.setShowPathBar($0) }),
            Toggle(id: "desktopicons", title: L.t(.desktopIcons), symbol: "desktopcomputer",
                   isOn: { SystemController.hideDesktopIcons },
                   setState: { SystemController.setHideDesktopIcons($0) }),
            Toggle(id: "keepawake", title: L.t(.keepAwake), symbol: "moon.zzz.fill",
                   isOn: { SystemController.isKeepAwake },
                   setState: { SystemController.setKeepAwake($0) }),
            Toggle(id: "mute", title: L.t(.mute), symbol: "speaker.slash.fill",
                   isOn: { SystemController.isMuted },
                   setState: { SystemController.setMuted($0) }),
            Toggle(id: "autohidedock", title: L.t(.autoHideDock), symbol: "dock.rectangle",
                   isOn: { SystemController.autoHideDock },
                   setState: { SystemController.setAutoHideDock($0) }),
            Toggle(id: "menubar", title: L.t(.hideMenuBar), symbol: "rectangle.topthird.inset.filled",
                   isOn: { SystemController.hideMenuBar },
                   setState: { SystemController.setHideMenuBar($0) }),
            Toggle(id: "scroll", title: L.t(.naturalScrolling), symbol: "arrow.up.arrow.down",
                   isOn: { SystemController.naturalScrolling },
                   setState: { SystemController.setNaturalScrolling($0) }),
            Toggle(id: "statusbar", title: L.t(.showStatusBar), symbol: "rectangle.bottomthird.inset.filled",
                   isOn: { SystemController.showStatusBar },
                   setState: { SystemController.setShowStatusBar($0) }),
            Toggle(id: "extensions", title: L.t(.showAllExtensions), symbol: "textformat.abc",
                   isOn: { SystemController.showAllExtensions },
                   setState: { SystemController.setShowAllExtensions($0) }),
        ]
    }

    /// The handful of switches worth showing in the compact panel.
    static var compact: [Toggle] {
        let ids: Set<String> = ["darkmode", "keepawake", "desktopicons", "mute"]
        return all.filter { ids.contains($0.id) }
    }
}
