import Foundation

// MARK: - 剪贴板历史条目

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let mode: String           // plainText / pasteFlow
    let detectedType: String?   // PasteFlow 识别类型名，nil = 未识别
    let action: String?         // 用户执行的操作名，nil = 未操作
    let isIntentFulfilled: Bool // 是否完成了意图动作

    init(text: String, mode: String, detectedType: String?, action: String? = nil, isIntentFulfilled: Bool = false) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.mode = mode
        self.detectedType = detectedType
        self.action = action
        self.isIntentFulfilled = isIntentFulfilled
    }

    /// 用于列表展示的简短预览（前 80 字符，取第一行）
    var preview: String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        return String(firstLine.prefix(80))
    }

    /// 相对时间描述
    var relativeTime: String {
        let interval = Date().timeIntervalSince(timestamp)
        switch interval {
        case ..<60:   return "刚刚"
        case ..<300:  return "\(Int(interval / 60)) 分钟前"
        case ..<3600: return "\(Int(interval / 60)) 分钟前"
        case ..<86400: return "\(Int(interval / 3600)) 小时前"
        default:       return "\(Int(interval / 86400)) 天前"
        }
    }
}
