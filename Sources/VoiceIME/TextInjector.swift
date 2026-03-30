import AppKit
import ApplicationServices
import Foundation

enum TextInjectionError: LocalizedError {
    case emptyText
    case accessibilityUnavailable
    case failedToCreateEventSource

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "没有可注入的文字。"
        case .accessibilityUnavailable:
            "缺少辅助功能权限，无法模拟粘贴。"
        case .failedToCreateEventSource:
            "无法创建键盘事件源，无法完成粘贴。"
        }
    }
}

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

final class TextInjector {
    private let inputSourceManager = InputSourceManager()

    func inject(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw TextInjectionError.emptyText
        }

        guard AXIsProcessTrusted() else {
            throw TextInjectionError.accessibilityUnavailable
        }

        let pasteboard = NSPasteboard.general
        let snapshot = makePasteboardSnapshot(from: pasteboard)
        let inputSourceSnapshot = inputSourceManager.prepareForPaste()

        // 无论后续注入是否成功，都要把输入法和剪贴板原样恢复，避免污染用户环境。
        defer {
            inputSourceManager.restore(inputSourceSnapshot)
            restorePasteboard(snapshot, to: pasteboard)
        }

        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)

        try await Task.sleep(for: .milliseconds(60))
        try postCommandV()
        try await Task.sleep(for: .milliseconds(140))
    }

    private func postCommandV() throws {
        guard let eventSource = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInjectionError.failedToCreateEventSource
        }

        let keyCodeV: CGKeyCode = 9

        guard let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCodeV,
            keyDown: true
        ),
        let keyUp = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCodeV,
            keyDown: false
        ) else {
            throw TextInjectionError.failedToCreateEventSource
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func makePasteboardSnapshot(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !snapshot.items.isEmpty else {
            return
        }

        let items = snapshot.items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()

            for (type, data) in itemData {
                item.setData(data, forType: type)
            }

            return item
        }

        pasteboard.writeObjects(items)
    }
}
