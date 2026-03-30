import Foundation

// 支持的识别语言。默认值必须是简体中文，保证首次启动即可直接识别中文。
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case simplifiedChinese = "zh-CN"
    case english = "en-US"
    case traditionalChinese = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        }
    }
}

// LLM 只做极保守纠错，因此配置上保持简单，避免出现额外的行为开关。
struct LLMConfiguration: Codable, Equatable {
    var isEnabled: Bool = false
    var baseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var model: String = "gpt-4o-mini"

    var isComplete: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum UserDefaultsKey {
    static let selectedLanguage = "selectedLanguage"
    static let llmConfiguration = "llmConfiguration"
}
