import ApplicationServices
import Foundation

enum HotkeyMonitorError: LocalizedError {
    case failedToCreateTap

    var errorDescription: String? {
        "无法创建全局键盘事件监听。请在系统设置中为 VoiceIME 开启辅助功能和输入监控权限。"
    }
}

final class HotkeyMonitor {
    var onFnStateChanged: ((Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnPressed = false

    func start() throws {
        guard eventTap == nil else {
            return
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            throw HotkeyMonitorError.failedToCreateTap
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil
        isFnPressed = false
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let isFnNowPressed = event.flags.contains(.maskSecondaryFn)

        guard isFnNowPressed != isFnPressed else {
            return Unmanaged.passUnretained(event)
        }

        isFnPressed = isFnNowPressed
        DispatchQueue.main.async { [weak self] in
            self?.onFnStateChanged?(isFnNowPressed)
        }

        // Fn 自己的 flagsChanged 事件直接吞掉，尽量避免触发系统 emoji 选择器。
        return nil
    }
}
