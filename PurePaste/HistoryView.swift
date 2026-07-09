import SwiftUI

// MARK: - 剪贴板历史窗口

struct HistoryView: View {
    @ObservedObject var store = HistoryStore.shared
    @State private var hoveredEntryID: UUID? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            Divider()

            // 快速筛选标签
            filterTags

            Divider()

            // 列表
            entryList

            Divider()

            // 底部状态栏
            bottomBar
        }
        .frame(width: 380, height: 520)
        .background(.ultraThickMaterial)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(L10n.historySearchPlaceholder, text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
            if !store.searchText.isEmpty {
                Button(action: { store.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 筛选标签

    private var filterTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(HistoryStore.FilterMode.allCases, id: \.id) { mode in
                    filterChip(mode)
                }
                // 类型标签
                ForEach(store.allDetectedTypes, id: \.self) { type in
                    typeFilterChip(type)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(_ mode: HistoryStore.FilterMode) -> some View {
        let isActive = store.filterMode == mode && store.filterByType == nil
        return Button(action: {
            store.filterMode = mode
            store.filterByType = nil
        }) {
            Text(mode.rawValue)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func typeFilterChip(_ type: String) -> some View {
        let isActive = store.filterByType == type
        return Button(action: {
            store.filterByType = isActive ? nil : type
            store.filterMode = .all
        }) {
            Text(type)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 条目列表

    private var entryList: some View {
        let items = store.filteredEntries

        return Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: store.searchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(store.searchText.isEmpty ? L10n.historyNoRecords : L10n.historyNoMatch)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { entry in
                    entryRow(entry)
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowSeparator(.hidden)
                        .onHover { hovering in
                            hoveredEntryID = hovering ? entry.id : nil
                        }
                        .contextMenu {
                            Button(L10n.historyCopyText) {
                                copyToClipboard(entry.text)
                            }
                            Button(L10n.historyDeleteEntry) {
                                store.deleteEntry(entry)
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private func entryRow(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            // 状态指示圆点
            Circle()
                .fill(statusColor(entry))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                // 文本预览
                Text(entry.preview)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 元数据行
                HStack(spacing: 6) {
                    Text(entry.relativeTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if let type = entry.detectedType {
                        badge(type, color: .accentColor)
                    }

                    if let action = entry.action {
                        badge(action, color: .green)
                    }

                    if !entry.isIntentFulfilled && entry.detectedType != nil {
                        badge(L10n.historyNotActed, color: .orange)
                    }

                    Text(entry.mode)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hoveredEntryID == entry.id ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            copyToClipboard(entry.text)
        }
    }

    // MARK: - 底部状态栏

    private var bottomBar: some View {
        HStack {
            Button(action: {
                store.clearAll()
            }) {
                Text(L10n.historyClearAll)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(store.filteredEntries.count) / \(store.entries.count)" + (L10n.isChinese ? " 条" : " entries"))
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 辅助

    private func statusColor(_ entry: HistoryEntry) -> Color {
        if entry.isIntentFulfilled { return .green }
        if entry.detectedType != nil { return .orange }
        return .secondary.opacity(0.4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))
            )
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - 预览

#Preview {
    HistoryView()
}
