import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        configuration: LLMConfiguration,
        onSave: @escaping (LLMConfiguration) -> Void
    ) {
        let rootView = LLMSettingsView(
            initialConfiguration: configuration,
            onSave: onSave
        )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "LLM Settings"
        window.setContentSize(NSSize(width: 520, height: 300))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct LLMSettingsView: View {
    @StateObject private var viewModel: LLMSettingsViewModel

    init(
        initialConfiguration: LLMConfiguration,
        onSave: @escaping (LLMConfiguration) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: LLMSettingsViewModel(
                initialConfiguration: initialConfiguration,
                onSave: onSave
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("API Base URL")
                    .font(.headline)
                TextField("https://api.openai.com/v1", text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)

                Text("API Key")
                    .font(.headline)
                SecureField("sk-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Clear API Key") {
                        viewModel.apiKey = ""
                    }
                }

                Text("Model")
                    .font(.headline)
                TextField("gpt-4o-mini", text: $viewModel.model)
                    .textFieldStyle(.roundedBorder)
            }

            Text(viewModel.statusMessage)
                .foregroundStyle(viewModel.statusColor)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()

                Button("Test") {
                    viewModel.test()
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Save") {
                    viewModel.save()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private final class LLMSettingsViewModel: ObservableObject {
    @Published var baseURL: String
    @Published var apiKey: String
    @Published var model: String
    @Published var statusMessage = "仅做极保守纠错，不会改写原句。"
    @Published var statusColor: Color = .secondary

    private let onSave: (LLMConfiguration) -> Void
    private let refiner = LLMRefiner()

    init(
        initialConfiguration: LLMConfiguration,
        onSave: @escaping (LLMConfiguration) -> Void
    ) {
        self.baseURL = initialConfiguration.baseURL
        self.apiKey = initialConfiguration.apiKey
        self.model = initialConfiguration.model
        self.onSave = onSave
    }

    func save() {
        onSave(currentConfiguration)
        statusMessage = "配置已保存。"
        statusColor = .green
    }

    func test() {
        let configuration = currentConfiguration
        statusMessage = "Testing..."
        statusColor = .secondary

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let response = try await refiner.test(configuration: configuration)
                await MainActor.run {
                    self.statusMessage = "Test 成功：\(response)"
                    self.statusColor = .green
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Test 失败：\(error.localizedDescription)"
                    self.statusColor = .red
                }
            }
        }
    }

    private var currentConfiguration: LLMConfiguration {
        LLMConfiguration(
            isEnabled: false,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model
        )
    }
}
