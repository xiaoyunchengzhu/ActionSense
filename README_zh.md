<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://www.xiaoniubuniu.com/products/pure-paste/"><img src="https://img.shields.io/badge/下载-xiaoniubuniu.com-ff69b4" alt="Download"></a>
</p>

<p align="center"><b>中文</b> | <a href="README.md">English</a></p>

# PurePaste

<p align="center"><b>macOS 智能剪贴板助手</b> — 不只是净化格式，更是理解你的复制意图。</p>

<p align="center">
  <a href="https://www.xiaoniubuniu.com/products/pure-paste/">产品页 & 下载</a>
</p>

---

## PurePaste 是什么？

PurePaste 是一个 macOS 菜单栏应用，常驻右上角，监听剪贴板变化。两个核心模式：

- **纯文本模式** — 自动剥离富文本格式，清理多余空白和 CJK 空格
- **PasteFlow 模式** — 识别复制内容的类型（URL / 邮箱 / 颜色 / 数学…），在鼠标旁弹出浮动面板，一键操作

所有处理在本地完成，数据永不上传。

## 功能详情

### PasteFlow — 意图识别

复制内容后自动检测类型，弹出对应操作：

| 类型 | 示例 | 操作 |
|------|------|------|
| 链接 | `https://github.com` | 浏览器打开 |
| 邮箱 | `hello@example.com` | 写邮件 |
| 电话 | `13812345678` | 拨打电话 |
| 地址 | `北京市海淀区中关村南大街5号` | 地图查看 |
| IP | `192.168.1.1` | Ping |
| 颜色 | `#FF5733` / `rgb(255,87,51)` | 复制 HEX / 复制 RGB |
| 日期 | `2024-01-15 14:00` | 添加到日历 |
| 数学 | `(35+47)*1.2` | 复制结果（自研递归下降计算器） |
| 经纬度 | `39.9042, 116.4074` | 地图定位 |
| 快递 | `SF123456789012` | 查快递 |
| 富文本 | 网页复制带格式 | 转为 Markdown / 转为纯文本 |

- 单按钮面板：<kbd>Enter</kbd> 直接触发
- <kbd>Esc</kbd> 或点击面板外部关闭

### 纯文本模式

去除 RTF/HTML 格式，合并多余换行，移除 CJK 字符间多余空格，压缩连续空白。英文单词空格保留。

### 意图历史

每条剪贴板记录带完整元数据：
- 🟢 意图已完成（有操作）
- 🟠 已识别但未操作
- ⚪ 普通复制 / 未识别

支持按类型、模式、关键词筛选。最大 5000 条，本地 JSON 存储。

## 截图

> *此处放演示 GIF。建议 30 秒录屏：复制 URL → 弹窗 → 浏览器打开；复制颜色 → 面板预览 → 复制 HEX；打开历史窗口 → 按类型筛选。*

## 安装

**方式一：源码编译（免费，无需 Apple Developer）**
```bash
git clone https://github.com/xiaoyunchengzhu/PurePaste.git
cd PurePaste
open PurePaste.xcodeproj
# Cmd+R 运行
```

**方式二：下载 DMG**
从 [xiaoniubuniu.com/products/pure-paste](https://www.xiaoniubuniu.com/products/pure-paste/) 下载最新版，拖到 `/Applications`。首次打开右键 → 打开，跳过 Gatekeeper。

## 项目结构

```
PurePaste/
├── PurePasteApp.swift              # MenuBarExtra 入口
├── PurePasteViewModel.swift        # 剪贴板轮询 + 模式状态
├── MenuView.swift                  # 菜单栏下拉 UI
├── TextProcessor.swift             # 纯文本 / HTML→Markdown
├── ContentDetector.swift           # 11 种类型识别引擎
├── ActionExecutor.swift            # 操作分发执行
├── FloatingPanelView.swift         # SwiftUI 浮动面板
├── FloatingPanelController.swift   # NSWindow 管理器
├── HistoryEntry.swift              # 历史数据模型
├── HistoryStore.swift              # JSON 持久化 + 筛选
├── HistoryView.swift               # 搜索 + 过滤 UI
├── HistoryWindowController.swift   # 历史记录窗口
└── Info.plist
```

核心设计：

- **死循环防护**：`internalWriteFlag` + `lastChangeCount` 双重守卫
- **数学计算器**：手写递归下降解析器，避开 `NSExpression` 格式字符串陷阱
- **浮动面板**：`NSWindow.borderless` + `.nonactivatingPanel`，鼠标旁弹出不抢焦点
- **历史存储**：内存过滤 + JSON 文件，无数据库依赖

## 技术栈

SwiftUI · AppKit · MenuBarExtra · NSPasteboard · Combine · SMAppService

## 许可证

MIT — 详见 [LICENSE](LICENSE)。
