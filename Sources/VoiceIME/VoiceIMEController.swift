import AppKit
import Foundation

@MainActor
final class VoiceIMEController: NSObject {
    private enum CaptureState {
        case idle
        case recording
        case refining
    }

    private let settingsStore = AppSettingsStore()
    private let permissionsManager = PermissionsManager()
    private let hotkeyMonitor = HotkeyMonitor()
    private let speechController = AudioSpeechController()
    private let hudController = HUDPanelController()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()

    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var captureState: CaptureState = .idle
    private var currentTranscript = ""

    func start() {
        let menuBarController = MenuBarController(settingsStore: settingsStore)
        menuBarController.delegate = self
        self.menuBarController = menuBarController

        speechController.onTranscript = { [weak self] transcript in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.currentTranscript = transcript
                self.hudController.updateTranscript(transcript)
            }
        }

        speechController.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.hudController.updateAudioLevel(level)
            }
        }

        hotkeyMonitor.onFnStateChanged = { [weak self] isPressed in
            guard let self else {
                return
            }

            Task { @MainActor in
                if isPressed {
                    await self.beginRecording()
                } else {
                    await self.finishRecording()
                }
            }
        }

        permissionsManager.promptForAccessibilityIfNeeded()

        do {
            try hotkeyMonitor.start()
        } catch {
            presentError(title: "Fn 监听不可用", message: error.localizedDescription)
        }
    }

    func stop() {
        hotkeyMonitor.stop()
        speechController.stopImmediately()
        hudController.hide()
    }

    private func beginRecording() async {
        guard captureState == .idle else {
            return
        }

        do {
            try permissionsManager.ensureAccessibilityTrusted()
            try await permissionsManager.ensureRecordingPermissions()
            try speechController.start(localeIdentifier: settingsStore.selectedLanguage.rawValue)
        } catch {
            hudController.showMessage(error.localizedDescription)
            scheduleHUDHide()
            presentError(title: "无法开始录音", message: error.localizedDescription)
            return
        }

        captureState = .recording
        currentTranscript = ""
        hudController.showListening()
    }

    private func finishRecording() async {
        guard captureState == .recording else {
            return
        }

        captureState = .refining
        let transcript = await speechController.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        currentTranscript = transcript

        guard !transcript.isEmpty else {
            captureState = .idle
            hudController.hide()
            return
        }

        let finalText = await refineIfNeeded(transcript)

        do {
            try await textInjector.inject(finalText)
        } catch {
            presentError(title: "文字注入失败", message: error.localizedDescription)
        }

        captureState = .idle
        hudController.hide()
    }

    private func refineIfNeeded(_ transcript: String) async -> String {
        let configuration = settingsStore.llmConfiguration

        guard configuration.isEnabled else {
            return transcript
        }

        guard configuration.isComplete else {
            presentError(title: "LLM 配置不完整", message: "请先在菜单栏的 LLM Settings 中填写 Base URL、API Key 和 Model。")
            return transcript
        }

        hudController.showRefining()

        do {
            return try await llmRefiner.refine(
                text: transcript,
                language: settingsStore.selectedLanguage,
                configuration: configuration
            )
        } catch {
            presentError(title: "LLM Refinement 失败", message: error.localizedDescription)
            return transcript
        }
    }

    private func scheduleHUDHide() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            self?.hudController.hide()
        }
    }

    private func presentError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
extension VoiceIMEController: MenuBarControllerDelegate {
    func menuBarController(_ controller: MenuBarController, didSelect language: AppLanguage) {
        settingsStore.updateLanguage(language)
    }

    func menuBarControllerDidToggleLLM(_ controller: MenuBarController) {
        settingsStore.updateLLMEnabled(!settingsStore.llmConfiguration.isEnabled)
    }

    func menuBarControllerDidOpenLLMSettings(_ controller: MenuBarController) {
        settingsWindowController?.close()
        settingsWindowController = SettingsWindowController(
            configuration: settingsStore.llmConfiguration,
            onSave: { [weak self] configuration in
                guard let self else {
                    return
                }

                var merged = configuration
                merged.isEnabled = self.settingsStore.llmConfiguration.isEnabled
                self.settingsStore.updateLLMConfiguration(merged)
                self.menuBarController?.refreshMenuState()
            }
        )

        settingsWindowController?.present()
    }

    func menuBarControllerDidRequestPermissions(_ controller: MenuBarController) {
        permissionsManager.promptForAccessibilityIfNeeded()
    }

    func menuBarControllerDidQuit(_ controller: MenuBarController) {
        NSApp.terminate(nil)
    }
}
