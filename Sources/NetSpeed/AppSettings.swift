// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import Combine
import Foundation
import ServiceManagement

/// Font sizes offered for the menu-bar text.
enum MenuBarFontSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 9
    case medium = 10
    case large = 11

    var id: Int { rawValue }

    var points: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .small: "Small (9 pt)"
        case .medium: "Medium (10 pt)"
        case .large: "Large (11 pt)"
        }
    }
}

/// User preferences.
///
/// Display preferences are persisted in `UserDefaults`. Launch-at-login is
/// deliberately *not* stored by us: the system owns that state (the user can
/// flip it in System Settings → General → Login Items at any time), so we read
/// it back from `SMAppService.mainApp.status` instead of trusting a local copy.
@MainActor
final class AppSettings: ObservableObject {

    private enum Key {
        static let showDownload = "showDownload"
        static let showUpload = "showUpload"
        static let fontSize = "fontSize"
    }

    private let defaults: UserDefaults

    // Invariant: `showDownload` and `showUpload` are never both false.

    @Published var showDownload: Bool {
        didSet { defaults.set(showDownload, forKey: Key.showDownload) }
    }

    @Published var showUpload: Bool {
        didSet { defaults.set(showUpload, forKey: Key.showUpload) }
    }

    @Published var fontSize: MenuBarFontSize {
        didSet { defaults.set(fontSize.rawValue, forKey: Key.fontSize) }
    }

    /// Mirrors `SMAppService.mainApp.status == .enabled`.
    @Published private(set) var launchAtLogin: Bool

    /// Set when macOS has registered the item but is waiting for the user to
    /// approve it in System Settings.
    @Published private(set) var launchAtLoginNeedsApproval = false

    /// A user-presentable message if the last register/unregister call failed.
    @Published private(set) var launchAtLoginError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Key.showDownload: true,
            Key.showUpload: true,
            Key.fontSize: MenuBarFontSize.medium.rawValue
        ])

        var download = defaults.bool(forKey: Key.showDownload)
        let upload = defaults.bool(forKey: Key.showUpload)

        // At least one speed must always be visible. The settings UI enforces
        // this, but earlier builds allowed turning both off, so repair any
        // such stored state rather than showing an empty menu-bar item.
        if !download && !upload {
            download = true
            defaults.set(true, forKey: Key.showDownload)
        }

        showDownload = download
        showUpload = upload
        fontSize = MenuBarFontSize(
            rawValue: defaults.integer(forKey: Key.fontSize)
        ) ?? .medium

        launchAtLogin = false
        refreshLaunchAtLogin()
    }

    // MARK: - Launch at login

    /// Re-read the real state from the system. Call whenever the settings
    /// window becomes visible/active, since the user may have changed it in
    /// System Settings while we were running.
    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled)
        launchAtLoginNeedsApproval = (status == .requiresApproval)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        // Always reflect what the system says, not what we asked for.
        refreshLaunchAtLogin()
    }

    /// Enable launch-at-login exactly once, on first run, so the app "just
    /// works" after install. After that the user's choice is respected — if
    /// they turn it off, we never turn it back on.
    func applyFirstRunLaunchAtLoginDefault() {
        let flag = "didApplyLaunchAtLoginDefault"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)

        if SMAppService.mainApp.status == .notRegistered {
            setLaunchAtLogin(true)
        }
    }
}
