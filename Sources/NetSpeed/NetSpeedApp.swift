// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import AppKit
import SwiftUI

@MainActor
final class NetworkModel: ObservableObject {
    @Published private(set) var reading = NetworkReading.initial

    private let sampler = NetworkSampler()
    private var samplingTask: Task<Void, Never>?

    func start() {
        guard samplingTask == nil else { return }

        samplingTask = Task { [weak self] in
            guard let self else { return }

            // `systemUptime` pauses during sleep, so a sleep/wake looks like ~1s
            // and defeats the sampler's `maximumGap`. `ContinuousClock` keeps
            // counting through sleep.
            let clock = ContinuousClock()
            let start = clock.now

            while !Task.isCancelled {
                let elapsed = clock.now - start
                reading = sampler.sample(now: elapsed.timeInterval)

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}

@main
struct NetSpeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    // The settings window is hosted by `SettingsWindowController` (an
    // NSWindow), because a SwiftUI `Settings` scene can't be opened reliably
    // from an NSStatusItem in an LSUIElement app. This empty scene only
    // exists so the SwiftUI `App` lifecycle has a body.
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NetworkModel()
    private let settings = AppSettings()

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsWindow = SettingsWindowController(settings: settings)
        settingsWindowController = settingsWindow

        model.start()

        statusBarController = StatusBarController(
            model: model,
            settings: settings,
            openSettings: { settingsWindow.show() }
        )

        // Register as a login item on first run only; afterwards the user's
        // choice (in Settings or System Settings) always wins.
        settings.applyFirstRunLaunchAtLoginDefault()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
