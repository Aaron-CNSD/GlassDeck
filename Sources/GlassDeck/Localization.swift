import Foundation

/// A lightweight, dependency-free localization layer.
///
/// Glass Deck supports five languages and follows the system language
/// automatically. Strings are keyed by a semantic identifier so every UI
/// surface (main app, menu bar, widgets) reads from a single source of truth.
enum L {

    // MARK: - Language detection

    /// The active language, resolved from the user's preferred localizations.
    enum Lang {
        case zhHans, zhHant, en, ja, ko

        static var current: Lang {
            let preferred = Locale.preferredLanguages.first ?? "en"
            let code = preferred.lowercased()
            if code.hasPrefix("zh-hans") || code.hasPrefix("zh_cn") || code == "zh-cn" { return .zhHans }
            if code.hasPrefix("zh-hant") || code.hasPrefix("zh_tw") || code.hasPrefix("zh_hk") || code.hasPrefix("zh-mo") { return .zhHant }
            if code.hasPrefix("ja") { return .ja }
            if code.hasPrefix("ko") { return .ko }
            return .en
        }
    }

    // MARK: - Lookup

    static func t(_ key: Key) -> String {
        let table = table(for: Lang.current)
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

        case tabSwitches, tabMonitor, tabWindows, tabCleaner, tabTools, tabLaunch

        // Toggles
        case darkMode, hiddenFiles, pathBar, desktopIcons, keepAwake, mute,
             autoHideDock, hideMenuBar, naturalScrolling

        // Monitor
        case cpu, memory, network, upload, download

        // Windows
        case windowTitle, bringToFront, forceQuit, refresh

        // Cleaner
        case cleanerTitle, scan, cleanAll, scanHint, cleaning, freed, nothingToClean

        // Tools
        case toolsTitle, screenshot, screenRecord, ocr, ocrCopied, ocrNoImage

        // Launch
        case launchTitle, addItem, emptyLaunch

        // Menu / general
        case openControlWindow, quit, settings

        // Widget
        case widgetSwitchTitle, widgetEmpty
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

    .launchTitle: "Quick Launch",
    .addItem: "Add Item",
    .emptyLaunch: "No shortcuts yet",

    .openControlWindow: "Open Control Window",
    .quit: "Quit Glass Deck",
    .settings: "Settings",

    .widgetSwitchTitle: "Quick Switches",
    .widgetEmpty: "Open Glass Deck to configure",
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

    .launchTitle: "快捷启动",
    .addItem: "添加项目",
    .emptyLaunch: "暂无快捷方式",

    .openControlWindow: "打开控制窗口",
    .quit: "退出玻璃面板",
    .settings: "设置",

    .widgetSwitchTitle: "快捷开关",
    .widgetEmpty: "打开玻璃面板进行配置",
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

    .launchTitle: "快速啟動",
    .addItem: "新增項目",
    .emptyLaunch: "尚無捷徑",

    .openControlWindow: "開啟控制視窗",
    .quit: "結束玻璃面板",
    .settings: "設定",

    .widgetSwitchTitle: "快捷開關",
    .widgetEmpty: "開啟玻璃面板進行設定",
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

    .launchTitle: "クイック起動",
    .addItem: "項目を追加",
    .emptyLaunch: "ショートカットがありません",

    .openControlWindow: "コントロールウィンドウを開く",
    .quit: "グラスデッキを終了",
    .settings: "設定",

    .widgetSwitchTitle: "クイックスイッチ",
    .widgetEmpty: "グラスデッキを開いて設定",
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

    .launchTitle: "빠른 실행",
    .addItem: "항목 추가",
    .emptyLaunch: "바로가기가 없습니다",

    .openControlWindow: "컨트롤 윈도우 열기",
    .quit: "글래스 덱 종료",
    .settings: "설정",

    .widgetSwitchTitle: "빠른 스위치",
    .widgetEmpty: "글래스 덱을 열어 설정",
]
