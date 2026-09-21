// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                // Whichever toggle is the last one on is disabled, so the
                // menu bar can never end up showing nothing.
                Toggle("Show download speed", isOn: $settings.showDownload)
                    .disabled(settings.showDownload && !settings.showUpload)

                Toggle("Show upload speed", isOn: $settings.showUpload)
                    .disabled(settings.showUpload && !settings.showDownload)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("At least one speed always stays visible.")
            }

            Section("Font Size") {
                Picker("Font size", selection: $settings.fontSize) {
                    ForEach(MenuBarFontSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section("General") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )

                if settings.launchAtLoginNeedsApproval {
                    Text("macOS needs your approval. Open System Settings → General → Login Items to allow NetSpeed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}
