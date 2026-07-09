import SwiftUI
import AppKit

// MARK: - PasteFlow 浮动面板窗口管理器

/// 管理浮动面板 NSWindow 的生命周期：创建、定位、显示、关闭
/// 使用单例模式，全局只有一个浮动面板实例
@MainActor
final class FloatingPanelController {
    static let shared = FloatingPanelController()

    /// 当前显示的浮动窗口
    private var panel: NSWindow?

    /// 监听外部点击/按键，用于自动关闭
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    /// KvRlYG2IXqgl：面板是否正在显示
    var isShowing: Bool { panel != nil }

    private init() {}

    // MARK: - 显示面板

    /// 在指定屏幕坐标显示内容识别面板
    /// - Parameters:
    ///   - content: 识别到的内容类型
    ///   - screenPoint: 鼠标所在屏幕坐标（NSEvent.mouseLocation）
    func show(content: DetectedContent, at screenPoint: NSPoint) {
        // 先关闭旧面板
        dismiss()

        // 头部 56 + 分隔线 1 + 预览 52 + 分隔线 1 + 按钮 80 + 间距
        let panelHeight: CGFloat = 56 + 1 + 52 + 1 + 78 + 8
        let panelWidth: CGFloat = 280

        // 创建无边框浮动窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 窗口外观配置
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        // 嵌入 SwiftUI 视图
        let hostingView = NSHostingView(
            rootView: FloatingPanelView(
                content: content,
                onAction: { [weak self] action in
                    self?.dismiss()
                    ActionExecutor.execute(action: action, content: content)
                    HistoryStore.shared.markLastIntentFulfilled(action: action.displayName)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                }
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView

        // 定位面板：鼠标右下偏移，同时处理屏幕边界
        let panelFrame = calculatePanelFrame(
            screenPoint: screenPoint,
            panelSize: NSSize(width: panelWidth, height: panelHeight)
        )
        window.setFrame(panelFrame, display: true)

        // 显示窗口（不抢夺焦点）
        window.orderFrontRegardless()

        // 添加淡入动画
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }

        // 监听 Esc 键关闭
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.dismiss()
                return nil // 消费事件
            }
            return event
        }

        // 监听外部鼠标点击关闭（延迟添加避免立即触发）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let panel = self.panel else { return }
                // 检查点击是否在面板外部
                let clickLocation = NSEvent.mouseLocation
                let panelGlobalFrame = self.convertToScreen(panel.frame)
                if !NSPointInRect(clickLocation, panelGlobalFrame) {
                    self.dismiss()
                }
            }
        }

        self.panel = window
    }

    // MARK: - 关闭面板

    func dismiss() {
        removeEventMonitors()

        guard let panel = panel else { return }
        self.panel = nil

        // 淡出动画后关闭
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.close()
        })
    }

    // MARK: - 辅助

    private func removeEventMonitors() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    /// 将窗口坐标转换为屏幕坐标（NSWindow frame 已在屏幕坐标系，直接返回）
    private func convertToScreen(_ windowFrame: NSRect) -> NSRect {
        return windowFrame
    }

    /// 计算面板在屏幕上的合适位置（避免超出屏幕边界）
    private func calculatePanelFrame(screenPoint: NSPoint, panelSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: NSPoint(x: screenPoint.x + 12, y: screenPoint.y - panelSize.height), size: panelSize)
        }

        let screenFrame = screen.visibleFrame
        let offset: CGFloat = 16 // 与鼠标的间距

        // 默认位置：鼠标右下
        var originX = screenPoint.x + offset
        var originY = screenPoint.y - panelSize.height - 8

        // 右边超出 → 放到鼠标左侧
        if originX + panelSize.width > screenFrame.maxX {
            originX = screenPoint.x - panelSize.width - offset
        }
        // 左边超出
        if originX < screenFrame.minX {
            originX = screenFrame.minX + offset
        }
        // 下方超出 → 放到鼠标上方
        if originY < screenFrame.minY {
            originY = screenPoint.y + offset
        }
        // 上方超出
        if originY + panelSize.height > screenFrame.maxY {
            originY = screenFrame.maxY - panelSize.height - offset
        }

        return NSRect(x: originX, y: originY, width: panelSize.width, height: panelSize.height)
    }
}
