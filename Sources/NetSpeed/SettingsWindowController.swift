// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import AppKit
import SwiftUI

/// Hosts `SettingsView` in a plain `NSWindow`.
///
/// We deliberately don't use SwiftUI's `Settings` scene for this. In an
/// `LSUIElement` (no Dock icon) app driven by an `NSStatusItem`, there is no
/// reliable public way to open that scene programmatically, so we own the
/// window ourselves.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(settings: settings)
            )

            let window = NSWindow(contentViewController: hosting)
            window.title = "NetSpeed Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        settings.refreshLaunchAtLogin()

        guard let window else { return }

        // An accessory (LSUIElement) app isn't frontmost by default. On recent
        // macOS, `NSApp.activate()` can be declined for such apps when none of
        // their windows is already active, which would leave this window
        // stranded behind other apps. So: ask to activate, but *also* raise
        // the window ourselves so it is always visible.
        NSApp.activate()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Drop back to a normal level once shown, so the window doesn't stay
        // pinned above everything while the user works in other apps.
        DispatchQueue.main.async { [weak window] in
            window?.level = .normal
        }
    }

    // Keep launch-at-login honest if the user changed it in System Settings
    // while this window was in the background.
    func windowDidBecomeKey(_ notification: Notification) {
        settings.refreshLaunchAtLogin()
    }
}
