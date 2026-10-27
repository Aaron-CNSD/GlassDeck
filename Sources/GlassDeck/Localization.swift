import Foundation

/// A lightweight, dependency-free localization layer.
///
/// Glass Deck supports five languages and follows the system language
/// automatically. Strings are keyed by a semantic identifier so every UI
/// surface (main app, menu bar, widgets) reads from a single source of truth.
enum L {

    // MARK: - Language detection

    /// The active language, resolved from the user's preferred localizations.
    enum Lang: CaseIterable {
        case zhHans, zhHant, en, ja, ko

        /// ISO code, e.g. "zh-Hans".
        var code: String {
            switch self {
            case .zhHans: return "zh-Hans"
            case .zhHant: return "zh-Hant"
            case .en: return "en"
            case .ja: return "ja"
            case .ko: return "ko"
            }
        }

        /// Native display name, e.g. "简体中文", "English".
        var displayName: String {
            switch self {
            case .zhHans: return "简体中文"
            case .zhHant: return "繁體中文"
            case .en: return "English"
            case .ja: return "日本語"
            case .ko: return "한국어"
            }
        }

        /// The language the system would pick, ignoring any manual override.
        static var system: Lang {
            let preferred = Locale.preferredLanguages.first ?? "en"
            let code = preferred.lowercased()
            if code.hasPrefix("zh-hans") || code.hasPrefix("zh_cn") || code == "zh-cn" { return .zhHans }
            if code.hasPrefix("zh-hant") || code.hasPrefix("zh_tw") || code.hasPrefix("zh_hk") || code.hasPrefix("zh-mo") { return .zhHant }
            if code.hasPrefix("ja") { return .ja }
            if code.hasPrefix("ko") { return .ko }
            return .en
        }
    }

    /// Notification posted whenever the language changes, so live UI can refresh.
    static let languageChangedNotification = Notification.Name("GlassDeckLanguageChanged")

    private static let overrideKey = "GlassDeck.languageOverride"

    /// The currently effective language: manual override wins, else follow system.
    static var current: Lang {
        if let stored = UserDefaults.standard.string(forKey: overrideKey),
           let lang = Lang.allCases.first(where: { $0.code == stored }) {
            return lang
        }
        return .system
    }

    /// Whether the user has manually chosen a language (vs. following the system).
    static var hasOverride: Bool {
        UserDefaults.standard.string(forKey: overrideKey) != nil
    }

    /// Set a manual override, or pass `nil` to fall back to the system language.
    static func setOverride(_ lang: Lang?) {
        if let lang = lang {
            UserDefaults.standard.set(lang.code, forKey: overrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        }
        NotificationCenter.default.post(name: languageChangedNotification, object: nil)
    }

    // MARK: - Lookup

    static func t(_ key: Key) -> String {
        let table = table(for: current)
        return table[key] ?? en[key] ?? key.rawValue
    }

    private static func table(for lang: Lang) -> [Key: String] {
        switch lang {
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        case .ja: return ja
        case .ko: return ko
        case .en: return en
        }
    }

    // MARK: - Keys

    enum Key: String {
        case appName
        case appTagline

        case tabSwitches, tabMonitor, tabWindows, tabCleaner, tabTools, tabClipboard, tabLaunch

        // Toggles
        case darkMode, hiddenFiles, pathBar, desktopIcons, keepAwake, mute,
             autoHideDock, hideMenuBar, naturalScrolling, showStatusBar, showAllExtensions

        // Monitor
        case cpu, memory, network, upload, download,
             topProcesses, quitProcess, processListUnavailable

        // Windows
        case windowTitle, bringToFront, forceQuit, refresh

        // Cleaner
        case cleanerTitle, scan, cleanAll, scanHint, cleaning, freed, nothingToClean

        // Tools
        case toolsTitle, screenshot, screenRecord, ocr, ocrCopied, ocrNoImage,
             emptyTrash, emptyClipboard, screenSaver,
             dnsCache, restartFinder, copyIP, lockScreen, sleepDisplay, copied

        // Compact panel
        case compactMode, fullMode, openFullDeck

        // Diagnostics / permissions
        case permissionCheck, permissionCheckHint, recheck, back, granted,
             needsPermission, denied, unknownState, openSettings,
             checkCommands, checkCommandsOK, checkFinderPrefs, checkDockPrefs,
             checkGlobalPrefs, checkSystemEvents, checkFinderAutomation,
             checkScreenRecording, checkActivateSettings, prefsHint,
             automationDeniedHint, screenRecordingNeeded, failed, done, firstUseHint

        // Launch
        case launchTitle, addItem, emptyLaunch

        // Menu / general
        case openControlWindow, quit, settings, language, followSystem,
             languageChangedTitle, languageChangedBody, relaunchNow, relaunchLater

        // Widget
        case widgetSwitchTitle, widgetEmpty

        // Search & scenes
        case searchPlaceholder, scenesTitle, scenePresentation, sceneFocus,
             sceneTidy, sceneAllOff, noMatches, sceneApplied

        // Clipboard shelf
        case clipboardCapture, clipboardEmpty, clipboardClear, clipboardCleared,
             clipboardHint, clipboardCopied, clipboardOn, clipboardOff,
             clipboardPin, clipboardUnpin, clipboardRemove, clipboardCount
    }
}

// MARK: - English

private let en: [L.Key: String] = [
    .appName: "Glass Deck",
    .appTagline: "Your Mac, at a glance",

    .tabSwitches: "Switches",
    .tabMonitor: "Monitor",
    .tabWindows: "Windows",
    .tabCleaner: "Cleaner",
    .tabTools: "Tools",
    .tabLaunch: "Launch",

    .darkMode: "Dark Mode",
    .hiddenFiles: "Show Hidden Files",
    .pathBar: "Finder Path Bar",
    .desktopIcons: "Hide Desktop Icons",
    .keepAwake: "Keep Awake",
    .mute: "Mute",
    .autoHideDock: "Auto-Hide Dock",
    .hideMenuBar: "Hide Menu Bar",
    .naturalScrolling: "Natural Scrolling",

    .cpu: "CPU",
    .memory: "Memory",
    .network: "Network",
    .upload: "Upload",
    .download: "Download",

    .topProcesses: "Top Processes",
    .quitProcess: "Quit",
    .processListUnavailable: "Process list unavailable",

    .windowTitle: "Windows",
    .bringToFront: "Bring to Front",
    .forceQuit: "Force Quit",
    .refresh: "Refresh",

    .cleanerTitle: "Cleaner",
    .scan: "Scan",
    .cleanAll: "Clean All",
    .scanHint: "Scan to see cache sizes",
    .cleaning: "Cleaning…",
    .freed: "Freed",
    .nothingToClean: "Nothing to clean",

    .toolsTitle: "Tools",
    .screenshot: "Screenshot",
    .screenRecord: "Screen Record",
    .ocr: "OCR Clipboard",
    .ocrCopied: "OCR text copied to clipboard",
    .ocrNoImage: "No image in clipboard",
    .emptyTrash: "Empty Trash",
    .emptyClipboard: "Empty Clipboard",
    .screenSaver: "Start Screen Saver",
    .dnsCache: "Flush DNS Cache",
    .restartFinder: "Restart Finder",
    .copyIP: "Copy Local IP",
    .lockScreen: "Lock Screen",
    .sleepDisplay: "Sleep Display",
    .copied: "Copied",

    .compactMode: "Compact Panel",
    .fullMode: "Full Panel",
    .openFullDeck: "Open Full Deck",

    .showStatusBar: "Finder Status Bar",
    .showAllExtensions: "Show File Extensions",

    .permissionCheck: "Permission Check",
    .permissionCheckHint: "Each row is a real probe. Anything orange or red is the reason a feature does nothing.",
    .recheck: "Re-check",
    .back: "Back",
    .granted: "Allowed",
    .needsPermission: "Not allowed yet",
    .denied: "Denied in System Settings",
    .unknownState: "Target not running",
    .openSettings: "Open Settings",
    .checkCommands: "System tools",
    .checkCommandsOK: "defaults, killall, osascript, screencapture all present",
    .checkFinderPrefs: "Finder settings writable",
    .checkDockPrefs: "Dock settings writable",
    .checkGlobalPrefs: "System settings writable",
    .checkSystemEvents: "Control System Events (Dark Mode)",
    .checkFinderAutomation: "Control Finder (Empty Trash)",
    .checkScreenRecording: "Screen Recording (Screenshot)",
    .checkActivateSettings: "Apply UI settings",
    .prefsHint: "Write blocked — check Full Disk Access",
    .automationDeniedHint: "macOS blocked this. Allow it in System Settings › Privacy & Security › Automation.",
    .screenRecordingNeeded: "Screen Recording permission is required. Enable it, then try again.",
    .failed: "Failed",
    .done: "Done",
    .firstUseHint: "Not requested yet — macOS asks on first use",

    .launchTitle: "Quick Launch",
    .addItem: "Add Item",
    .emptyLaunch: "No shortcuts yet",

    .openControlWindow: "Open Control Window",
    .quit: "Quit Glass Deck",
    .settings: "Settings",
    .language: "Language",
    .followSystem: "Follow System",
    .languageChangedTitle: "Language Changed",
    .languageChangedBody: "The language will take effect after Glass Deck relaunches.",
    .relaunchNow: "Relaunch Now",
    .relaunchLater: "Later",

    .widgetSwitchTitle: "Quick Switches",
    .widgetEmpty: "Open Glass Deck to configure",

    .searchPlaceholder: "Search switches",
    .scenesTitle: "Scenes",
    .scenePresentation: "Present",
    .sceneFocus: "Focus",
    .sceneTidy: "Tidy",
    .sceneAllOff: "All Off",
    .noMatches: "No switches match that search",
    .sceneApplied: "Scene applied",

    .tabClipboard: "Clipboard",
    .clipboardCapture: "Record clipboard",
    .clipboardEmpty: "Nothing yet. Copy some text and it lands here.",
    .clipboardClear: "Clear",
    .clipboardCleared: "Clipboard history cleared",
    .clipboardHint: "Stored on this Mac only. Items marked confidential by password managers are skipped.",
    .clipboardCopied: "Copied back to clipboard",
    .clipboardOn: "Clipboard history on",
    .clipboardOff: "Clipboard history off",
    .clipboardPin: "Pin to keep",
    .clipboardUnpin: "Unpin",
    .clipboardRemove: "Remove",
    .clipboardCount: "%d items",
]

// MARK: - 简体中文

private let zhHans: [L.Key: String] = [
    .appName: "玻璃面板",
    .appTagline: "一眼掌控你的 Mac",

    .tabSwitches: "开关",
    .tabMonitor: "监控",
    .tabWindows: "窗口",
    .tabCleaner: "清理",
    .tabTools: "工具",
    .tabLaunch: "启动",

    .darkMode: "深色模式",
    .hiddenFiles: "显示隐藏文件",
    .pathBar: "访达路径栏",
    .desktopIcons: "隐藏桌面图标",
    .keepAwake: "保持清醒",
    .mute: "静音",
    .autoHideDock: "自动隐藏程序坞",
    .hideMenuBar: "隐藏菜单栏",
    .naturalScrolling: "自然滚动",

    .cpu: "CPU",
    .memory: "内存",
    .network: "网络",
    .upload: "上传",
    .download: "下载",

    .topProcesses: "占用最高",
    .quitProcess: "退出",
    .processListUnavailable: "暂时读不到进程列表",

    .windowTitle: "窗口",
    .bringToFront: "置于最前",
    .forceQuit: "强制退出",
    .refresh: "刷新",

    .cleanerTitle: "清理",
    .scan: "扫描",
    .cleanAll: "全部清理",
    .scanHint: "点击扫描查看缓存大小",
    .cleaning: "清理中…",
    .freed: "已释放",
    .nothingToClean: "没有可清理的内容",

    .toolsTitle: "工具",
    .screenshot: "截图",
    .screenRecord: "录屏",
    .ocr: "剪贴板 OCR",
    .ocrCopied: "OCR 文字已复制到剪贴板",
    .ocrNoImage: "剪贴板中没有图片",
    .emptyTrash: "清空废纸篓",
    .emptyClipboard: "清空剪贴板",
    .screenSaver: "启动屏保",
    .dnsCache: "清除 DNS 缓存",
    .restartFinder: "重启访达",
    .copyIP: "复制本机 IP",
    .lockScreen: "锁定屏幕",
    .sleepDisplay: "显示器休眠",
    .copied: "已复制",

    .compactMode: "简版面板",
    .fullMode: "完整面板",
    .openFullDeck: "打开完整面板",

    .showStatusBar: "访达状态栏",
    .showAllExtensions: "显示文件扩展名",

    .permissionCheck: "权限自检",
    .permissionCheckHint: "每一行都是一次真实检测。橙色或红色，就是某个功能点了没反应的原因。",
    .recheck: "重新检测",
    .back: "返回",
    .granted: "已授权",
    .needsPermission: "尚未授权",
    .denied: "已在系统设置中拒绝",
    .unknownState: "目标未运行",
    .openSettings: "打开设置",
    .checkCommands: "系统命令",
    .checkCommandsOK: "defaults、killall、osascript、screencapture 均可用",
    .checkFinderPrefs: "访达设置可写入",
    .checkDockPrefs: "程序坞设置可写入",
    .checkGlobalPrefs: "系统设置可写入",
    .checkSystemEvents: "控制系统事件（深色模式）",
    .checkFinderAutomation: "控制访达（清空废纸篓）",
    .checkScreenRecording: "屏幕录制（截图）",
    .checkActivateSettings: "应用界面设置",
    .prefsHint: "写入被拦截，请检查「完全磁盘访问权限」",
    .automationDeniedHint: "macOS 阻止了该操作。请在 系统设置 › 隐私与安全性 › 自动化 中允许。",
    .screenRecordingNeeded: "需要「屏幕录制」权限，开启后再试一次。",
    .failed: "失败",
    .done: "已完成",
    .firstUseHint: "尚未请求过（首次操作时系统会询问）",

    .launchTitle: "快捷启动",
    .addItem: "添加项目",
    .emptyLaunch: "暂无快捷方式",

    .openControlWindow: "打开控制窗口",
    .quit: "退出玻璃面板",
    .settings: "设置",
    .language: "语言",
    .followSystem: "跟随系统",
    .languageChangedTitle: "语言已切换",
    .languageChangedBody: "语言将在玻璃面板重新启动后生效。",
    .relaunchNow: "立即重启",
    .relaunchLater: "稍后",

    .widgetSwitchTitle: "快捷开关",
    .widgetEmpty: "打开玻璃面板进行配置",

    .searchPlaceholder: "搜索开关",
    .scenesTitle: "场景",
    .scenePresentation: "演示",
    .sceneFocus: "专注",
    .sceneTidy: "整理",
    .sceneAllOff: "全关",
    .noMatches: "没有匹配的开关",
    .sceneApplied: "场景已应用",

    .tabClipboard: "剪贴板",
    .clipboardCapture: "记录剪贴板",
    .clipboardEmpty: "还没有记录，复制点什么就会出现在这里。",
    .clipboardClear: "清空",
    .clipboardCleared: "剪贴板历史已清空",
    .clipboardHint: "只保存在这台 Mac 上；密码管理器标记为机密的内容会自动跳过。",
    .clipboardCopied: "已复制回剪贴板",
    .clipboardOn: "剪贴板历史已开启",
    .clipboardOff: "剪贴板历史已关闭",
    .clipboardPin: "固定保留",
    .clipboardUnpin: "取消固定",
    .clipboardRemove: "删除",
    .clipboardCount: "%d 条",
]

// MARK: - 繁體中文

private let zhHant: [L.Key: String] = [
    .appName: "玻璃面板",
    .appTagline: "一眼掌控你的 Mac",

    .tabSwitches: "開關",
    .tabMonitor: "監控",
    .tabWindows: "視窗",
    .tabCleaner: "清理",
    .tabTools: "工具",
    .tabLaunch: "啟動",

    .darkMode: "深色模式",
    .hiddenFiles: "顯示隱藏檔案",
    .pathBar: "Finder 路徑列",
    .desktopIcons: "隱藏桌面圖示",
    .keepAwake: "保持清醒",
    .mute: "靜音",
    .autoHideDock: "自動隱藏 Dock",
    .hideMenuBar: "隱藏選單列",
    .naturalScrolling: "自然捲動",

    .cpu: "CPU",
    .memory: "記憶體",
    .network: "網路",
    .upload: "上傳",
    .download: "下載",

    .topProcesses: "佔用最高",
    .quitProcess: "結束",
    .processListUnavailable: "暫時讀不到進程列表",

    .windowTitle: "視窗",
    .bringToFront: "置於最前",
    .forceQuit: "強制結束",
    .refresh: "重新整理",

    .cleanerTitle: "清理",
    .scan: "掃描",
    .cleanAll: "全部清理",
    .scanHint: "點擊掃描查看快取大小",
    .cleaning: "清理中…",
    .freed: "已釋放",
    .nothingToClean: "沒有可清理的內容",

    .toolsTitle: "工具",
    .screenshot: "截圖",
    .screenRecord: "錄影",
    .ocr: "剪貼簿 OCR",
    .ocrCopied: "OCR 文字已複製到剪貼簿",
    .ocrNoImage: "剪貼簿中沒有圖片",
    .emptyTrash: "清空垃圾桶",
    .emptyClipboard: "清空剪貼簿",
    .screenSaver: "啟動螢幕保護",
    .dnsCache: "清除 DNS 快取",
    .restartFinder: "重新啟動 Finder",
    .copyIP: "複製本機 IP",
    .lockScreen: "鎖定螢幕",
    .sleepDisplay: "顯示器休眠",
    .copied: "已複製",

    .compactMode: "簡版面板",
    .fullMode: "完整面板",
    .openFullDeck: "開啟完整面板",

    .showStatusBar: "Finder 狀態列",
    .showAllExtensions: "顯示檔案延伸檔名",

    .permissionCheck: "權限自我檢查",
    .permissionCheckHint: "每一列都是一次真實檢測。橘色或紅色，就是某個功能點了沒反應的原因。",
    .recheck: "重新檢測",
    .back: "返回",
    .granted: "已授權",
    .needsPermission: "尚未授權",
    .denied: "已在系統設定中拒絕",
    .unknownState: "目標未執行",
    .openSettings: "開啟設定",
    .checkCommands: "系統指令",
    .checkCommandsOK: "defaults、killall、osascript、screencapture 均可使用",
    .checkFinderPrefs: "Finder 設定可寫入",
    .checkDockPrefs: "Dock 設定可寫入",
    .checkGlobalPrefs: "系統設定可寫入",
    .checkSystemEvents: "控制系統事件（深色模式）",
    .checkFinderAutomation: "控制 Finder（清空垃圾桶）",
    .checkScreenRecording: "螢幕錄製（截圖）",
    .checkActivateSettings: "套用介面設定",
    .prefsHint: "寫入被封鎖，請檢查「完全磁碟取用權限」",
    .automationDeniedHint: "macOS 阻擋了這個操作。請在 系統設定 › 隱私權與安全性 › 自動化 中允許。",
    .screenRecordingNeeded: "需要「螢幕錄製」權限，開啟後再試一次。",
    .failed: "失敗",
    .done: "已完成",
    .firstUseHint: "尚未請求過（首次操作時系統會詢問）",

    .launchTitle: "快速啟動",
    .addItem: "新增項目",
    .emptyLaunch: "尚無捷徑",

    .openControlWindow: "開啟控制視窗",
    .quit: "結束玻璃面板",
    .settings: "設定",
    .language: "語言",
    .followSystem: "跟隨系統",
    .languageChangedTitle: "語言已切換",
    .languageChangedBody: "語言將在玻璃面板重新啟動後生效。",
    .relaunchNow: "立即重新啟動",
    .relaunchLater: "稍後",

    .widgetSwitchTitle: "快捷開關",
    .widgetEmpty: "開啟玻璃面板進行設定",

    .searchPlaceholder: "搜尋開關",
    .scenesTitle: "場景",
    .scenePresentation: "簡報",
    .sceneFocus: "專注",
    .sceneTidy: "整理",
    .sceneAllOff: "全關",
    .noMatches: "沒有符合的開關",
    .sceneApplied: "場景已套用",

    .tabClipboard: "剪貼板",
    .clipboardCapture: "記錄剪貼板",
    .clipboardEmpty: "還沒有記錄，複製點什麼就會出現在這裡。",
    .clipboardClear: "清空",
    .clipboardCleared: "剪貼板歷史已清空",
    .clipboardHint: "只保存在這台 Mac 上；密碼管理器標記為機密的內容會自動跳過。",
    .clipboardCopied: "已複製回剪貼板",
    .clipboardOn: "剪貼板歷史已開啟",
    .clipboardOff: "剪貼板歷史已關閉",
    .clipboardPin: "固定保留",
    .clipboardUnpin: "取消固定",
    .clipboardRemove: "刪除",
    .clipboardCount: "%d 條",
]

// MARK: - 日本語

private let ja: [L.Key: String] = [
    .appName: "グラスデッキ",
    .appTagline: "Mac をひと目で",

    .tabSwitches: "スイッチ",
    .tabMonitor: "モニター",
    .tabWindows: "ウィンドウ",
    .tabCleaner: "クリーン",
    .tabTools: "ツール",
    .tabLaunch: "起動",

    .darkMode: "ダークモード",
    .hiddenFiles: "隠しファイルを表示",
    .pathBar: "Finder パスバー",
    .desktopIcons: "デスクトップを隠す",
    .keepAwake: "スリープ防止",
    .mute: "ミュート",
    .autoHideDock: "Dock を自動的に隠す",
    .hideMenuBar: "メニューバーを隠す",
    .naturalScrolling: "ナチュラルスクロール",

    .cpu: "CPU",
    .memory: "メモリ",
    .network: "ネットワーク",
    .upload: "アップロード",
    .download: "ダウンロード",

    .topProcesses: "上位プロセス",
    .quitProcess: "終了",
    .processListUnavailable: "プロセス一覧を取得できません",

    .windowTitle: "ウィンドウ",
    .bringToFront: "前面に移動",
    .forceQuit: "強制終了",
    .refresh: "更新",

    .cleanerTitle: "クリーン",
    .scan: "スキャン",
    .cleanAll: "すべてクリーン",
    .scanHint: "スキャンしてキャッシュを確認",
    .cleaning: "クリーン中…",
    .freed: "解放済み",
    .nothingToClean: "クリーンするものはありません",

    .toolsTitle: "ツール",
    .screenshot: "スクリーンショット",
    .screenRecord: "画面収録",
    .ocr: "クリップボード OCR",
    .ocrCopied: "OCR テキストをクリップボードにコピーしました",
    .ocrNoImage: "クリップボードに画像がありません",
    .emptyTrash: "ゴミ箱を空にする",
    .emptyClipboard: "クリップボードを空にする",
    .screenSaver: "スクリーンセーバー起動",
    .dnsCache: "DNS キャッシュを消去",
    .restartFinder: "Finder を再起動",
    .copyIP: "ローカル IP をコピー",
    .lockScreen: "画面をロック",
    .sleepDisplay: "ディスプレイをスリープ",
    .copied: "コピーしました",

    .compactMode: "コンパクトパネル",
    .fullMode: "フルパネル",
    .openFullDeck: "フルパネルを開く",

    .showStatusBar: "Finder ステータスバー",
    .showAllExtensions: "拡張子を表示",

    .permissionCheck: "権限チェック",
    .permissionCheckHint: "各行は実際の検証です。オレンジや赤は、機能が反応しない原因です。",
    .recheck: "再チェック",
    .back: "戻る",
    .granted: "許可済み",
    .needsPermission: "未許可",
    .denied: "システム設定で拒否済み",
    .unknownState: "対象が起動していません",
    .openSettings: "設定を開く",
    .checkCommands: "システムコマンド",
    .checkCommandsOK: "defaults、killall、osascript、screencapture すべて利用可能",
    .checkFinderPrefs: "Finder 設定の書き込み",
    .checkDockPrefs: "Dock 設定の書き込み",
    .checkGlobalPrefs: "システム設定の書き込み",
    .checkSystemEvents: "System Events の制御（ダークモード）",
    .checkFinderAutomation: "Finder の制御（ゴミ箱を空にする）",
    .checkScreenRecording: "画面収録（スクリーンショット）",
    .checkActivateSettings: "UI 設定の適用",
    .prefsHint: "書き込みがブロックされています（フルディスクアクセスを確認）",
    .automationDeniedHint: "macOS がブロックしました。システム設定 › プライバシーとセキュリティ › オートメーション で許可してください。",
    .screenRecordingNeeded: "画面収録の権限が必要です。有効にしてから再試行してください。",
    .failed: "失敗",
    .done: "完了",
    .firstUseHint: "未要求（初回操作時に確認されます）",

    .launchTitle: "クイック起動",
    .addItem: "項目を追加",
    .emptyLaunch: "ショートカットがありません",

    .openControlWindow: "コントロールウィンドウを開く",
    .quit: "グラスデッキを終了",
    .settings: "設定",
    .language: "言語",
    .followSystem: "システムに従う",
    .languageChangedTitle: "言語を変更しました",
    .languageChangedBody: "言語はグラスデッキの再起動後に反映されます。",
    .relaunchNow: "今すぐ再起動",
    .relaunchLater: "後で",

    .widgetSwitchTitle: "クイックスイッチ",
    .widgetEmpty: "グラスデッキを開いて設定",

    .searchPlaceholder: "スイッチを検索",
    .scenesTitle: "シーン",
    .scenePresentation: "プレゼン",
    .sceneFocus: "集中",
    .sceneTidy: "整理",
    .sceneAllOff: "全てオフ",
    .noMatches: "一致するスイッチがありません",
    .sceneApplied: "シーンを適用しました",

    .tabClipboard: "クリップボード",
    .clipboardCapture: "クリップボードを記録",
    .clipboardEmpty: "まだ記録はありません。コピーするとここに残ります。",
    .clipboardClear: "消去",
    .clipboardCleared: "クリップボード履歴を消去しました",
    .clipboardHint: "この Mac にのみ保存されます。パスワードマネージャが機密指定した内容は記録しません。",
    .clipboardCopied: "クリップボードに戻しました",
    .clipboardOn: "クリップボード履歴をオンにしました",
    .clipboardOff: "クリップボード履歴をオフにしました",
    .clipboardPin: "固定して残す",
    .clipboardUnpin: "固定を解除",
    .clipboardRemove: "削除",
    .clipboardCount: "%d 件",
]

// MARK: - 한국어

private let ko: [L.Key: String] = [
    .appName: "글래스 덱",
    .appTagline: "당신의 Mac을 한눈에",

    .tabSwitches: "스위치",
    .tabMonitor: "모니터",
    .tabWindows: "윈도우",
    .tabCleaner: "정리",
    .tabTools: "도구",
    .tabLaunch: "실행",

    .darkMode: "다크 모드",
    .hiddenFiles: "숨김 파일 표시",
    .pathBar: "Finder 경로 막대",
    .desktopIcons: "데스크탑 아이콘 숨기기",
    .keepAwake: "잠자기 방지",
    .mute: "음소거",
    .autoHideDock: "Dock 자동 숨김",
    .hideMenuBar: "메뉴 막대 숨기기",
    .naturalScrolling: "자연 스크롤",

    .cpu: "CPU",
    .memory: "메모리",
    .network: "네트워크",
    .upload: "업로드",
    .download: "다운로드",

    .topProcesses: "사용량 상위",
    .quitProcess: "종료",
    .processListUnavailable: "프로세스 목록을 읽을 수 없습니다",

    .windowTitle: "윈도우",
    .bringToFront: "앞으로 가져오기",
    .forceQuit: "강제 종료",
    .refresh: "새로고침",

    .cleanerTitle: "정리",
    .scan: "스캔",
    .cleanAll: "모두 정리",
    .scanHint: "스캔하여 캐시 크기 확인",
    .cleaning: "정리 중…",
    .freed: "확보됨",
    .nothingToClean: "정리할 항목이 없습니다",

    .toolsTitle: "도구",
    .screenshot: "스크린샷",
    .screenRecord: "화면 녹화",
    .ocr: "클립보드 OCR",
    .ocrCopied: "OCR 텍스트가 클립보드에 복사되었습니다",
    .ocrNoImage: "클립보드에 이미지가 없습니다",
    .emptyTrash: "휴지통 비우기",
    .emptyClipboard: "클립보드 비우기",
    .screenSaver: "화면 보호기 시작",
    .dnsCache: "DNS 캐시 지우기",
    .restartFinder: "Finder 재시작",
    .copyIP: "로컬 IP 복사",
    .lockScreen: "화면 잠금",
    .sleepDisplay: "디스플레이 잠자기",
    .copied: "복사됨",

    .compactMode: "간단 패널",
    .fullMode: "전체 패널",
    .openFullDeck: "전체 패널 열기",

    .showStatusBar: "Finder 상태 막대",
    .showAllExtensions: "파일 확장자 표시",

    .permissionCheck: "권한 점검",
    .permissionCheckHint: "각 행은 실제 검증입니다. 주황색이나 빨간색이 기능이 반응하지 않는 이유입니다.",
    .recheck: "다시 점검",
    .back: "뒤로",
    .granted: "허용됨",
    .needsPermission: "아직 허용되지 않음",
    .denied: "시스템 설정에서 거부됨",
    .unknownState: "대상이 실행 중이 아님",
    .openSettings: "설정 열기",
    .checkCommands: "시스템 명령",
    .checkCommandsOK: "defaults, killall, osascript, screencapture 모두 사용 가능",
    .checkFinderPrefs: "Finder 설정 쓰기",
    .checkDockPrefs: "Dock 설정 쓰기",
    .checkGlobalPrefs: "시스템 설정 쓰기",
    .checkSystemEvents: "System Events 제어(다크 모드)",
    .checkFinderAutomation: "Finder 제어(휴지통 비우기)",
    .checkScreenRecording: "화면 기록(스크린샷)",
    .checkActivateSettings: "UI 설정 적용",
    .prefsHint: "쓰기가 차단되었습니다. 전체 디스크 접근 권한을 확인하세요",
    .automationDeniedHint: "macOS가 차단했습니다. 시스템 설정 › 개인정보 보호 및 보안 › 자동화에서 허용하세요.",
    .screenRecordingNeeded: "화면 기록 권한이 필요합니다. 활성화한 후 다시 시도하세요.",
    .failed: "실패",
    .done: "완료",
    .firstUseHint: "아직 요청되지 않음(처음 사용할 때 시스템이 묻습니다)",

    .launchTitle: "빠른 실행",
    .addItem: "항목 추가",
    .emptyLaunch: "바로가기가 없습니다",

    .openControlWindow: "컨트롤 윈도우 열기",
    .quit: "글래스 덱 종료",
    .settings: "설정",
    .language: "언어",
    .followSystem: "시스템 따르기",
    .languageChangedTitle: "언어가 변경되었습니다",
    .languageChangedBody: "언어는 글래스 덱 재시작 후 적용됩니다.",
    .relaunchNow: "지금 재시작",
    .relaunchLater: "나중에",

    .widgetSwitchTitle: "빠른 스위치",
    .widgetEmpty: "글래스 덱을 열어 설정",

    .searchPlaceholder: "스위치 검색",
    .scenesTitle: "장면",
    .scenePresentation: "발표",
    .sceneFocus: "집중",
    .sceneTidy: "정리",
    .sceneAllOff: "모두 끔",
    .noMatches: "일치하는 스위치가 없습니다",
    .sceneApplied: "장면을 적용했습니다",

    .tabClipboard: "클립보드",
    .clipboardCapture: "클립보드 기록",
    .clipboardEmpty: "아직 기록이 없습니다. 복사하면 여기에 남습니다.",
    .clipboardClear: "지우기",
    .clipboardCleared: "클립보드 기록을 지웠습니다",
    .clipboardHint: "이 Mac에만 저장됩니다. 암호 관리자가 기밀로 표시한 항목은 기록하지 않습니다.",
    .clipboardCopied: "클립보드로 다시 복사했습니다",
    .clipboardOn: "클립보드 기록 켜짐",
    .clipboardOff: "클립보드 기록 꺼짐",
    .clipboardPin: "고정",
    .clipboardUnpin: "고정 해제",
    .clipboardRemove: "삭제",
    .clipboardCount: "%d개",
]
