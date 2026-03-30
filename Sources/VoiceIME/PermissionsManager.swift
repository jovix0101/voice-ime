import AVFoundation
import ApplicationServices
import Foundation
import Speech

enum PermissionsError: LocalizedError {
    case accessibility
    case microphone
    case speechRecognition

    var errorDescription: String? {
        switch self {
        case .accessibility:
            "需要开启辅助功能权限，才能监听 Fn 键并把文字注入到当前输入框。"
        case .microphone:
            "需要开启麦克风权限，才能开始录音。"
        case .speechRecognition:
            "需要开启语音识别权限，才能进行实时转录。"
        }
    }
}

@MainActor
final class PermissionsManager {
    // 启动时主动触发一次辅助功能授权提示，避免用户按下 Fn 后才发现无法工作。
    func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func ensureAccessibilityTrusted() throws {
        guard AXIsProcessTrusted() else {
            throw PermissionsError.accessibility
        }
    }

    func ensureRecordingPermissions() async throws {
        guard await ensureMicrophonePermission() else {
            throw PermissionsError.microphone
        }

        guard await ensureSpeechPermission() else {
            throw PermissionsError.speechRecognition
        }
    }

    private func ensureMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func ensureSpeechPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        default:
            return false
        }
    }
}
