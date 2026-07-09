import SwiftUI

// MARK: - PasteFlow 浮动操作面板（SwiftUI 视图，由 NSHostingView 嵌入 NSWindow）

struct FloatingPanelView: View {
    let content: DetectedContent
    let onAction: (PasteFlowAction) -> Void
    let onDismiss: () -> Void

    @State private var hoveredAction: PasteFlowAction? = nil
    @State private var appeared = false

    private let actions: [PasteFlowAction]

    init(content: DetectedContent,
         onAction: @escaping (PasteFlowAction) -> Void,
         onDismiss: @escaping () -> Void) {
        self.content = content
        self.onAction = onAction
        self.onDismiss = onDismiss
        self.actions = PasteFlowAction.actions(for: content)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：图标 + 类型标签 + 关闭按钮
            headerView

            Divider()
                .opacity(0.3)

            // 中部：内容预览
            previewView

            // 底部：操作按钮
            actionButtons
        }
        .frame(width: 280)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        .onExitCommand {
            onDismiss()
        }
        .onKeyPress(.return) {
            // 只有一个操作时，Enter 直接触发
            guard actions.count == 1, let action = actions.first else {
                return .ignored
            }
            onAction(action)
            return .handled
        }
    }

    // MARK: - 顶部区域

    private var headerView: some View {
        HStack(spacing: 10) {
            // 类型图标
            Image(systemName: content.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            // 类型名称
            Text(content.displayType)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 预览区域

    @ViewBuilder
    private var previewView: some View {
        if case .color(let color, let hex) = content {
            // 颜色类型：放大色块 + HEX/RGB 详情
            colorPreviewView(color: color, hex: hex)
        } else {
            // 其他类型：文本预览
            textPreviewView
        }
    }

    /// 颜色专用预览：大色块 + 色值信息
    private func colorPreviewView(color: NSColor, hex: String) -> some View {
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        let rgbStr = "rgb(\(r), \(g), \(b))"

        return VStack(spacing: 10) {
            // 大色块
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: color))
                .frame(width: 80, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color(nsColor: color).opacity(0.4), radius: 8, y: 3)

            // 色值信息
            VStack(spacing: 3) {
                Text(hex)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                Text(rgbStr)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// 文本内容预览
    private var textPreviewView: some View {
        HStack(spacing: 0) {
            Text(content.previewText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 操作按钮区域

    private var actionButtons: some View {
        HStack(spacing: 8) {
            ForEach(actions, id: \.self) { action in
                actionButton(for: action)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func actionButton(for action: PasteFlowAction) -> some View {
        let isHovered = hoveredAction == action

        return Button(action: {
            onAction(action)
        }) {
            VStack(spacing: 6) {
                Image(systemName: action.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(isHovered ? .white : .accentColor)
                Text(action.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isHovered ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isHovered
                            ? Color.accentColor
                            : Color.accentColor.opacity(0.08)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredAction = hovering ? action : nil
            }
        }
    }

    // MARK: - 面板背景

    private var panelBackground: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
    }
}

// MARK: - NSVisualEffectView 桥接（毛玻璃效果）

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 预览

#Preview {
    FloatingPanelView(
        content: .url(URL(string: "https://github.com/example/project")!),
        onAction: { _ in },
        onDismiss: {}
    )
    .padding()
}
