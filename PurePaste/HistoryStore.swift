import Foundation

// MARK: - 剪贴板历史存储（单例，内存常驻，JSON 持久化）

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published var entries: [HistoryEntry] = []
    @Published var searchText: String = ""
    @Published var filterMode: FilterMode = .all

    private let maxEntries = 5000
    private let fileURL: URL

    enum FilterMode: String, CaseIterable {
        case all = "全部"
        case intentFulfilled = "意图"
        case detectedOnly = "识别"
        case unrecognized = "未识别"
        case plainText = "纯文本"

        var id: String { rawValue }
    }

    /// 按类型名过滤（URL / 邮箱 / 颜色 / …），nil 表示不限
    @Published var filterByType: String? = nil

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PurePaste")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        let tail = entries.suffix(maxEntries)
        if tail.count != entries.count { entries = Array(tail) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 添加

    func addEntry(text: String, mode: String, detectedType: String?) {
        let entry = HistoryEntry(text: text, mode: mode, detectedType: detectedType)
        entries.append(entry)
        save()
    }

    /// 将最近一条匹配的记录标记为意图已完成
    func markLastIntentFulfilled(action: String) {
        guard let idx = entries.lastIndex(where: { !$0.isIntentFulfilled && $0.detectedType != nil }) else { return }
        let prev = entries[idx]
        entries[idx] = HistoryEntry(
            text: prev.text,
            mode: prev.mode,
            detectedType: prev.detectedType,
            action: action,
            isIntentFulfilled: true
        )
        save()
    }

    // MARK: - 筛选

    var filteredEntries: [HistoryEntry] {
        var result = entries

        // 模式筛选
        switch filterMode {
        case .all:
            break
        case .intentFulfilled:
            result = result.filter { $0.isIntentFulfilled }
        case .detectedOnly:
            result = result.filter { $0.detectedType != nil }
        case .unrecognized:
            result = result.filter { $0.detectedType == nil }
        case .plainText:
            result = result.filter { $0.mode == "plainText" }
        }

        // 类型筛选
        if let type = filterByType {
            result = result.filter { $0.detectedType == type }
        }

        // 关键词搜索
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { $0.text.lowercased().contains(query) }
        }

        return result.reversed() // 最新在上
    }

    /// 所有出现过的类型名（用于类型筛选标签）
    var allDetectedTypes: [String] {
        let types = Set(entries.compactMap { $0.detectedType })
        return types.sorted()
    }

    // MARK: - 管理

    func deleteEntry(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }
}
