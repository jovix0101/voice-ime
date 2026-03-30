import Combine
import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: UserDefaultsKey.selectedLanguage)
        }
    }

    @Published var llmConfiguration: LLMConfiguration {
        didSet {
            saveLLMConfiguration()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: UserDefaultsKey.selectedLanguage),
           let language = AppLanguage(rawValue: rawValue) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .simplifiedChinese
        }

        if let data = defaults.data(forKey: UserDefaultsKey.llmConfiguration),
           let configuration = try? JSONDecoder().decode(LLMConfiguration.self, from: data) {
            self.llmConfiguration = configuration
        } else {
            self.llmConfiguration = LLMConfiguration()
        }
    }

    func updateLanguage(_ language: AppLanguage) {
        selectedLanguage = language
    }

    func updateLLMEnabled(_ isEnabled: Bool) {
        llmConfiguration.isEnabled = isEnabled
    }

    func updateLLMConfiguration(_ configuration: LLMConfiguration) {
        llmConfiguration = configuration
    }

    private func saveLLMConfiguration() {
        guard let data = try? JSONEncoder().encode(llmConfiguration) else {
            return
        }

        defaults.set(data, forKey: UserDefaultsKey.llmConfiguration)
    }
}
