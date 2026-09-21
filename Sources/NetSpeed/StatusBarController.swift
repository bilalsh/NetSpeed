// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let model: NetworkModel
    private let settings: AppSettings
    private let openSettings: () -> Void

    private let downloadLabel = NSTextField(labelWithString: "")
    private let uploadLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    private var cancellables = Set<AnyCancellable>()

    init(
        model: NetworkModel,
        settings: AppSettings,
        openSettings: @escaping () -> Void
    ) {
        self.model = model
        self.settings = settings
        self.openSettings = openSettings

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        configureView()
        configureMenu()
        update()

        // Redraw when a new reading arrives or any preference changes.
        // `objectWillChange` fires *before* the value is set, so hop to the
        // next main-queue turn to read the settled values.
        model.$reading
            .sink { [weak self] _ in self?.scheduleUpdate() }
            .store(in: &cancellables)

        settings.objectWillChange
            .sink { [weak self] _ in self?.scheduleUpdate() }
            .store(in: &cancellables)
    }

    // MARK: - View

    private func configureView() {
        guard let button = statusItem.button else {
            return
        }

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for label in [downloadLabel, uploadLabel] {
            label.alignment = .left
            label.lineBreakMode = .byClipping
            label.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(label)
        }

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(stack)

        // Centre the stack vertically so a single visible line sits in the
        // middle of the menu bar rather than hugging the top.
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    private func configureMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit NetSpeed",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func scheduleUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.update()
        }
    }

    func update() {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.fontSize.points,
            weight: .regular
        )
        downloadLabel.font = font
        uploadLabel.font = font

        downloadLabel.stringValue = format(
            arrow: "↓",
            value: model.reading.downloadBytesPerSecond
        )
        uploadLabel.stringValue = format(
            arrow: "↑",
            value: model.reading.uploadBytesPerSecond
        )

        // `AppSettings` guarantees at least one of these is visible.
        downloadLabel.isHidden = !settings.showDownload
        uploadLabel.isHidden = !settings.showUpload
    }

    // MARK: - Formatting (unchanged behaviour)

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

    // MARK: - Actions

    @objc
    private func showSettings() {
        openSettings()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
