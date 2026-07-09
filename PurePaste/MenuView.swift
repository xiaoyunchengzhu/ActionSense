import SwiftUI

// MARK: - 菜单栏弹出菜单视图

struct MenuView: View {
    @EnvironmentObject var viewModel: PurePasteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ---- 当前状态 ----
            statusHeader

            Divider()

            // ---- 模式选择（互斥勾选） ----
            modeSelectionSection

            Divider()

            // ---- 最近一次转换预览 ----
            conversionPreviewSection

            Divider()

            // ---- 偏好设置 ----
            preferencesSection

            Divider()

            // ---- 试用 / 购买 ----
            if !viewModel.isActivated {
                trialSection
                Divider()
            }

            // ---- 历史记录 ----
            Divider()
            historyButton

            // ---- 使用帮助 ----
            helpButton

            // ---- 关于 ----
            aboutButton

            // ---- 退出 ----
            quitButton
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }

    // MARK: - 状态头部

    private var statusHeader: some View {
        HStack {
            Image(systemName: viewModel.mode.menuBarIcon)
                .foregroundColor(accentColor(for: viewModel.mode))
                .font(.title3)
            Text(L10n.aboutTitle)
                .font(.headline)
            Spacer()
            if viewModel.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 模式选择区域

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.Menu.modeSelection.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ForEach(PasteMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
    }

    /// 单个模式选择按钮
    @ViewBuilder
    private func modeButton(for mode: PasteMode) -> some View {
        let isSelected = viewModel.mode == mode
        let isDisabled = mode == .pasteFlow && !viewModel.isPasteFlowAvailable

        Button(action: {
            if mode == .pasteFlow && !viewModel.isPasteFlowAvailable {
                // 试用过期，智能模式不可用
                return
            }
            viewModel.switchMode(to: mode)
        }) {
            HStack(spacing: 8) {
                // 勾选标记
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .font(.system(size: 8))
                    .foregroundColor(isSelected ? accentColor(for: mode) : .secondary.opacity(0.4))

                // 模式图标
                Image(systemName: mode.menuBarIcon)
                    .frame(width: 18)
                    .foregroundColor(isDisabled ? .secondary.opacity(0.35) : accentColor(for: mode))

                // 模式名称
                Text(L10n.Mode(rawValue: mode.rawValue)!.text)
                    .font(.body)

                Spacer()

                // 试用限制标记
                if mode == .pasteFlow && !viewModel.isPasteFlowAvailable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }

    // MARK: - 最近转换预览

    @ViewBuilder
    private var conversionPreviewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Menu.recentConversion.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            if let preview = viewModel.lastConversionPreview {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(preview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(L10n.Menu.waitingFirstCopy.text)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }

            if viewModel.lastCopyWasNonText {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(L10n.Menu.lastCopyNonText.text)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - 偏好设置

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.Menu.preferences.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            Toggle(isOn: $viewModel.launchAtLogin) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .frame(width: 18)
                    Text(L10n.Menu.launchAtLogin.text)
                }
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            languagePicker
        }
    }

    // MARK: - 语言选择

    @AppStorage("preferredLanguage") private var preferredLanguage: String = L10n.Language.auto.rawValue

    private var languagePicker: some View {
        Picker(selection: $preferredLanguage) {
            ForEach(L10n.Language.allCases, id: \.rawValue) { lang in
                Text(lang.displayName).tag(lang.rawValue)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .frame(width: 18)
                Text(L10n.isChinese ? "语言" : "Language")
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - 试用 / 购买区域

    private var trialSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.isTrialExpired {
                // 试用已过期
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(L10n.Menu.trialExpired.text)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
            } else {
                // 试用期内
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                    Text(L10n.isChinese ? "试用中（剩余约 \(max(0, 7 - viewModel.launchCount)) 天）" : "Trial (\(max(0, 7 - viewModel.launchCount)) days left)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }

            // 购买按钮
            Button(action: { viewModel.openBuyPage() }) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .frame(width: 18)
                    Text(L10n.Menu.buyActivate.text)
                    Spacer()
                    Text("$9.99")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 测试用：模拟激活切换
            #if DEBUG
            Button(action: { viewModel.toggleActivation() }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isActivated ? "key.fill" : "key")
                        .frame(width: 18)
                    Text(viewModel.isActivated ? L10n.Menu.cancelActivate.text : L10n.Menu.simulateActivate.text)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(.vertical, 6)
    }

    // MARK: - 历史记录按钮

    private var historyButton: some View {
        Button(action: { HistoryWindowController.shared.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: 18)
                Text(L10n.Menu.clipboardHistory.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 使用帮助按钮

    private var helpButton: some View {
        Button(action: { showHelpDialog() }) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .frame(width: 18)
                Text(L10n.Menu.help.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 关于按钮

    private var aboutButton: some View {
        Button(action: { showAboutDialog() }) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .frame(width: 18)
                Text(L10n.Menu.about.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 退出按钮

    private var quitButton: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.square")
                    .frame(width: 18)
                Text(L10n.Menu.quit.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    // MARK: - 辅助方法

    /// 根据当前模式返回强调色
    private func accentColor(for mode: PasteMode) -> Color {
        switch mode {
        case .disabled:      return .gray
        case .plainText:     return .blue
        case .pasteFlow: return .teal
        }
    }

    /// 显示使用帮助对话框
    private func showHelpDialog() {
        let alert = NSAlert()
        alert.messageText = L10n.helpTitle
        alert.informativeText = L10n.helpText
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.helpButton)
        alert.icon = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help")
        alert.runModal()
    }

    /// 显示"关于"对话框
    private func showAboutDialog() {
        let alert = NSAlert()
        alert.messageText = "PurePaste"
        alert.informativeText = "\(L10n.Menu.version.text)\n\n\(L10n.aboutText)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.isChinese ? "确定" : "OK")
        alert.icon = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "PurePaste")
        alert.runModal()
    }
}

// MARK: - 预览

#Preview {
    MenuView()
        .environmentObject(PurePasteViewModel())
}
