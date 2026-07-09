import Foundation
import AppKit

// MARK: - 内容识别结果

/// PasteFlow 识别到的内容类型，携带解析后的数据
enum DetectedContent {
    case url(URL)
    case email(String)
    case phone(String)
    case address(String)
    case datetime(Date, String)
    case ipAddress(String)
    case tracking(String, String)
    case color(NSColor, String)
    case imageURL(URL)
    case mathExpression(String, Double)
    case geoCoordinate(Double, Double)
    case richHTML(String, Data)  // (plainText, htmlData)

    /// 类型展示名称
    var displayType: String {
        switch self {
        case .url:             return L10n.Detected.url.text
        case .email:           return L10n.Detected.email.text
        case .phone:           return L10n.Detected.phone.text
        case .address:         return L10n.Detected.address.text
        case .datetime:        return L10n.Detected.datetime.text
        case .ipAddress:       return L10n.Detected.ip.text
        case .tracking:        return L10n.Detected.tracking.text
        case .color:           return L10n.Detected.color.text
        case .imageURL:        return L10n.Detected.imageURL.text
        case .mathExpression:  return L10n.Detected.math.text
        case .geoCoordinate:   return L10n.Detected.geo.text
        case .richHTML:        return L10n.Detected.richHTML.text
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .url:             return "link"
        case .email:           return "envelope"
        case .phone:           return "phone"
        case .address:         return "mappin.and.ellipse"
        case .datetime:        return "calendar"
        case .ipAddress:       return "network"
        case .tracking:        return "shippingbox"
        case .color:           return "paintpalette"
        case .imageURL:        return "photo"
        case .mathExpression:  return "function"
        case .geoCoordinate:   return "location.fill"
        case .richHTML:        return "doc.richtext"
        }
    }

    /// 原始文本摘要（用于面板预览）
    var previewText: String {
        switch self {
        case .url(let url):
            return url.absoluteString
        case .email(let addr):
            return addr
        case .phone(let num):
            return num
        case .address(let addr):
            return addr
        case .datetime(_, let original):
            return original
        case .ipAddress(let ip):
            return ip
        case .tracking(let num, _):
            return num
        case .color(_, let hex):
            return hex
        case .imageURL(let url):
            return url.absoluteString
        case .mathExpression(let expr, let result):
            return "\(expr) = \(formatNumber(result))"
        case .geoCoordinate(let lat, let lng):
            return String(format: "%.6f, %.6f", lat, lng)
        case .richHTML(let text, _):
            return String(text.prefix(80))
        }
    }

    /// 格式化数字显示（整数不显示小数点）
    private func formatNumber(_ n: Double) -> String {
        if n == floor(n) && n.isFinite {
            return String(format: "%.0f", n)
        }
        return String(format: "%.6g", n)
    }
}

// MARK: - 可执行的操作

enum PasteFlowAction: CaseIterable {
    case openBrowser
    case openMail
    case callPhone
    case openMaps
    case addToCalendar
    case pingIP
    case trackPackage
    case copyColorHex
    case copyColorRGB
    case copyResult
    case openMapLocation
    case convertToMarkdown
    case convertToPlainText

    var displayName: String {
        switch self {
        case .openBrowser:        return L10n.Action.openBrowser.text
        case .openMail:           return L10n.Action.openMail.text
        case .callPhone:          return L10n.Action.callPhone.text
        case .openMaps:           return L10n.Action.openMaps.text
        case .addToCalendar:      return L10n.Action.addToCalendar.text
        case .pingIP:             return L10n.Action.pingIP.text
        case .trackPackage:       return L10n.Action.trackPackage.text
        case .copyColorHex:       return L10n.Action.copyColorHex.text
        case .copyColorRGB:       return L10n.Action.copyColorRGB.text
        case .copyResult:         return L10n.Action.copyResult.text
        case .openMapLocation:    return L10n.Action.openMapLocation.text
        case .convertToMarkdown:  return L10n.Action.convertToMarkdown.text
        case .convertToPlainText: return L10n.Action.convertToPlainText.text
        }
    }

    var iconName: String {
        switch self {
        case .openBrowser:        return "safari"
        case .openMail:           return "envelope"
        case .callPhone:          return "phone"
        case .openMaps:           return "map"
        case .addToCalendar:      return "calendar.badge.plus"
        case .pingIP:             return "terminal"
        case .trackPackage:       return "shippingbox"
        case .copyColorHex:       return "number"
        case .copyColorRGB:       return "number.square"
        case .copyResult:         return "doc.on.doc"
        case .openMapLocation:    return "location.fill"
        case .convertToMarkdown:  return "arrow.down.doc"
        case .convertToPlainText: return "text.alignleft"
        }
    }

    /// 每种内容类型对应的一组操作
    static func actions(for content: DetectedContent) -> [PasteFlowAction] {
        switch content {
        case .url:         return [.openBrowser]
        case .email:       return [.openMail]
        case .phone:       return [.callPhone]
        case .address:     return [.openMaps]
        case .datetime:    return [.addToCalendar]
        case .ipAddress:   return [.pingIP]
        case .tracking:    return [.trackPackage]
        case .color:           return [.copyColorHex, .copyColorRGB]
        case .imageURL:        return [.openBrowser]
        case .mathExpression:  return [.copyResult]
        case .geoCoordinate:   return [.openMapLocation]
        case .richHTML:        return [.convertToMarkdown, .convertToPlainText]
        }
    }
}

// MARK: - 内容识别引擎

enum ContentDetector {

    /// 对剪贴板文本进行类型识别，返回第一个匹配的结果
    /// - Parameters:
    ///   - text: 剪贴板中的纯文本
    ///   - hasHTML: 剪贴板是否同时包含 HTML 数据
    /// - Returns: 识别到的内容类型与解析数据，未识别返回 nil
    static func detect(_ text: String, hasHTML: Bool = false, htmlData: Data? = nil) -> DetectedContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 按精确度从高到低依次匹配
        if let result = detectColor(trimmed)    { return result }
        if let result = detectIP(trimmed)       { return result }
        if let result = detectEmail(trimmed)    { return result }
        if let result = detectImageURL(trimmed)  { return result }
        if let result = detectURL(trimmed)      { return result }
        if let result = detectPhone(trimmed)    { return result }
        if let result = detectTracking(trimmed)  { return result }
        if let result = detectMathExpression(trimmed) { return result }
        if let result = detectGeoCoordinate(trimmed)  { return result }
        if let result = detectDatetime(trimmed)  { return result }

        // 富文本检测优先于地址
        if hasHTML { return .richHTML(trimmed, htmlData ?? Data()) }

        if let result = detectAddress(trimmed)   { return result }

        return nil
    }

    // MARK: - 颜色值识别

    private static func detectColor(_ text: String) -> DetectedContent? {
        // #RGB / #RRGGBB / #RRGGBBAA
        let hexPattern = "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
        if text.range(of: hexPattern, options: .regularExpression) != nil,
           let color = colorFromHex(text) {
            return .color(color, text.uppercased())
        }

        // rgb(r, g, b) / rgba(r, g, b, a)
        let rgbPattern = "^rgba?\\s*\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*(?:,\\s*([\\d.]+))?\\s*\\)$"
        if let regex = try? NSRegularExpression(pattern: rgbPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 4,
           let r = Int(text[match.range(at: 1)]),
           let g = Int(text[match.range(at: 2)]),
           let b = Int(text[match.range(at: 3)]),
           r <= 255, g <= 255, b <= 255 {
            let nsColor = NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            return .color(nsColor, hex)
        }

        return nil
    }

    private static func colorFromHex(_ hex: String) -> NSColor? {
        var hexStr = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        // 三位数扩展为六位
        if hexStr.count == 3 {
            hexStr = hexStr.map { "\($0)\($0)" }.joined()
        }
        guard hexStr.count == 6 || hexStr.count == 8,
              let value = UInt64(hexStr, radix: 16) else { return nil }

        let r, g, b, a: CGFloat
        if hexStr.count == 8 {
            r = CGFloat((value >> 24) & 0xFF) / 255.0
            g = CGFloat((value >> 16) & 0xFF) / 255.0
            b = CGFloat((value >> 8) & 0xFF) / 255.0
            a = CGFloat(value & 0xFF) / 255.0
        } else {
            r = CGFloat((value >> 16) & 0xFF) / 255.0
            g = CGFloat((value >> 8) & 0xFF) / 255.0
            b = CGFloat(value & 0xFF) / 255.0
            a = 1.0
        }
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - IP 地址识别

    private static func detectIP(_ text: String) -> DetectedContent? {
        let ipv4Pattern = "^((25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)\\.){3}(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)$"
        if text.range(of: ipv4Pattern, options: .regularExpression) != nil {
            return .ipAddress(text)
        }
        return nil
    }

    // MARK: - 邮箱识别

    private static func detectEmail(_ text: String) -> DetectedContent? {
        let emailPattern = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
        if text.range(of: emailPattern, options: .regularExpression) != nil {
            return .email(text)
        }
        return nil
    }

    // MARK: - 图片 URL 识别

    private static func detectImageURL(_ text: String) -> DetectedContent? {
        let imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".heic", ".avif"]
        let lower = text.lowercased()
        guard imageExtensions.contains(where: { lower.hasSuffix($0) || lower.contains("\($0)?") }) else { return nil }
        guard let url = URL(string: text), url.scheme != nil else { return nil }
        return .imageURL(url)
    }

    // MARK: - URL 识别

    private static func detectURL(_ text: String) -> DetectedContent? {
        // 必须有明确的 scheme 或者是 www. 开头
        guard let url = URL(string: text),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host?.contains(".") == true else {
            // 尝试 www. 开头
            if text.hasPrefix("www."), let url = URL(string: "https://\(text)") {
                return .url(url)
            }
            return nil
        }
        return .url(url)
    }

    // MARK: - 中国手机号识别

    private static func detectPhone(_ text: String) -> DetectedContent? {
        // 中国大陆手机号：1[3-9] 开头，共 11 位
        let phonePattern = "^(\\+?86[\\- ]?)?1[3-9]\\d{9}$"
        let cleaned = text.replacingOccurrences(of: "[\\- ]", with: "", options: .regularExpression)
        let cleanedWith86 = cleaned.replacingOccurrences(of: "^(\\+?86)", with: "", options: .regularExpression)

        if cleaned.range(of: phonePattern, options: .regularExpression) != nil ||
           cleanedWith86.range(of: "^1[3-9]\\d{9}$", options: .regularExpression) != nil {
            let formatted = formatPhoneNumber(cleanedWith86)
            return .phone(formatted)
        }
        return nil
    }

    private static func formatPhoneNumber(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        guard digits.count == 11 else { return raw }
        let s = Array(digits)
        return "\(s[0])\(s[1])\(s[2]) \(s[3])\(s[4])\(s[5])\(s[6]) \(s[7])\(s[8])\(s[9])\(s[10])"
    }

    // MARK: - 快递单号识别

    private static func detectTracking(_ text: String) -> DetectedContent? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)

        let carriers: [(String, String)] = [
            ("SF", "顺丰速运"),
            ("SF", "顺丰"),
            ("YT", "圆通速递"),
            ("YTO", "圆通速递"),
            ("ZTO", "中通快递"),
            ("STO", "申通快递"),
            ("JD", "京东物流"),
            ("DB", "德邦快递"),
            ("EMS", "中国邮政"),
        ]

        for (prefix, name) in carriers {
            if cleaned.hasPrefix(prefix) {
                // 顺丰：SF + 12位数字
                if prefix == "SF" {
                    let nums = String(cleaned.dropFirst(prefix.count))
                    if nums.count == 12 && nums.allSatisfy({ $0.isNumber }) {
                        return .tracking(cleaned, name)
                    }
                }
                // 圆通：YT/YTO + 数字
                if (prefix == "YT" || prefix == "YTO") {
                    let nums = cleaned.dropFirst(prefix.count)
                    if nums.count >= 10 && nums.allSatisfy({ $0.isNumber }) {
                        return .tracking(cleaned, name)
                    }
                }
                // 其他
                if prefix != "SF" && prefix != "YT" && prefix != "YTO" {
                    let nums = cleaned.dropFirst(prefix.count)
                    if nums.count >= 8 && nums.allSatisfy({ $0.isNumber }) {
                        return .tracking(cleaned, name)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 日期时间识别

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy年M月d日 HH:mm",
            "yyyy年M月d日",
            "M月d日 HH:mm",
            "MM-dd HH:mm",
            "HH:mm",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "zh_CN")
            return f
        }
    }()

    // MARK: - 数学表达式识别

    /// 安全计算算术表达式，使用 NSExpression
    /// 只允许数字、运算符、括号、小数点和空格
    private static func detectMathExpression(_ text: String) -> DetectedContent? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // 太短、太长都不像算式
        guard trimmed.count >= 3 && trimmed.count <= 60 else { return nil }

        // 必须包含至少一个运算符
        let hasOperator = trimmed.contains(where: { "+-*/^%".contains($0) })
        guard hasOperator else { return nil }

        // 必须有数字
        let hasNumber = trimmed.contains(where: { $0.isNumber })
        guard hasNumber else { return nil }

        // 安全字符集白名单：数字、运算符、括号、小数点、空格
        let allowed = CharacterSet(charactersIn: "0123456789+-*/^%()., ")
        let disallowed = trimmed.unicodeScalars.filter { !allowed.contains($0) }
        // 允许不超过 15% 的非算术字符（处理如 "100元+50" 这类）
        guard disallowed.count == 0 || Double(disallowed.count) / Double(trimmed.unicodeScalars.count) <= 0.15 else {
            return nil
        }

        // 清理：移除中文单位和货币符号
        let expr = trimmed
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .replacingOccurrences(of: ",", with: "") // 移除千分位逗号
            .replacingOccurrences(of: "^", with: "**") // ^ 转 Python-style 指数
            .replacingOccurrences(of: "％", with: "%")

        // 使用 NSExpression 安全计算
        guard let result = evaluateMath(expr) else { return nil }
        guard result.isFinite && !result.isNaN else { return nil }

        return .mathExpression(text, result)
    }

    /// 安全计算数学表达式（递归下降解析器，避免 NSExpression 的格式字符串陷阱）
    private static func evaluateMath(_ expression: String) -> Double? {
        let expr = expression
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "**", with: "^") // 统一指数符号
        // 只允许安全字符
        guard expr.allSatisfy({ c in
            c.isNumber || "+-*/%^().".contains(c)
        }) else { return nil }

        let tokens = tokenize(expr)
        guard !tokens.isEmpty else { return nil }

        var pos = 0
        guard let result = parseExpression(tokens, &pos) else { return nil }
        // 确保全部 token 被消费
        guard pos == tokens.count else { return nil }

        return result
    }

    // MARK: - 递归下降词法/语法分析

    private enum MathToken {
        case number(Double)
        case plus, minus, multiply, divide, modulo, power
        case leftParen, rightParen
        case end
    }

    private static func tokenize(_ expr: String) -> [MathToken] {
        var tokens: [MathToken] = []
        var i = expr.startIndex

        while i < expr.endIndex {
            let c = expr[i]
            if c.isNumber || c == "." {
                var numStr = ""
                var hasDot = false
                while i < expr.endIndex {
                    let ch = expr[i]
                    if ch.isNumber {
                        numStr.append(ch)
                    } else if ch == ".", !hasDot {
                        numStr.append(ch)
                        hasDot = true
                    } else {
                        break
                    }
                    i = expr.index(after: i)
                }
                if let val = Double(numStr) {
                    tokens.append(.number(val))
                }
                continue
            } else {
                switch c {
                case "+": tokens.append(.plus)
                case "-": tokens.append(.minus)
                case "*": tokens.append(.multiply)
                case "/": tokens.append(.divide)
                case "%": tokens.append(.modulo)
                case "^": tokens.append(.power)
                case "(": tokens.append(.leftParen)
                case ")": tokens.append(.rightParen)
                default: return [] // 非法字符
                }
                i = expr.index(after: i)
            }
        }
        tokens.append(.end)
        return tokens
    }

    // 表达式 = 项 (("+"|"-") 项)*
    private static func parseExpression(_ tokens: [MathToken], _ pos: inout Int) -> Double? {
        guard let left = parseTerm(tokens, &pos) else { return nil }
        var result = left
        while pos < tokens.count {
            switch tokens[pos] {
            case .plus:
                pos += 1
                guard let right = parseTerm(tokens, &pos) else { return nil }
                result += right
            case .minus:
                pos += 1
                guard let right = parseTerm(tokens, &pos) else { return nil }
                result -= right
            default:
                return result
            }
        }
        return result
    }

    // 项 = 指数 (("*"|"/"|"%") 指数)*
    private static func parseTerm(_ tokens: [MathToken], _ pos: inout Int) -> Double? {
        guard let left = parsePower(tokens, &pos) else { return nil }
        var result = left
        while pos < tokens.count {
            switch tokens[pos] {
            case .multiply:
                pos += 1
                guard let right = parsePower(tokens, &pos) else { return nil }
                result *= right
            case .divide:
                pos += 1
                guard let right = parsePower(tokens, &pos), right != 0 else { return nil }
                result /= right
            case .modulo:
                pos += 1
                guard let right = parsePower(tokens, &pos), right != 0 else { return nil }
                result = result.truncatingRemainder(dividingBy: right)
            default:
                return result
            }
        }
        return result
    }

    // 指数 = 一元 ("^" 一元)?
    private static func parsePower(_ tokens: [MathToken], _ pos: inout Int) -> Double? {
        guard let left = parseUnary(tokens, &pos) else { return nil }
        if pos < tokens.count, case .power = tokens[pos] {
            pos += 1
            guard let right = parseUnary(tokens, &pos) else { return nil }
            return pow(left, right)
        }
        return left
    }

    // 一元 = ("+"|"-")? 原子
    private static func parseUnary(_ tokens: [MathToken], _ pos: inout Int) -> Double? {
        if pos < tokens.count {
            if case .plus = tokens[pos] {
                pos += 1
                return parseAtom(tokens, &pos)
            }
            if case .minus = tokens[pos] {
                pos += 1
                guard let value = parseAtom(tokens, &pos) else { return nil }
                return -value
            }
        }
        return parseAtom(tokens, &pos)
    }

    // 原子 = 数字 | "(" 表达式 ")"
    private static func parseAtom(_ tokens: [MathToken], _ pos: inout Int) -> Double? {
        guard pos < tokens.count else { return nil }
        switch tokens[pos] {
        case .number(let value):
            pos += 1
            return value
        case .leftParen:
            pos += 1
            guard let result = parseExpression(tokens, &pos) else { return nil }
            guard pos < tokens.count, case .rightParen = tokens[pos] else { return nil }
            pos += 1
            return result
        default:
            return nil
        }
    }

    // MARK: - 经纬度识别

    /// 识别经纬度坐标对，支持多种格式：
    /// - 39.9042, 116.4074
    /// - 39.9042°N, 116.4074°E
    /// - 39°54'15"N, 116°23'27"E
    private static func detectGeoCoordinate(_ text: String) -> DetectedContent? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // 格式1：纯数字对 "lat, lng" 或 "lat lng"
        if let coord = parseDecimalCoords(trimmed) { return coord }

        // 格式2：带方向的十进制度数
        if let coord = parseDegreeCoords(trimmed) { return coord }

        // 格式3：度分秒 DMS
        if let coord = parseDMSCoords(trimmed) { return coord }

        return nil
    }

    /// "39.9042, 116.4074" 或 "39.9042 116.4074"
    private static func parseDecimalCoords(_ text: String) -> DetectedContent? {
        // 先尝试逗号分隔
        let commaParts = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if commaParts.count == 2,
           let a = Double(commaParts[0]), let b = Double(commaParts[1]) {
            if abs(a) <= 90 && abs(b) <= 180 { return .geoCoordinate(a, b) }
            if abs(b) <= 90 && abs(a) <= 180 { return .geoCoordinate(b, a) }
        }

        // 再尝试空格分隔
        let spaceParts = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        if spaceParts.count == 2,
           let a = Double(spaceParts[0]), let b = Double(spaceParts[1]) {
                // 判断哪个是纬度哪个是经度
                if abs(a) <= 90 && abs(b) <= 180 {
                    return .geoCoordinate(a, b)
                }
                if abs(b) <= 90 && abs(a) <= 180 {
                    return .geoCoordinate(b, a)
                }
            }
        return nil
    }

    /// "39.9042°N, 116.4074°E"
    private static func parseDegreeCoords(_ text: String) -> DetectedContent? {
        let pattern = "([0-9.]+)\\s*°?\\s*([NnSs]),?\\s*([0-9.]+)\\s*°?\\s*([EeWw])"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 5 else { return nil }

        let latStr = String(text[Range(match.range(at: 1), in: text)!])
        let latDir = String(text[Range(match.range(at: 2), in: text)!]).uppercased()
        let lngStr = String(text[Range(match.range(at: 3), in: text)!])
        let lngDir = String(text[Range(match.range(at: 4), in: text)!]).uppercased()

        guard var lat = Double(latStr), var lng = Double(lngStr) else { return nil }
        if latDir == "S" { lat = -lat }
        if lngDir == "W" { lng = -lng }
        guard abs(lat) <= 90 && abs(lng) <= 180 else { return nil }

        return .geoCoordinate(lat, lng)
    }

    /// "39°54'15\"N, 116°23'27\"E"
    private static func parseDMSCoords(_ text: String) -> DetectedContent? {
        let number = "([0-9.]+)"
        let pattern = "\(number)°\\s*\(number)'\\s*\(number)\"?\\s*([NnSs])\\s*,?\\s*\(number)°\\s*\(number)'\\s*\(number)\"?\\s*([EeWw])"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 9 else { return nil }

        let extracts: [Double] = (1...6).compactMap { i in
            let r = match.range(at: i)
            return Double(String(text[Range(r, in: text)!]))
        }
        guard extracts.count == 6 else { return nil }

        let latDir = String(text[Range(match.range(at: 7), in: text)!]).uppercased()
        let lngDir = String(text[Range(match.range(at: 8), in: text)!]).uppercased()

        var lat = extracts[0] + extracts[1] / 60 + extracts[2] / 3600
        var lng = extracts[3] + extracts[4] / 60 + extracts[5] / 3600
        if latDir == "S" { lat = -lat }
        if lngDir == "W" { lng = -lng }
        guard abs(lat) <= 90 && abs(lng) <= 180 else { return nil }

        return .geoCoordinate(lat, lng)
    }

    private static func detectDatetime(_ text: String) -> DetectedContent? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: text) {
                return .datetime(date, text)
            }
        }
        return nil
    }

    // MARK: - 中国地址识别

    /// 省/直辖市关键词
    private static let provinceKeys = [
        "北京", "天津", "上海", "重庆",
        "河北", "山西", "辽宁", "吉林", "黑龙江",
        "江苏", "浙江", "安徽", "福建", "江西", "山东",
        "河南", "湖北", "湖南", "广东", "海南",
        "四川", "贵州", "云南", "陕西", "甘肃", "青海",
        "台湾", "内蒙古", "广西", "西藏", "宁夏", "新疆",
        "香港", "澳门",
    ]

    /// 市/区/县/街道/路/号等地址特征词
    private static let addressKeys = [
        "市", "区", "县", "镇", "乡", "村",
        "街道", "路", "街", "巷", "弄", "里",
        "号", "楼", "栋", "单元", "室", "层",
        "大道", "大街", "胡同",
    ]

    private static func detectAddress(_ text: String) -> DetectedContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 太短的不可能是地址
        guard trimmed.count >= 6 else { return nil }

        var score = 0

        // 含省/直辖市名
        for p in provinceKeys {
            if trimmed.contains(p) { score += 2; break }
        }

        // 含市/区/县等等级词
        var addrKeyCount = 0
        for k in addressKeys {
            if trimmed.contains(k) { addrKeyCount += 1 }
        }
        // 需要至少 2 个地址特征词
        if addrKeyCount >= 2 { score += 2 }
        else if addrKeyCount >= 1 { score += 1 }

        // 地址通常较长
        if trimmed.count >= 15 { score += 1 }

        // 总分达标则认为是地址
        if score >= 3 {
            return .address(trimmed)
        }
        return nil
    }
}

// MARK: - NSRegularExpression Range 辅助

private extension String {
    subscript(_ nsRange: NSRange) -> String {
        let r = Range(nsRange, in: self) ?? startIndex..<startIndex
        return String(self[r])
    }
}
