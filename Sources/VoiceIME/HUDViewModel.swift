import AppKit
import Combine
import Foundation

@MainActor
final class HUDViewModel: ObservableObject {
    @Published private(set) var text: String = "按住 Fn 开始说话"
    @Published private(set) var textWidth: CGFloat = 160
    @Published private(set) var panelWidth: CGFloat = 304
    @Published private(set) var barHeights: [CGFloat] = Array(repeating: 10, count: 5)

    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var smoothedLevel: CGFloat = 0

    func showListeningPlaceholder() {
        updateText("正在聆听…")
    }

    func showRefining() {
        updateText("Refining...")
    }

    func showMessage(_ message: String) {
        updateText(message)
    }

    func updateTranscript(_ transcript: String) {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        updateText(normalized.isEmpty ? "正在聆听…" : normalized)
    }

    func updateAudioLevel(_ rawLevel: CGFloat) {
        // attack 40%、release 15%，让波形在大声时更灵敏、收回时更平滑。
        let clampedLevel = max(0, min(1, rawLevel))
        let smoothing = clampedLevel >= smoothedLevel ? 0.40 : 0.15
        smoothedLevel += (clampedLevel - smoothedLevel) * smoothing

        let minHeight: CGFloat = 7
        let maxTravel: CGFloat = 22

        barHeights = weights.map { weight in
            let jitter = CGFloat.random(in: 0.96...1.04)
            let height = minHeight + maxTravel * smoothedLevel * weight * jitter
            return min(31, max(minHeight, height))
        }
    }

    private func updateText(_ newText: String) {
        text = newText

        let font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let bounding = NSString(string: newText).boundingRect(
            with: NSSize(width: 560, height: 24),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        textWidth = min(560, max(160, ceil(bounding.width) + 4))
        panelWidth = 44 + 14 + textWidth + 52
    }
}
