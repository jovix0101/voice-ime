import Carbon
import Foundation

struct InputSourceSnapshot {
    let originalSource: TISInputSource
    let switchedToASCII: Bool
}

final class InputSourceManager {
    func prepareForPaste() -> InputSourceSnapshot? {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        let shouldSwitch = isCJKInputSource(currentSource)

        guard shouldSwitch,
              let asciiSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return InputSourceSnapshot(originalSource: currentSource, switchedToASCII: false)
        }

        TISSelectInputSource(asciiSource)
        return InputSourceSnapshot(originalSource: currentSource, switchedToASCII: true)
    }

    func restore(_ snapshot: InputSourceSnapshot?) {
        guard let snapshot, snapshot.switchedToASCII else {
            return
        }

        TISSelectInputSource(snapshot.originalSource)
    }

    private func isCJKInputSource(_ inputSource: TISInputSource) -> Bool {
        let sourceID = stringProperty(for: inputSource, key: kTISPropertyInputSourceID)
        let languages = arrayProperty(for: inputSource, key: kTISPropertyInputSourceLanguages)
        let lowercasedID = sourceID.lowercased()

        if languages.contains(where: { $0.hasPrefix("zh") || $0.hasPrefix("ja") || $0.hasPrefix("ko") }) {
            return true
        }

        return lowercasedID.contains("inputmethod") ||
               lowercasedID.contains("pinyin") ||
               lowercasedID.contains("kotoeri") ||
               lowercasedID.contains("korean")
    }

    private func stringProperty(for inputSource: TISInputSource, key: CFString) -> String {
        guard let property = TISGetInputSourceProperty(inputSource, key) else {
            return ""
        }

        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }

    private func arrayProperty(for inputSource: TISInputSource, key: CFString) -> [String] {
        guard let property = TISGetInputSourceProperty(inputSource, key) else {
            return []
        }

        let value = Unmanaged<CFArray>.fromOpaque(property).takeUnretainedValue() as NSArray
        return value.compactMap { $0 as? String }
    }
}
