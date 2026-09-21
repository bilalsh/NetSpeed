import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let model: NetworkModel

    private let downloadLabel = NSTextField(labelWithString: "")
    private let uploadLabel = NSTextField(labelWithString: "")

    init(model: NetworkModel) {
        self.model = model

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        configureView()
        update()

        NotificationCenter.default.addObserver(
            forName: .init("NetSpeedModelDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func configureView() {
        guard let button = statusItem.button else {
            return
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0

        for label in [downloadLabel, uploadLabel] {
            label.font = .monospacedDigitSystemFont(
                ofSize: 10,
                weight: .regular
            )
            label.alignment = .left
            label.lineBreakMode = .byClipping
            label.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(label)
        }

        button.subviews.forEach { $0.removeFromSuperview() }

        stack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.topAnchor.constraint(equalTo: button.topAnchor),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        let menu = NSMenu()

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func update() {
        downloadLabel.stringValue = format(
            arrow: "↓",
            value: model.reading.downloadBytesPerSecond
        )

        uploadLabel.stringValue = format(
            arrow: "↑",
            value: model.reading.uploadBytesPerSecond
        )
    }

    private func format(arrow: String, value: Double?) -> String {
        guard let value else {
            return "\(arrow) —"
        }

        guard value > 0 else {
            return "\(arrow) 0"
        }

        // Avoid displaying raw byte rates such as "960 bytes/s".
        if value < 1_024 {
            let kilobytes = Int(ceil(value / 1_024))
            return "\(arrow) \(kilobytes) kB/s"
        }

        let bytes = Int64(value.rounded())

        let formatted = bytes.formatted(
            .byteCount(
                style: .binary,
                allowedUnits: .all,
                spellsOutZero: false,
                includesActualByteCount: false
            )
        )

        return "\(arrow) \(formatted)/s"
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}