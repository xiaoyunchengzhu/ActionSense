import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 工作模式枚举

enum PasteMode: String, CaseIterable {
    case disabled   // 停用
    case plainText  // 纯文本模式
    case pasteFlow  // PasteFlow 智能识别

    var displayName: String {
        switch self {
        case .disabled:  return "停用"
        case .plainText: return "纯文本模式"
        case .pasteFlow: return "PasteFlow"
        }
    }

    var menuBarIcon: String {
        switch self {
        case .disabled:  return "clipboard"
        case .plainText: return "list.clipboard"
        case .pasteFlow: return "sparkles"
        }
    }
}

// MARK: - 核心 ViewModel，管理剪贴板监听、格式纯化和状态

@MainActor
final class PurePasteViewModel: ObservableObject {

    // MARK: - 发布的状态属性

    /// 当前工作模式
    @Published var mode: PasteMode = .pasteFlow

    /// 最近一次转换结果的预览（前 50 个字符）
    @Published var lastConversionPreview: String?

    /// 累计转换次数（用于试用逻辑中的"偶尔"提示）
    @Published var conversionCount: Int = 0

    /// 是否正在处理剪贴板（用于 UI 状态指示）
    @Published var isProcessing: Bool = false

    /// 本次会话中剪贴板内容是否非文本（用于提示用户）
    @Published var lastCopyWasNonText: Bool = false

    // MARK: - AppStorage 持久化属性

    /// 应用启动次数（模拟试用天数）
    @AppStorage("launchCount") var launchCount: Int = 0

    /// 是否已激活（购买解锁）
    @AppStorage("isActivated") var isActivated: Bool = false

    /// 是否开机启动
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            // 当开关变化时，注册/注销登录项
            Task { await updateLoginItem() }
        }
    }

    // MARK: - 私有属性：剪贴板监听

    /// 定时器，每 0.5 秒检查剪贴板变化
    private var monitorTimer: Timer?

    /// 上一次记录的剪贴板 changeCount，用于检测外部复制
    private var lastChangeCount: Int = 0

    /// 内部处理标志位：防止写回剪贴板时触发自身监听（避免死循环）
    private var internalWriteFlag: Bool = false

    // MARK: - 试用相关计算属性

    /// 试用是否已过期（启动次数 > 7 且未激活）
    var isTrialExpired: Bool {
        !isActivated && launchCount > 7
    }

    /// PasteFlow 模式是否可用（激活 或 试用期内）
    var isPasteFlowAvailable: Bool {
        isActivated || !isTrialExpired
    }

    // MARK: - 初始化

    init() {
        // 每次启动递增计数
        launchCount += 1
        // 启动剪贴板监听
        startMonitoring()
        // 同步登录项状态
        Task { await syncLoginItemState() }
    }

    deinit {
        // Timer.invalidate() 是线程安全的，可以直接在 deinit 中调用
        monitorTimer?.invalidate()
    }

    // MARK: - 剪贴板监听

    /// 启动剪贴板变化监听（每 0.5 秒轮询 changeCount）
    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
            }
        }
        // 确保定时器在 RunLoop 的 common modes 下运行（包括菜单跟踪模式）
        if let timer = monitorTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// 停止剪贴板监听
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - 剪贴板检查与处理（核心逻辑）

    /// 检查剪贴板是否有新内容，如果有则进行格式纯化
    ///
    /// **避免死循环的关键设计：**
    /// 1. `internalWriteFlag`：处理前检查，如果为 true 说明是自身写入触发的变化，直接跳过
    /// 2. `lastChangeCount`：写入后立即更新为当前的 changeCount，下一次轮询时会发现值相同而跳过
    /// 3. 非文本内容（图片、文件等）直接忽略，不做任何操作
    private func checkClipboard() {
        // 关键：如果是自身写入触发的变化，跳过，避免死循环
        guard !internalWriteFlag else { return }

        // 停用模式下不做任何处理
        guard mode != .disabled else { return }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // changeCount 未变，说明没有新的复制操作
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 读取剪贴板中的字符串内容
        // 如果内容不是字符串（图片、文件等），string(forType:) 返回 nil，直接忽略
        guard let plainString = pasteboard.string(forType: .string) else {
            lastCopyWasNonText = true
            return
        }

        lastCopyWasNonText = false

        // PasteFlow 模式：识别内容类型并弹出浮动操作面板
        if mode == .pasteFlow, isPasteFlowAvailable {
            isProcessing = true
            let htmlData = pasteboard.data(forType: .html)
            let detected = ContentDetector.detect(plainString, hasHTML: htmlData != nil, htmlData: htmlData)
            if let detected = detected {
                let mouseLocation = NSEvent.mouseLocation
                FloatingPanelController.shared.show(content: detected, at: mouseLocation)
                lastConversionPreview = "[\(detected.displayType)] \(String(detected.previewText.prefix(40)))"
                conversionCount += 1
                // 记录历史：已识别
                HistoryStore.shared.addEntry(text: plainString, mode: "pasteFlow", detectedType: detected.displayType)
            } else {
                // 记录历史：未识别
                HistoryStore.shared.addEntry(text: plainString, mode: "pasteFlow", detectedType: nil)
            }
            lastChangeCount = pasteboard.changeCount
            isProcessing = false
            return
        }

        // 纯文本模式：格式净化后写回剪贴板
        isProcessing = true

        let processed = TextProcessor.plainText(plainString)

        // 写回剪贴板前设置标志位，防止触发自身监听
        internalWriteFlag = true
        pasteboard.clearContents()
        pasteboard.setString(processed, forType: .string)
        lastChangeCount = pasteboard.changeCount
        internalWriteFlag = false

        lastConversionPreview = String(processed.prefix(50))
        conversionCount += 1
        isProcessing = false
        // 记录历史：纯文本模式
        HistoryStore.shared.addEntry(text: plainString, mode: "plainText", detectedType: nil)
    }

    // MARK: - 模式切换

    /// 切换工作模式
    func switchMode(to newMode: PasteMode) {
        mode = newMode
        // 模式切换后重置 changeCount，避免立即处理上一个模式残留的变化
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - 激活（模拟购买）

    /// 模拟购买激活，切换激活状态
    func toggleActivation() {
        isActivated.toggle()
    }

    /// 打开购买页面 URL
    func openBuyPage() {
        if let url = URL(string: "https://yourdomain.com/buy") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 开机启动管理

    /// 判断当前运行环境能否操作登录项
    /// SMAppService 要求 App 位于 /Applications 且具有有效签名；
    /// Xcode 调试构建或非 /Applications 路径下必定失败
    private var canManageLoginItem: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix("/System/Applications/")
    }

    /// 更新登录项注册状态
    func updateLoginItem() async {
        // 开发环境下直接跳过，避免无意义的 Operation not permitted 错误
        guard canManageLoginItem else { return }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch {
            // 注册失败回退开关状态
            await MainActor.run {
                launchAtLogin = false
                print("PurePaste: 开机启动设置失败 - \(error.localizedDescription)")
            }
        }
    }

    /// 同步当前登录项的实际状态
    private func syncLoginItemState() async {
        // 开发环境下跳过，避免不必要的 SMAppService 调用
        guard canManageLoginItem else { return }

        let status = SMAppService.mainApp.status
        await MainActor.run {
            switch status {
            case .enabled:
                launchAtLogin = true
            default:
                launchAtLogin = false
            }
        }
    }

    // MARK: - 试用提示判断

    /// 是否应该在菜单中显示购买提示
    /// 试用过期后，每 5 次转换或在智能模式下被拒绝时显示
    var shouldShowBuyPrompt: Bool {
        guard isTrialExpired else { return false }
        return conversionCount % 5 == 0
    }
}
