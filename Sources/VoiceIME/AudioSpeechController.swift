import AVFoundation
import Foundation
import Speech

enum AudioSpeechError: LocalizedError {
    case recognizerUnavailable
    case audioEngineFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "当前语言的语音识别器不可用。"
        case .audioEngineFailed:
            "音频引擎启动失败。"
        }
    }
}

final class AudioSpeechController {
    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var stopFallbackTask: Task<Void, Never>?

    var onTranscript: ((String) -> Void)?
    var onAudioLevel: ((CGFloat) -> Void)?

    func start(localeIdentifier: String) throws {
        stopImmediately()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            throw AudioSpeechError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        latestTranscript = ""
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else {
                return
            }

            if let result {
                let transcript = result.bestTranscription.formattedString
                self.latestTranscript = transcript

                DispatchQueue.main.async {
                    self.onTranscript?(transcript)
                }

                if result.isFinal {
                    self.finishStoppingIfNeeded()
                }
            }

            if error != nil {
                self.finishStoppingIfNeeded()
            }
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else {
                return
            }

            self.recognitionRequest?.append(buffer)
            let level = self.normalizedRMSLevel(from: buffer)

            DispatchQueue.main.async {
                self.onAudioLevel?(level)
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            throw AudioSpeechError.audioEngineFailed
        }
    }

    func stop() async -> String {
        guard audioEngine.isRunning || recognitionTask != nil else {
            return latestTranscript
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        return await withCheckedContinuation { continuation in
            stopContinuation = continuation

            // 某些情况下最终结果不会立刻回调，这里做一个兜底，保证松开 Fn 后能及时结束流程。
            stopFallbackTask?.cancel()
            stopFallbackTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                self?.finishStoppingIfNeeded()
            }
        }
    }

    func stopImmediately() {
        stopFallbackTask?.cancel()
        stopFallbackTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil

        if let stopContinuation {
            stopContinuation.resume(returning: latestTranscript)
            self.stopContinuation = nil
        }
    }

    private func finishStoppingIfNeeded() {
        stopFallbackTask?.cancel()
        stopFallbackTask = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        if let stopContinuation {
            stopContinuation.resume(returning: latestTranscript)
            self.stopContinuation = nil
        }
    }

    private func normalizedRMSLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData?.pointee else {
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        var sum: Float = 0
        for index in 0..<frameLength {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let minimum: Float = 0.000_12
        let decibel = 20 * log10(max(rms, minimum))

        // 把大约 [-78dB, 0dB] 映射到 [0, 1]，方便驱动 HUD 波形。
        let normalized = (decibel + 78) / 78
        return CGFloat(max(0, min(1, normalized)))
    }
}
