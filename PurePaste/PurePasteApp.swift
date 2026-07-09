import SwiftUI
import AppKit

// MARK: - AppDelegate，在正确的生命周期节点做初始化

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保不显示 Dock 图标（双重保险，配合 Info.plist 中的 LSUIElement）
        NSApp.setActivationPolicy(.accessory)

        // 明显的启动标记，方便在控制台噪音中找到
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  ✅ PurePaste 已启动")
        print("  📋 查看屏幕右上角菜单栏的剪贴板图标")
        print("  \(L10n.startupMessage)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// MARK: - PurePaste 应用入口
// 使用 MenuBarExtra 构建原生菜单栏应用，无 Dock 图标，无主窗口

@main
struct PurePasteApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 全局 ViewModel，管理剪贴板监听和状态
    @StateObject private var viewModel = PurePasteViewModel()

    var body: some Scene {
        MenuBarExtra {
            // 弹出菜单内容
            MenuView()
                .environmentObject(viewModel)
        } label: {
            // 菜单栏图标：根据当前模式显示不同图标和颜色
            Image(systemName: viewModel.mode.menuBarIcon)
                .foregroundColor(menuBarTint)
        }
    }

    /// 菜单栏图标颜色：根据模式 + 是否有待处理内容动态变化
    private var menuBarTint: Color {
        switch viewModel.mode {
        case .disabled:
            return .gray
        case .plainText:
            return .blue
        case .pasteFlow:
            return .teal
        }
    }
}
