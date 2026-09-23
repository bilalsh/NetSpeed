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

    /// The entire status-item content — glyph plus one or two lines of
    /// text — is rendered as a single bitmap and shown in this image view.
    ///
    /// Earlier versions used a stack of `NSTextField`s and fought AppKit's
    /// auto-layout (intrinsic content size, stack spacing, baseline
    /// offsets) to get two lines to sit tightly and evenly. Drawing
    /// everything by hand into one `NSImage`, with explicit Y-coordinates
    /// for each line, sidesteps that entirely: there's no layout system to
    /// fight, just a few numbers to position text precisely.
    private let contentView = NSImageView()
    private var contentWidthConstraint: NSLayoutConstraint!

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

        contentView.imageScaling = .scaleNone
        contentView.translatesAutoresizingMaskIntoConstraints = false

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(contentView)

        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: button.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            contentWidthConstraint
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
        let bothVisible = settings.showDownload && settings.showUpload

        let downloadText = format(arrow: "↓", value: model.reading.downloadBytesPerSecond)
        let uploadText = format(arrow: "↑", value: model.reading.uploadBytesPerSecond)

        let lines: [String]
        if bothVisible {
            lines = [downloadText, uploadText]
        } else if settings.showDownload {
            lines = [downloadText]
        } else {
            lines = [uploadText]
        }

        let image = Self.renderContent(
            lines: lines,
            fontSize: settings.fontSize.points
        )

        contentView.image = image
        contentWidthConstraint.constant = image.size.width
    }

    // MARK: - Rendering

    /// Fixed glyph canvas size and the gap between the glyph and the text
    /// that follows it.
    private static let glyphSize: CGFloat = 18
    private static let glyphTextGap: CGFloat = 4
    /// Breathing room before the glyph and after the text, so the content
    /// doesn't sit flush against the menu's highlight edge when the status
    /// item is active.
    private static let leadingPadding: CGFloat = 2
    private static let trailingPadding: CGFloat = 2

    /// Draws the glyph and one or two lines of text into a single bitmap,
    /// sized exactly to its content, with explicit Y-coordinates for each
    /// line rather than relying on stack-view layout.
    private static func renderContent(lines: [String], fontSize: CGFloat) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        let lineSizes = lines.map { ($0 as NSString).size(withAttributes: attributes) }
        let textWidth = ceil(lineSizes.map(\.width).max() ?? 0)

        // A little vertical padding above/below so the glyph doesn't touch
        // the top/bottom edge of the status item's highlight when active.
        let verticalPadding: CGFloat = 3
        let contentHeight = max(glyphSize, lines.count == 2 ? fontSize * 2.1 : fontSize * 1.3)
        let imageHeight = contentHeight + verticalPadding * 2

        let imageWidth = leadingPadding + glyphSize + glyphTextGap + textWidth + trailingPadding
        let size = NSSize(width: ceil(imageWidth), height: ceil(imageHeight))

        let image = NSImage(size: size, flipped: false) { rect in
            let glyphY = (size.height - glyphSize) / 2
            drawGlyph(in: NSRect(x: leadingPadding, y: glyphY, width: glyphSize, height: glyphSize))

            let textX = leadingPadding + glyphSize + glyphTextGap

            if lines.count == 2 {
                // Two lines: split the available height in half and centre
                // each line's text within its half — explicit positions,
                // no stack-view spacing/intrinsic-size guesswork.
                let lineHeight = contentHeight / 2
                let topLineY = verticalPadding + lineHeight
                let bottomLineY = verticalPadding

                for (index, line) in lines.enumerated() {
                    let lineSize = lineSizes[index]
                    let boxY = index == 0 ? topLineY : bottomLineY
                    let y = boxY + (lineHeight - lineSize.height) / 2
                    (line as NSString).draw(at: NSPoint(x: textX, y: y), withAttributes: attributes)
                }
            } else if let line = lines.first {
                let lineSize = lineSizes[0]
                let y = (size.height - lineSize.height) / 2
                (line as NSString).draw(at: NSPoint(x: textX, y: y), withAttributes: attributes)
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    /// Draws the monochrome "N" glyph into `rect`, using the *exact* path
    /// data from the real app icon (`app-icon.svg`) — not a simplified
    /// approximation — so the menu-bar glyph is guaranteed to match it.
    /// Quadratic curves from the original SVG are converted to the cubic
    /// curves `NSBezierPath` supports (`CP1 = p0 + 2/3*(q-p0)`,
    /// `CP2 = p1 + 2/3*(q-p1)`, the standard quadratic-to-cubic formula).
    ///
    /// The SVG places the glyph with `transform="translate(0.7 1.4)
    /// scale(0.03)"` in an 18x18, y-down viewBox. `NSImage(flipped: false)`
    /// draws in a y-up space, so the same visual result needs the
    /// translate/scale folded together with a y-flip. Working through
    /// `ns_y = 18 - (1.4 + 0.03 * svg_y) = 16.6 - 0.03 * svg_y` gives an
    /// equivalent transform of translate(0.7, 16.6) + scale(0.03, -0.03) —
    /// same x handling, y scaled negative to flip it. Verified against the
    /// path's first point (100, 8), which should land near the top of the
    /// canvas in both spaces; it does (SVG y=1.64, NS y=16.36 of 18).
    ///
    /// `rect` is expected to be 18x18 (`glyphSize`); this additionally
    /// scales by `rect.width / 18` so the glyph still fits if that ever
    /// changes.
    private static func drawGlyph(in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let designSize: CGFloat = 18
        let outerScale = rect.width / designSize

        let outer = NSAffineTransform()
        outer.translateX(by: rect.minX, yBy: rect.minY)
        outer.scale(by: outerScale)
        outer.concat()

        // translate(0.7, 16.6) + scale(0.03, -0.03), applied second so it
        // acts on the original 556x514 path coordinates.
        let iconTransform = NSAffineTransform()
        iconTransform.translateX(by: 0.7, yBy: 16.6)
        iconTransform.scaleX(by: 0.03, yBy: -0.03)
        iconTransform.concat()

        NSColor.black.setFill()

        let upPath = NSBezierPath()
        upPath.move(to: NSPoint(x: 100, y: 8))
        upPath.curve(to: NSPoint(x: 136.0000, y: 14.0000), controlPoint1: NSPoint(x: 112.0000, y: 2.6667), controlPoint2: NSPoint(x: 124.0000, y: 4.6667))
        upPath.line(to: NSPoint(x: 228, y: 124))
        upPath.curve(to: NSPoint(x: 226.0000, y: 154.0000), controlPoint1: NSPoint(x: 234.6667, y: 134.6667), controlPoint2: NSPoint(x: 234.0000, y: 144.6667))
        upPath.curve(to: NSPoint(x: 204.0000, y: 162.0000), controlPoint1: NSPoint(x: 220.6667, y: 159.3333), controlPoint2: NSPoint(x: 213.3333, y: 162.0000))
        upPath.line(to: NSPoint(x: 158, y: 162))
        upPath.line(to: NSPoint(x: 158, y: 480))
        upPath.curve(to: NSPoint(x: 118.0000, y: 508.0000), controlPoint1: NSPoint(x: 158.0000, y: 498.6667), controlPoint2: NSPoint(x: 144.6667, y: 508.0000))
        upPath.curve(to: NSPoint(x: 78.0000, y: 480.0000), controlPoint1: NSPoint(x: 91.3333, y: 508.0000), controlPoint2: NSPoint(x: 78.0000, y: 498.6667))
        upPath.line(to: NSPoint(x: 78, y: 162))
        upPath.line(to: NSPoint(x: 34, y: 162))
        upPath.curve(to: NSPoint(x: 4.0000, y: 146.0000), controlPoint1: NSPoint(x: 18.0000, y: 162.0000), controlPoint2: NSPoint(x: 8.0000, y: 156.6667))
        upPath.curve(to: NSPoint(x: 12.0000, y: 120.0000), controlPoint1: NSPoint(x: 1.3333, y: 136.6667), controlPoint2: NSPoint(x: 4.0000, y: 128.0000))
        upPath.line(to: NSPoint(x: 98, y: 10))
        upPath.close()
        upPath.fill()

        let connectorPath = NSBezierPath()
        connectorPath.move(to: NSPoint(x: 178, y: 182))
        connectorPath.line(to: NSPoint(x: 210, y: 182))
        connectorPath.curve(to: NSPoint(x: 246.0000, y: 158.0000), controlPoint1: NSPoint(x: 224.6667, y: 179.3333), controlPoint2: NSPoint(x: 236.6667, y: 171.3333))
        connectorPath.line(to: NSPoint(x: 252, y: 154))
        connectorPath.line(to: NSPoint(x: 380, y: 328))
        connectorPath.line(to: NSPoint(x: 338, y: 330))
        connectorPath.curve(to: NSPoint(x: 308.0000, y: 352.0000), controlPoint1: NSPoint(x: 327.3333, y: 334.0000), controlPoint2: NSPoint(x: 317.3333, y: 341.3333))
        connectorPath.close()
        connectorPath.fill()

        let downPath = NSBezierPath()
        downPath.move(to: NSPoint(x: 402, y: 30))
        downPath.curve(to: NSPoint(x: 440.0000, y: 4.0000), controlPoint1: NSPoint(x: 402.0000, y: 12.6667), controlPoint2: NSPoint(x: 414.6667, y: 4.0000))
        downPath.curve(to: NSPoint(x: 478.0000, y: 30.0000), controlPoint1: NSPoint(x: 465.3333, y: 4.0000), controlPoint2: NSPoint(x: 478.0000, y: 12.6667))
        downPath.line(to: NSPoint(x: 478, y: 346))
        downPath.line(to: NSPoint(x: 522, y: 346))
        downPath.curve(to: NSPoint(x: 552.0000, y: 364.0000), controlPoint1: NSPoint(x: 538.0000, y: 347.3333), controlPoint2: NSPoint(x: 548.0000, y: 353.3333))
        downPath.curve(to: NSPoint(x: 544.0000, y: 390.0000), controlPoint1: NSPoint(x: 554.6667, y: 373.3333), controlPoint2: NSPoint(x: 552.0000, y: 382.0000))
        downPath.line(to: NSPoint(x: 462, y: 492))
        downPath.curve(to: NSPoint(x: 420.0000, y: 498.0000), controlPoint1: NSPoint(x: 450.0000, y: 506.6667), controlPoint2: NSPoint(x: 436.0000, y: 508.6667))
        downPath.line(to: NSPoint(x: 336, y: 396))
        downPath.curve(to: NSPoint(x: 326.0000, y: 364.0000), controlPoint1: NSPoint(x: 324.0000, y: 384.0000), controlPoint2: NSPoint(x: 320.6667, y: 373.3333))
        downPath.curve(to: NSPoint(x: 352.0000, y: 346.0000), controlPoint1: NSPoint(x: 330.0000, y: 353.3333), controlPoint2: NSPoint(x: 338.6667, y: 347.3333))
        downPath.line(to: NSPoint(x: 402, y: 346))
        downPath.close()
        downPath.fill()
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