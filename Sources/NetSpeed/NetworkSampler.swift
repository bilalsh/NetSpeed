// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file contains a simplified adaptation of the sampling logic used by
// vorssaint/vorssaint-utils.
// Original project: https://github.com/vorssaint/vorssaint-utils
//
// Copyright (C) 2026 Vorssaint
//
// This adapted work is distributed under the terms of the
// GNU General Public License version 3 or later.

import Foundation

struct NetworkReading: Sendable {
    let downloadBytesPerSecond: Double?
    let uploadBytesPerSecond: Double?

    static let initial = NetworkReading(
        downloadBytesPerSecond: nil,
        uploadBytesPerSecond: nil
    )
}

final class NetworkSampler {

    private let reader: NetworkCounterReader

    private var previous: (
        counters: NetworkCounters,
        time: TimeInterval
    )?

    // If sampling stops for longer than this, don't calculate a rate across
    // the entire gap. Establish a fresh baseline instead.
    private let maximumGap: TimeInterval = 10

    init(reader: NetworkCounterReader = NetworkCounterReader()) {
        self.reader = reader
    }

    func sample(now: TimeInterval) -> NetworkReading {
        guard let current = reader.read() else {
            return .initial
        }

        defer {
            previous = (
                counters: current,
                time: now
            )
        }

        guard let previous,
              now > previous.time else {
            return .initial
        }

        let elapsed = now - previous.time

        guard elapsed <= maximumGap else {
            return .initial
        }

        let download: Double

        if current.received >= previous.counters.received {
            download =
                Double(current.received - previous.counters.received)
                / elapsed
        } else {
            // Counter reset/decrease. Don't turn it into a giant spike.
            download = 0
        }

        let upload: Double

        if current.sent >= previous.counters.sent {
            upload =
                Double(current.sent - previous.counters.sent)
                / elapsed
        } else {
            // Counter reset/decrease.
            upload = 0
        }

        return NetworkReading(
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload
        )
    }
}