import SwiftUI
import WebKit

struct RichTextView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground") // 背景を透明に
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        let htmlString = renderMarkdownToHTML(markdown)
        nsView.loadHTMLString(htmlString, baseURL: nil)
    }

    private func renderMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown

        // エスケープ
        html = html.replacingOccurrences(of: "&", with: "&amp;")
        html = html.replacingOccurrences(of: "<", with: "&lt;")
        html = html.replacingOccurrences(of: ">", with: "&gt;")

        // 見出し
        html = html.replacingOccurrences(of: "(?m)^### (.*)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.*)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.*)$", with: "<h1>$1</h1>", options: .regularExpression)

        // 箇条書き
        html = html.replacingOccurrences(of: "(?m)^- (.*)$", with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\* (.*)$", with: "<li>$1</li>", options: .regularExpression)

        // 段落と改行
        let paragraphs = html.components(separatedBy: "\n\n")
        html = paragraphs.map { paragraph in
            if paragraph.contains("<li>") {
                return "<ul>\(paragraph)</ul>"
            } else {
                return "<p>\(paragraph.replacingOccurrences(of: "\n", with: "<br>"))</p>"
            }
        }.joined()

        let css = """
        <style>
            :root {
                color-scheme: light dark;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 13px;
                line-height: 1.6;
                padding: 15px;
                color: canvastext;
                background-color: transparent;
            }
            h1, h2, h3 {
                margin-top: 1.2em;
                margin-bottom: 0.5em;
                font-weight: 700;
                color: #007AFF;
            }
            h1 { font-size: 1.6em; border-bottom: 2px solid #007AFF; padding-bottom: 0.2em; }
            h2 { font-size: 1.4em; border-bottom: 1px solid rgba(0,122,255,0.3); padding-bottom: 0.1em; }
            h3 { font-size: 1.2em; }
            ul { padding-left: 1.5em; margin-bottom: 1em; }
            li { margin-bottom: 0.4em; }
            p { margin-bottom: 1em; }
            code {
                background-color: rgba(27,31,35,0.05);
                padding: 0.2em 0.4em;
                border-radius: 3px;
                font-family: SFMono-Regular, Consolas, Menlo, monospace;
            }
        </style>
        """

        return "<html><head><meta charset='utf-8'>\(css)</head><body>\(html)</body></html>"
    }
}
