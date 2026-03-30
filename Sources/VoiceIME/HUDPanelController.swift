import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class HUDPanelController {
    let viewModel = HUDViewModel()

    private let panel: NSPanel
    private let visualEffectView: NSVisualEffectView
    private let hostingView: NSHostingView<HUDContentView>
    private var subscriptions = Set<AnyCancellable>()
    private var isVisible = false

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 304, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        visualEffectView = NSVisualEffectView(frame: .zero)
        hostingView = NSHostingView(rootView: HUDContentView(viewModel: viewModel))

        configurePanel()
        bindWidthChanges()
    }

    func showListening() {
        viewModel.showListeningPlaceholder()
        animateInIfNeeded()
    }

    func updateTranscript(_ transcript: String) {
        viewModel.updateTranscript(transcript)
        animateInIfNeeded()
    }

    func updateAudioLevel(_ level: CGFloat) {
        viewModel.updateAudioLevel(level)
    }

    func showRefining() {
        viewModel.showRefining()
        animateInIfNeeded()
    }

    func showMessage(_ message: String) {
        viewModel.showMessage(message)
        animateInIfNeeded()
    }

    func hide() {
        guard isVisible else {
            return
        }

        isVisible = false

        let contentLayer = visualEffectView.layer
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.0
        shrink.toValue = 0.92
        shrink.duration = 0.22
        shrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentLayer?.add(shrink, forKey: "exitScale")
        contentLayer?.setAffineTransform(CGAffineTransform(scaleX: 0.92, y: 0.92))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [panel, visualEffectView] in
            visualEffectView.layer?.setAffineTransform(.identity)
            panel.orderOut(nil)
        }
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 28
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.7
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = visualEffectView
        visualEffectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        updateFrame(animated: false, duration: 0)
    }

    private func bindWidthChanges() {
        viewModel.$panelWidth
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateFrame(animated: true, duration: 0.25)
            }
            .store(in: &subscriptions)
    }

    private func animateInIfNeeded() {
        let wasVisible = isVisible
        isVisible = true
        updateFrame(animated: wasVisible, duration: 0.25)

        guard !wasVisible else {
            return
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        let startFrame = panel.frame.offsetBy(dx: 0, dy: -10)
        panel.setFrame(startFrame, display: true)

        visualEffectView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.94, y: 0.94))

        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.94
        spring.toValue = 1.0
        spring.mass = 0.85
        spring.stiffness = 180
        spring.damping = 18
        spring.duration = 0.35
        spring.isRemovedOnCompletion = true
        visualEffectView.layer?.add(spring, forKey: "entryScale")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame(), display: true)
        } completionHandler: {
            self.visualEffectView.layer?.setAffineTransform(.identity)
        }
    }

    private func updateFrame(animated: Bool, duration: TimeInterval) {
        let frame = targetFrame()

        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func targetFrame() -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = viewModel.panelWidth
        let height: CGFloat = 56
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + 28

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
