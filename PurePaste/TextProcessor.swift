import Foundation

// MARK: - 文本处理器，负责剪贴板内容的格式纯化
// 所有处理均在本地完成，数据永不上传
enum TextProcessor {

    // MARK: - 纯文本模式处理

    /// 纯文本模式：移除富文本格式，清理多余空白，移除 CJK 字符间不必要的空格
    static func plainText(_ input: String) -> String {
        var result = input

        // 1. 去除首尾空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. 将连续两个以上的换行替换为一个换行
        //    先统一各种换行符为 \n
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        //    将 2+ 个连续 \n 替换为单个 \n
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        let collapsePattern = "\n{3,}"
        if let regex = try? NSRegularExpression(pattern: collapsePattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n\n")
        }

        // 3. 移除 CJK 字符间不必要的空格，但保留英文单词间的单个空格
        result = removeCJKSpaces(result)

        // 4. 压缩多个连续空格为一个
        let multiSpacePattern = " {2,}"
        if let regex = try? NSRegularExpression(pattern: multiSpacePattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }

        // 5. 清理每行首尾空白
        let lines = result.components(separatedBy: "\n")
        result = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")

        return result
    }

    // MARK: - HTML → Markdown 转换（供 PasteFlow 使用）

    /// 将剪贴板中的 HTML 数据转换为 Markdown 格式
    /// - Parameters:
    ///   - htmlData: 剪贴板中的 HTML 原始数据
    ///   - plainText: 剪贴板中的纯文本（兜底用）
    /// - Returns: 转换后的 Markdown 文本
    static func smartMarkdown(htmlData: Data, fallbackText: String) -> String {
        // 尝试从 Apple 剪贴板 HTML 格式中提取实际 HTML 片段
        if let rawHTML = String(data: htmlData, encoding: .utf8) {
            let fragmentHTML = extractAppleFragmentHTML(rawHTML)
            let markdown = htmlToMarkdown(fragmentHTML)
            // 如果 HTML 转换结果为空或仅包含空白，回退到纯文本
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return plainText(fallbackText)
            }
            // 对转换后的 Markdown 也进行空白清理
            return plainText(markdown)
        }

        // 无法解析 HTML，回退到纯文本模式
        return plainText(fallbackText)
    }

    // MARK: - Apple 剪贴板 HTML 格式解析

    /// 从 Apple 剪贴板 HTML 格式中提取实际的 HTML 片段
    /// Apple 剪贴板 HTML 格式包含一个头部，记录了各部分的字节偏移量：
    /// ```
    /// Version:1.0
    /// StartHTML:0000000105
    /// EndHTML:0000000522
    /// StartFragment:0000000466
    /// EndFragment:0000000486
    /// <html>...<!--StartFragment-->content<!--EndFragment-->...</html>
    /// ```
    private static func extractAppleFragmentHTML(_ clipboardHTML: String) -> String {
        // 方法1：通过头部字节偏移量精确提取
        let lines = clipboardHTML.components(separatedBy: .newlines)
        var startFragment = 0
        var endFragment = 0

        for line in lines {
            if line.hasPrefix("StartFragment:") {
                let val = line.replacingOccurrences(of: "StartFragment:", with: "")
                startFragment = Int(val) ?? 0
            } else if line.hasPrefix("EndFragment:") {
                let val = line.replacingOccurrences(of: "EndFragment:", with: "")
                endFragment = Int(val) ?? 0
            }
            // 遇到 <html 开头的行说明头部结束，不需要继续扫描
            if line.hasPrefix("<") && startFragment > 0 && endFragment > 0 {
                break
            }
        }

        if startFragment > 0 && endFragment > startFragment {
            let utf8Bytes = Array(clipboardHTML.utf8)
            if endFragment <= utf8Bytes.count {
                let fragmentBytes = utf8Bytes[startFragment..<min(endFragment, utf8Bytes.count)]
                if let fragment = String(bytes: fragmentBytes, encoding: .utf8), !fragment.isEmpty {
                    return fragment
                }
            }
        }

        // 方法2：通过注释标记提取（兜底方案）
        if let startRange = clipboardHTML.range(of: "<!--StartFragment-->"),
           let endRange = clipboardHTML.range(of: "<!--EndFragment-->") {
            let content = String(clipboardHTML[startRange.upperBound..<endRange.lowerBound])
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
        }

        // 方法3：提取 <body> 标签内容
        if let bodyStart = clipboardHTML.range(of: "<body[^>]*>", options: .regularExpression),
           let bodyEnd = clipboardHTML.range(of: "</body>") {
            return String(clipboardHTML[bodyStart.upperBound..<bodyEnd.lowerBound])
        }

        // 最终兜底：返回原始 HTML，交由 htmlToMarkdown 处理
        return clipboardHTML
    }

    // MARK: - HTML 到 Markdown 转换

    /// 将 HTML 片段转换为 Markdown 格式
    private static func htmlToMarkdown(_ html: String) -> String {
        var result = html

        // 1. <a href="url">text</a> → [text](url)
        if let regex = try? NSRegularExpression(
            pattern: "<a\\s+[^>]*href\\s*=\\s*\"([^\"]*)\"[^>]*>\\s*(.*?)\\s*</a\\s*>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[$2]($1)")
        }

        // 2. <strong> / <b> → **text**
        if let regex = try? NSRegularExpression(
            pattern: "<(strong|b)\\s*>\\s*(.*?)\\s*</(strong|b)\\s*>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "**$2**")
        }

        // 3. <em> / <i> → *text*
        if let regex = try? NSRegularExpression(
            pattern: "<(em|i)\\s*>\\s*(.*?)\\s*</(em|i)\\s*>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "*$2*")
        }

        // 4. <li> → - （无序列表项）
        if let regex = try? NSRegularExpression(
            pattern: "<li\\s*>\\s*",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "- ")
        }
        // 闭合 </li> 替换为换行
        if let regex = try? NSRegularExpression(
            pattern: "\\s*</li\\s*>",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n")
        }

        // 5. <br> / <br/> → \n
        if let regex = try? NSRegularExpression(
            pattern: "<br\\s*/?\\s*>",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n")
        }

        // 6. <p> 开始标签 → 空行（段落分隔）
        if let regex = try? NSRegularExpression(
            pattern: "<p[^>]*>\\s*",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // </p> → 换行
        if let regex = try? NSRegularExpression(
            pattern: "\\s*</p\\s*>",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n\n")
        }

        // 7. <h1> - <h6> → Markdown 标题
        for level in 1...6 {
            if let regex = try? NSRegularExpression(
                pattern: "<h\(level)[^>]*>\\s*(.*?)\\s*</h\(level)\\s*>",
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                let range = NSRange(result.startIndex..., in: result)
                let prefix = String(repeating: "#", count: level)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\(prefix) $1")
            }
        }

        // 8. 剥离其余所有 HTML 标签
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // 9. 解码常见 HTML 实体
        result = decodeHTMLEntities(result)

        return result
    }

    // MARK: - HTML 实体解码

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&#160;", " "),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // 处理十进制数字实体 &#NNNN;
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let numRange = match.matchRange(at: 1, in: result)
                let numStr = String(result[numRange])
                if let codePoint = UInt32(numStr),
                   let scalar = UnicodeScalar(codePoint) {
                    let replacement = String(scalar)
                    result.replaceSubrange(match.range(at: 0, in: result), with: replacement)
                }
            }
        }

        // 处理十六进制数字实体 &#xNNNN;
        if let regex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let numRange = match.matchRange(at: 1, in: result)
                let numStr = String(result[numRange])
                if let codePoint = UInt32(numStr, radix: 16),
                   let scalar = UnicodeScalar(codePoint) {
                    let replacement = String(scalar)
                    result.replaceSubrange(match.range(at: 0, in: result), with: replacement)
                }
            }
        }

        return result
    }

    // MARK: - CJK 空格清理

    /// 移除中/日/韩文字符之间不必要的空格，但保留英文单词间的空格
    ///
    /// 规则：如果空格两侧都是 CJK 字符，则移除该空格。
    /// 涉及的 Unicode 区间：
    /// - CJK 统一表意文字：U+4E00–U+9FFF
    /// - CJK 扩展 A：U+3400–U+4DBF
    /// - CJK 兼容区：U+F900–U+FAFF
    /// - 日文平假名：U+3040–U+309F
    /// - 日文片假名：U+30A0–U+30FF
    /// - 韩文音节：U+AC00–U+D7AF
    /// - 韩文辅音/元音：U+1100–U+11FF, U+3130–U+318F
    /// - CJK 标点/全角形式：U+3000–U+303F, U+FF00–U+FFEF
    private static func removeCJKSpaces(_ text: String) -> String {
        // 构建 CJK 字符正则类
        let cjkRanges = [
            "\\u{4E00}-\\u{9FFF}",   // CJK 统一表意文字
            "\\u{3400}-\\u{4DBF}",   // CJK 扩展 A
            "\\u{F900}-\\u{FAFF}",   // CJK 兼容区
            "\\u{3040}-\\u{309F}",   // 平假名
            "\\u{30A0}-\\u{30FF}",   // 片假名
            "\\u{AC00}-\\u{D7AF}",   // 韩文音节
            "\\u{1100}-\\u{11FF}",   // 韩文辅音
            "\\u{3130}-\\u{318F}",   // 韩文兼容字母
            "\\u{3000}-\\u{303F}",   // CJK 标点
            "\\u{FF00}-\\u{FFEF}",   // 全角形式
        ]
        let cjkClass = cjkRanges.joined(separator: "")

        // 模式：CJK字符 + 一个或多个空格 + CJK字符 → 直接拼接
        let pattern = "([\(cjkClass)])\\s+([\(cjkClass)])"

        var result = text
        // 多次迭代处理，直到不再变化（处理连续 CJK 空格链）
        var changed = true
        var iterations = 0
        while changed && iterations < 10 {
            changed = false
            iterations += 1
            guard let regex = try? NSRegularExpression(pattern: pattern) else { break }
            let range = NSRange(result.startIndex..., in: result)
            let newResult = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1$2")
            if newResult != result {
                changed = true
                result = newResult
            }
        }

        return result
    }
}

// MARK: - NSTextCheckingResult 扩展，用于安全获取 Range<String.Index>

private extension NSTextCheckingResult {
    func matchRange(at idx: Int, in string: String) -> Range<String.Index> {
        let nsRange = range(at: idx)
        return Range(nsRange, in: string) ?? string.startIndex..<string.startIndex
    }

    func range(at idx: Int, in string: String) -> Range<String.Index> {
        let nsRange = range(at: idx)
        return Range(nsRange, in: string) ?? string.startIndex..<string.startIndex
    }
}
