<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://www.xiaoniubuniu.com/products/pure-paste/"><img src="https://img.shields.io/badge/Download-xiaoniubuniu.com-ff69b4" alt="Download"></a>
</p>

<p align="center"><b>English</b> | <a href="README_zh.md">中文</a></p>

# PurePaste

<p align="center"><b>macOS Smart Clipboard Assistant</b> — understands what you copy, not just what it says.</p>

<p align="center">
  <a href="https://www.xiaoniubuniu.com/products/pure-paste/">Product Page & Download</a>
</p>

---

## What is PurePaste?

PurePaste is a macOS menu bar app that watches your clipboard and acts on what you copy. Two modes:

- **Plain Text Mode** — automatically strips rich formatting, cleans up whitespace and CJK spacing
- **PasteFlow Mode** — detects the *type* of content you copied (URL, email, color, math expression...) and pops up a floating action panel at your mouse cursor. One click or <kbd>Enter</kbd> to act.

All processing is local. Your clipboard never leaves your machine.

## Features

### PasteFlow — Intent-Aware Clipboard

When you copy something, PasteFlow detects what it is and offers relevant actions:

| Type | Example | Actions |
|------|---------|---------|
| URL | `https://www.xiaoniubuniu.com` | Open in Browser |
| Email | `xiaoyunchengzhu@gmail.com` | Compose Mail |
| Phone | `13812345678` | Call |
| Address | `北京市海淀区...` | Open in Maps |
| IP | `192.168.1.1` | Ping |
| Color | `#FF5733` / `rgb(255,87,51)` | Copy HEX / Copy RGB |
| Date/Time | `2024-01-15 14:00` | Add to Calendar |
| Math | `(35+47)*1.2` | Copy Result (custom recursive descent parser) |
| Coordinates | `39.9042, 116.4074` | Open in Maps |
| Tracking | `SF123456789012` | Track Package |
| Rich HTML | Web content with formatting | Convert to Markdown / Plain Text |

- <kbd>Enter</kbd> triggers the action directly when there's only one button
- <kbd>Esc</kbd> or click outside to dismiss

### Plain Text Mode

Strips RTF/HTML formatting, collapses excess newlines, removes unnecessary spaces between CJK characters, compresses multiple spaces into one. Keeps English word spacing intact.

### Intent History

Every clipboard change is recorded with metadata:
- 🟢 Intent fulfilled (action taken)
- 🟠 Detected but not acted upon
- ⚪ Plain text / unrecognized

Filter by type, mode, or keyword. Search across up to 5000 entries. All stored locally at `~/Library/Application Support/PurePaste/history.json`.

## Screenshot

![PurePaste Demo](screenshot/demo.gif)

### PasteFlow — Smart Detection

| URL Detection | Color Preview | Math Calculation |
|:---:|:---:|:---:|
| ![URL](screenshot/url-detect.png) | ![Color](screenshot/color-detect.png) | ![Math](screenshot/math-detect.png) |

### Intent History

![History](screenshot/history.png)

## Installation

**Option 1: Build from Source (free, no Apple Developer account needed)**
```bash
git clone https://github.com/xiaoyunchengzhu/PurePaste.git
cd PurePaste
open PurePaste.xcodeproj
# Cmd+R to run
```

**Option 2: Download DMG**
Download the latest build from [xiaoniubuniu.com/products/pure-paste](https://www.xiaoniubuniu.com/products/pure-paste/), drag to `/Applications`. Right-click → Open on first launch to bypass Gatekeeper.

## Architecture

```
PurePaste/
├── PurePasteApp.swift              # MenuBarExtra entry point
├── PurePasteViewModel.swift        # Clipboard polling + mode state
├── MenuView.swift                  # Menu bar dropdown UI
├── TextProcessor.swift             # Plain text / HTML→Markdown
├── ContentDetector.swift           # 11-type recognition engine
├── ActionExecutor.swift            # Action dispatcher
├── FloatingPanelView.swift         # SwiftUI floating panel
├── FloatingPanelController.swift   # NSWindow manager
├── HistoryEntry.swift              # History data model
├── HistoryStore.swift              # JSON persistence + filter
├── HistoryView.swift               # Search + filter UI
├── HistoryWindowController.swift   # History window
└── Info.plist
```

Key design decisions:

- **Dead-loop prevention**: `internalWriteFlag` + `lastChangeCount` dual guard in clipboard polling
- **Math evaluator**: hand-written recursive descent parser (avoids `NSExpression` format-string traps)
- **Floating panel**: `NSWindow.borderless` + `.nonactivatingPanel` — appears near cursor without stealing focus
- **History**: in-memory filtering on JSON-loaded entries, no database dependency

## Tech Stack

SwiftUI · AppKit · MenuBarExtra · NSPasteboard · Combine · SMAppService

## License

MIT — see [LICENSE](LICENSE).
