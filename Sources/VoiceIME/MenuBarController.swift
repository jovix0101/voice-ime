import AppKit
import Combine

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarController(_ controller: MenuBarController, didSelect language: AppLanguage)
    func menuBarControllerDidToggleLLM(_ controller: MenuBarController)
    func menuBarControllerDidOpenLLMSettings(_ controller: MenuBarController)
    func menuBarControllerDidRequestPermissions(_ controller: MenuBarController)
    func menuBarControllerDidQuit(_ controller: MenuBarController)
}

@MainActor
final class MenuBarController: NSObject {
    weak var delegate: MenuBarControllerDelegate?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let settingsStore: AppSettingsStore

    private var languageItems: [AppLanguage: NSMenuItem] = [:]
    private var llmToggleItem: NSMenuItem?
    private var subscriptions = Set<AnyCancellable>()

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        super.init()

        configureStatusItem()
        buildMenu()
        bindState()
    }

    func refreshMenuState() {
        for (language, item) in languageItems {
            item.state = settingsStore.selectedLanguage == language ? .on : .off
        }

        llmToggleItem?.state = settingsStore.llmConfiguration.isEnabled ? .on : .off
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "waveform.circle.fill",
                accessibilityDescription: "VoiceIME"
            )
            button.image?.isTemplate = true
            button.toolTip = "VoiceIME"
        }

        statusItem.menu = menu
    }

    private func bindState() {
        settingsStore.$selectedLanguage
            .sink { [weak self] _ in
                self?.refreshMenuState()
            }
            .store(in: &subscriptions)

        settingsStore.$llmConfiguration
            .sink { [weak self] _ in
                self?.refreshMenuState()
            }
            .store(in: &subscriptions)
    }

    private func buildMenu() {
        menu.removeAllItems()

        let hintItem = NSMenuItem(title: "按住 Fn 说话，松开自动注入", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)
        menu.addItem(.separator())

        let languageMenu = NSMenu(title: "Language")
        for language in AppLanguage.allCases {
            let item = NSMenuItem(
                title: language.menuTitle,
                action: #selector(handleLanguageSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
            languageItems[language] = item
        }

        let languageRoot = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)

        let llmMenu = NSMenu(title: "LLM Refinement")
        let toggleItem = NSMenuItem(
            title: "Enable Conservative Refinement",
            action: #selector(handleLLMToggle),
            keyEquivalent: ""
        )
        toggleItem.target = self
        llmMenu.addItem(toggleItem)
        llmToggleItem = toggleItem

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(handleOpenSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        let llmRoot = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmRoot.submenu = llmMenu
        menu.addItem(llmRoot)

        menu.addItem(.separator())

        let permissionsItem = NSMenuItem(
            title: "Prompt Permissions",
            action: #selector(handlePermissionsRequest),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit VoiceIME",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        refreshMenuState()
    }

    @objc private func handleLanguageSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }

        delegate?.menuBarController(self, didSelect: language)
    }

    @objc private func handleLLMToggle() {
        delegate?.menuBarControllerDidToggleLLM(self)
    }

    @objc private func handleOpenSettings() {
        delegate?.menuBarControllerDidOpenLLMSettings(self)
    }

    @objc private func handlePermissionsRequest() {
        delegate?.menuBarControllerDidRequestPermissions(self)
    }

    @objc private func handleQuit() {
        delegate?.menuBarControllerDidQuit(self)
    }
}
