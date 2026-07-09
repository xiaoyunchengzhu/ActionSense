import Foundation

// MARK: - 双语支持（手动切换优先，未设置时跟随系统）

enum L10n {

    enum Language: String, CaseIterable {
        case auto = "auto"
        case english = "en"
        case chinese = "zh"

        var displayName: String {
            switch self {
            case .auto:    return isChineseSystem ? "自动 (中文)" : "Auto (English)"
            case .english: return "English"
            case .chinese: return "中文"
            }
        }
    }

    /// 用户偏好的语言（auto / en / zh），通过 UserDefaults 存取
    static var preferredLanguage: String {
        get { UserDefaults.standard.string(forKey: "preferredLanguage") ?? Language.auto.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "preferredLanguage") }
    }

    /// 当前是否使用中文
    static var isChinese: Bool {
        switch Language(rawValue: preferredLanguage) ?? .auto {
        case .chinese: return true
        case .english: return false
        case .auto:    return isChineseSystem
        }
    }

    /// 系统是否为中文
    static var isChineseSystem: Bool {
        guard let lang = Locale.preferredLanguages.first else { return false }
        return lang.hasPrefix("zh")
    }

    // MARK: - 模式名称

    enum Mode: String {
        case disabled, plainText, pasteFlow

        var text: String {
            switch (L10n.isChinese, self) {
            case (true, .disabled):  return "停用"
            case (true, .plainText): return "纯文本模式"
            case (true, .pasteFlow): return "PasteFlow"
            case (_, .disabled):     return "Disabled"
            case (_, .plainText):    return "Plain Text"
            case (_, .pasteFlow):    return "PasteFlow"
            }
        }
    }

    // MARK: - 识别类型名称

    enum Detected: String {
        case url, email, phone, address, datetime, ip, tracking, color, imageURL, math, geo, richHTML

        var text: String {
            switch (L10n.isChinese, self) {
            case (true, .url):       return "链接"
            case (true, .email):     return "邮箱"
            case (true, .phone):     return "电话"
            case (true, .address):   return "地址"
            case (true, .datetime):  return "日期时间"
            case (true, .ip):        return "IP 地址"
            case (true, .tracking):  return "快递单号"
            case (true, .color):     return "颜色值"
            case (true, .imageURL):  return "图片链接"
            case (true, .math):      return "数学计算"
            case (true, .geo):       return "经纬度"
            case (true, .richHTML):  return "富文本"
            case (_, .url):          return "URL"
            case (_, .email):        return "Email"
            case (_, .phone):        return "Phone"
            case (_, .address):      return "Address"
            case (_, .datetime):     return "Date & Time"
            case (_, .ip):           return "IP Address"
            case (_, .tracking):     return "Tracking"
            case (_, .color):        return "Color"
            case (_, .imageURL):     return "Image URL"
            case (_, .math):         return "Math"
            case (_, .geo):          return "Coordinates"
            case (_, .richHTML):     return "Rich Text"
            }
        }
    }

    // MARK: - 操作名称

    enum Action: String {
        case openBrowser, copyContent, openMail, callPhone, openMaps, addToCalendar
        case pingIP, trackPackage, copyColorHex, copyColorRGB, copyResult, openMapLocation
        case convertToMarkdown, convertToPlainText

        var text: String {
            switch (L10n.isChinese, self) {
            case (true, .openBrowser):        return "浏览器打开"
            case (true, .copyContent):        return "复制内容"
            case (true, .openMail):           return "写邮件"
            case (true, .callPhone):          return "拨打电话"
            case (true, .openMaps):           return "地图查看"
            case (true, .addToCalendar):      return "添加到日历"
            case (true, .pingIP):             return "Ping"
            case (true, .trackPackage):       return "查快递"
            case (true, .copyColorHex):       return "复制 HEX"
            case (true, .copyColorRGB):       return "复制 RGB"
            case (true, .copyResult):         return "复制结果"
            case (true, .openMapLocation):    return "地图定位"
            case (true, .convertToMarkdown):  return "转为 Markdown"
            case (true, .convertToPlainText): return "转为纯文本"
            case (_, .openBrowser):           return "Open in Browser"
            case (_, .copyContent):           return "Copy"
            case (_, .openMail):              return "Compose Email"
            case (_, .callPhone):             return "Call"
            case (_, .openMaps):              return "Open in Maps"
            case (_, .addToCalendar):         return "Add to Calendar"
            case (_, .pingIP):                return "Ping"
            case (_, .trackPackage):          return "Track Package"
            case (_, .copyColorHex):          return "Copy HEX"
            case (_, .copyColorRGB):          return "Copy RGB"
            case (_, .copyResult):            return "Copy Result"
            case (_, .openMapLocation):       return "Open in Maps"
            case (_, .convertToMarkdown):     return "Convert to Markdown"
            case (_, .convertToPlainText):    return "Convert to Plain Text"
            }
        }
    }

    // MARK: - 菜单 UI

    enum Menu: String {
        case modeSelection, recentConversion, preferences, launchAtLogin
        case clipboardHistory, help, about, quit
        case waitingFirstCopy, lastCopyNonText, trialExpired
        case trialActive, buyActivate, simulateActivate, cancelActivate
        case price, version

        var text: String {
            switch (L10n.isChinese, self) {
            case (true, .modeSelection):     return "模式选择"
            case (true, .recentConversion):  return "最近转换"
            case (true, .preferences):       return "偏好设置"
            case (true, .launchAtLogin):     return "开机启动"
            case (true, .clipboardHistory):  return "剪贴板历史"
            case (true, .help):              return "使用帮助"
            case (true, .about):             return "关于 PurePaste"
            case (true, .quit):              return "退出 PurePaste"
            case (true, .waitingFirstCopy):  return "等待首次复制..."
            case (true, .lastCopyNonText):   return "上次复制的内容非文本，已忽略"
            case (true, .trialExpired):      return "试用期已结束，请购买以解锁全部功能"
            case (true, .trialActive):       return "试用中"
            case (true, .buyActivate):       return "购买激活"
            case (true, .simulateActivate):  return "模拟激活 (Debug)"
            case (true, .cancelActivate):    return "取消激活 (Debug)"
            case (true, .price):             return "$9.99"
            case (true, .version):           return "版本 2.0"
            case (_, .modeSelection):        return "Mode"
            case (_, .recentConversion):     return "Recent"
            case (_, .preferences):          return "Preferences"
            case (_, .launchAtLogin):        return "Launch at Login"
            case (_, .clipboardHistory):     return "Clipboard History"
            case (_, .help):                 return "Help"
            case (_, .about):                return "About PurePaste"
            case (_, .quit):                 return "Quit PurePaste"
            case (_, .waitingFirstCopy):     return "Waiting for first copy..."
            case (_, .lastCopyNonText):      return "Last copy was non-text, ignored"
            case (_, .trialExpired):         return "Trial expired. Purchase to unlock all features."
            case (_, .trialActive):          return "Trial"
            case (_, .buyActivate):          return "Buy Activation"
            case (_, .simulateActivate):     return "Simulate Activate (Debug)"
            case (_, .cancelActivate):       return "Deactivate (Debug)"
            case (_, .price):                return "$9.99"
            case (_, .version):              return "Version 2.0"
            }
        }
    }

    // MARK: - 帮助文案

    static var helpText: String {
        if isChinese {
            return """
            模式说明：
            🔵 纯文本模式 — 自动剥离复制内容的富文本格式，清理多余空白和 CJK 空格，写回剪贴板
            🩵 PasteFlow   — 智能识别复制内容类型，在鼠标旁弹出操作面板，一键直达

            PasteFlow 识别类型：
            URL / 邮箱 / 电话 / 地址 / IP / 日期
            颜色值 / 数学算式 / 经纬度 / 快递单号
            富文本（转为 Markdown / 纯文本）

            操作提示：
            · 面板仅一个按钮时，按 Enter 直接触发
            · 按 ESC 或点击面板外部关闭面板
            · 菜单栏图标颜色随模式变化，一眼知状态

            历史记录：
            · 点击菜单「剪贴板历史」打开独立窗口
            · 🟢 意图完成  🟠 识别未操作  ⚪ 普通复制
            · 支持按类型、模式、关键词筛选

            隐私声明：所有处理均在本地完成，数据永不上传。
            问题反馈：https://github.com/xiaoyunchengzhu/PurePaste/issues
            作者网站：https://www.xiaoniubuniu.com
            """
        } else {
            return """
            Modes:
            🔵 Plain Text — Auto strip formatting, clean whitespace & CJK spacing
            🩵 PasteFlow  — Detect content type, pop up action panel near cursor

            PasteFlow Detection:
            URL / Email / Phone / Address / IP / Date
            Color / Math / Coordinates / Tracking / Rich HTML

            Tips:
            · Press Enter to trigger when only one action is shown
            · Press ESC or click outside to dismiss the panel
            · Menu bar icon color reflects current mode

            History:
            · Click "Clipboard History" in the menu to open
            · 🟢 Fulfilled  🟠 Detected  ⚪ Plain
            · Filter by type, mode, or keyword

            Privacy: All processing is local. Your data never leaves this machine.
            Feedback: https://github.com/xiaoyunchengzhu/PurePaste/issues
            Author: https://www.xiaoniubuniu.com
            """
        }
    }

    static var helpTitle: String {
        isChinese ? "PurePaste 使用帮助" : "PurePaste Help"
    }

    static var helpButton: String {
        isChinese ? "知道了" : "Got it"
    }

    // MARK: - 关于文案

    static var aboutText: String {
        if isChinese {
            return """
            macOS 智能剪贴板助手。
            纯文本净化 + PasteFlow 智能识别 + 意图历史回溯。

            隐私声明：
            所有处理均在本地完成，数据永不上传。

            开发者：小牛不牛
            网站：https://www.xiaoniubuniu.com
            GitHub：https://github.com/xiaoyunchengzhu/PurePaste
            """
        } else {
            return """
            macOS smart clipboard assistant.
            Plain text purification + PasteFlow intent detection + intent history.

            Privacy: All processing is local. Your data never leaves this machine.

            Developer: xiaoniubuniu
            Website: https://www.xiaoniubuniu.com
            GitHub: https://github.com/xiaoyunchengzhu/PurePaste
            """
        }
    }

    static var aboutTitle: String { "PurePaste" }

    // MARK: - 历史窗口

    enum HistoryFilter: String {
        case all, intentFulfilled, detectedOnly, unrecognized, plainText

        var text: String {
            switch (L10n.isChinese, self) {
            case (true, .all):             return "全部"
            case (true, .intentFulfilled): return "意图"
            case (true, .detectedOnly):    return "识别"
            case (true, .unrecognized):    return "未识别"
            case (true, .plainText):       return "纯文本"
            case (_, .all):                return "All"
            case (_, .intentFulfilled):    return "Fulfilled"
            case (_, .detectedOnly):       return "Detected"
            case (_, .unrecognized):       return "Other"
            case (_, .plainText):          return "Plain"
            }
        }
    }

    static var historySearchPlaceholder: String {
        isChinese ? "搜索历史..." : "Search history..."
    }

    static var historyNoRecords: String {
        isChinese ? "暂无历史记录" : "No history yet"
    }

    static var historyNoMatch: String {
        isChinese ? "未找到匹配项" : "No matching entries"
    }

    static var historyClearAll: String {
        isChinese ? "清除全部" : "Clear All"
    }

    static var historyCopyText: String {
        isChinese ? "复制文本" : "Copy Text"
    }

    static var historyDeleteEntry: String {
        isChinese ? "删除此记录" : "Delete Entry"
    }

    static var historyNotActed: String {
        isChinese ? "未操作" : "Not acted"
    }

    static var historyTitle: String {
        isChinese ? "PurePaste 剪贴板历史" : "PurePaste Clipboard History"
    }

    // MARK: - 启动信息

    static var startupMessage: String {
        isChinese
            ? "🔵 蓝色 = 纯文本 | 🩵 青色 = PasteFlow | ⚫ 灰色 = 停用"
            : "🔵 Blue = Plain Text | 🩵 Teal = PasteFlow | ⚫ Gray = Disabled"
    }

    // MARK: - 日历事件名称

    static var calendarEventTitle: String {
        isChinese ? "来自剪贴板" : "From Clipboard"
    }

    // MARK: - AppleScript Terminal 打开

    static var terminalPingScript: String { "ping -c 4 " }

    // MARK: - 快递搜索

    static var trackingSearchQuery: String { "快递" }
}
