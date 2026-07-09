import AppKit

// MARK: - 操作执行器，处理 PasteFlow 面板中各按钮的实际行为

enum ActionExecutor {

    /// 执行指定操作
    static func execute(action: PasteFlowAction, content: DetectedContent) {
        switch action {
        case .openBrowser:
            openBrowser(for: content)
        case .openMail:
            openMail(for: content)
        case .callPhone:
            callPhone(for: content)
        case .openMaps:
            openMaps(for: content)
        case .addToCalendar:
            addToCalendar(for: content)
        case .pingIP:
            pingIP(for: content)
        case .trackPackage:
            trackPackage(for: content)
        case .copyColorHex:
            copyColorHex(for: content)
        case .copyColorRGB:
            copyColorRGB(for: content)
        case .copyResult:
            copyResult(for: content)
        case .openMapLocation:
            openMapLocation(for: content)
        case .convertToMarkdown:
            convertToMarkdown(for: content)
        case .convertToPlainText:
            convertToPlainText(for: content)
        }
    }

    // MARK: - 浏览器打开

    private static func openBrowser(for content: DetectedContent) {
        let urlString: String?
        switch content {
        case .url(let url):
            urlString = url.absoluteString
        case .imageURL(let url):
            urlString = url.absoluteString
        default:
            urlString = nil
        }
        guard let str = urlString, let url = URL(string: str) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 打开邮件客户端

    private static func openMail(for content: DetectedContent) {
        guard case .email(let addr) = content else { return }
        if let url = URL(string: "mailto:\(addr)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 拨打电话

    private static func callPhone(for content: DetectedContent) {
        guard case .phone(let num) = content else { return }
        let digits = num.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:\(digits)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 地图查看

    private static func openMaps(for content: DetectedContent) {
        guard case .address(let addr) = content else { return }
        // 使用 Apple Maps URL Scheme
        let encoded = addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? addr
        if let url = URL(string: "https://maps.apple.com/?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 添加到日历

    private static func addToCalendar(for content: DetectedContent) {
        guard case .datetime(let date, let original) = content else { return }

        // 创建日历事件的基本信息写入剪贴板
        // 由于直接写入系统日历需要 EventKit 权限（较复杂），
        // 这里采用将事件详情复制到剪贴板的方式
        let formatter = DateFormatter()
        formatter.locale = L10n.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = L10n.isChinese ? "yyyy年M月d日 HH:mm" : "MMM d, yyyy HH:mm"

        let info = """
        \(L10n.calendarEventTitle)
        \(L10n.isChinese ? "时间" : "Time")：\(formatter.string(from: date))
        \(L10n.isChinese ? "原始内容" : "Original")：\(original)
        """
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(info, forType: .string)

        // 尝试通过 URL scheme 打开日历快速添加
        // macOS 不支持直接 add-event URL，替代方案是打开日历 App
        if let calendarURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "ical://")!) {
            NSWorkspace.shared.open(calendarURL)
        }
    }

    // MARK: - Ping IP

    private static func pingIP(for content: DetectedContent) {
        guard case .ipAddress(let ip) = content else { return }
        // 打开终端并执行 ping
        let script = """
        tell application "Terminal"
            activate
            do script "ping -c 4 \(ip)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }

    // MARK: - 查快递

    private static func trackPackage(for content: DetectedContent) {
        guard case .tracking(let number, _) = content else { return }
        // 使用百度搜索快递单号
        let encoded = number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number
        if let url = URL(string: "https://www.baidu.com/s?wd=\(encoded)%20%E5%BF%AB%E9%80%92") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 复制 HEX

    private static func copyColorHex(for content: DetectedContent) {
        guard case .color(_, let hex) = content else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
    }

    // MARK: - 复制 RGB

    private static func copyColorRGB(for content: DetectedContent) {
        guard case .color(let color, _) = content else { return }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        let rgb = "rgb(\(r), \(g), \(b))"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(rgb, forType: .string)
    }

    // MARK: - 复制计算结果

    private static func copyResult(for content: DetectedContent) {
        guard case .mathExpression(_, let result) = content else { return }
        let text: String
        if result == floor(result) && result.isFinite {
            text = String(format: "%.0f", result)
        } else {
            text = String(format: "%.6g", result)
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - 地图定位（经纬度）

    private static func openMapLocation(for content: DetectedContent) {
        guard case .geoCoordinate(let lat, let lng) = content else { return }
        let urlStr = "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(lat),\(lng)"
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 格式转换

    /// HTML / 富文本 → Markdown（使用检测时存储的 HTML 数据，不重新读剪贴板）
    private static func convertToMarkdown(for content: DetectedContent) {
        guard case .richHTML(let text, let htmlData) = content, !htmlData.isEmpty else { return }
        let markdown = TextProcessor.smartMarkdown(htmlData: htmlData, fallbackText: text)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }

    /// 任意内容 → 纯文本
    private static func convertToPlainText(for content: DetectedContent) {
        let text: String
        switch content {
        case .richHTML(let t, _): text = t
        default: text = content.previewText
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(TextProcessor.plainText(text), forType: .string)
    }

}
