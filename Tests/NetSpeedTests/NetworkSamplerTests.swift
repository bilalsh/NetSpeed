// SPDX-License-Identifier: GPL-3.0-or-later
//
// Copyright (C) 2026 Neo
//
// This file is part of NetSpeed, distributed under the terms of the
// GNU General Public License version 3 or later. See LICENSE.

import Testing
@testable import NetSpeed

/// A stub reader that returns a scripted sequence of counter snapshots,
/// one per call to `read()`, so `NetworkSampler`'s rate math can be tested
/// without touching real system interfaces.
final class StubNetworkCounterReader: NetworkCounterReaderProtocol {
    private var readings: [NetworkCounters?]
    private var index = 0

    init(readings: [NetworkCounters?]) {
        self.readings = readings
    }

    func read() -> NetworkCounters? {
        guard index < readings.count else { return readings.last ?? nil }
        defer { index += 1 }
        return readings[index]
    }
}

@Suite("NetworkSampler")
struct NetworkSamplerTests {

    @Test("First sample establishes a baseline and reports no rate")
    func firstSampleIsBaseline() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 1_000, sent: 500)
        ])
        let sampler = NetworkSampler(reader: reader)

        let reading = sampler.sample(now: 0)

        #expect(reading.downloadBytesPerSecond == nil)
        #expect(reading.uploadBytesPerSecond == nil)
    }

    @Test("Second sample computes bytes-per-second from the delta")
    func computesRateFromDelta() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 1_000, sent: 500),
            NetworkCounters(received: 3_000, sent: 1_500)
        ])
        let sampler = NetworkSampler(reader: reader)

        _ = sampler.sample(now: 0)
        let reading = sampler.sample(now: 2)

        // (3000 - 1000) / 2s = 1000 B/s, (1500 - 500) / 2s = 500 B/s
        #expect(reading.downloadBytesPerSecond == 1_000)
        #expect(reading.uploadBytesPerSecond == 500)
    }

    @Test("Counter decrease is treated as zero rate, not a spike")
    func counterDecreaseIsZero() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 5_000, sent: 5_000),
            // Simulates an interface counter reset.
            NetworkCounters(received: 100, sent: 100)
        ])
        let sampler = NetworkSampler(reader: reader)

        _ = sampler.sample(now: 0)
        let reading = sampler.sample(now: 1)

        #expect(reading.downloadBytesPerSecond == 0)
        #expect(reading.uploadBytesPerSecond == 0)
    }

    @Test("A gap longer than maximumGap resets the baseline")
    func largeGapResetsBaseline() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 1_000, sent: 1_000),
            NetworkCounters(received: 50_000, sent: 50_000)
        ])
        let sampler = NetworkSampler(reader: reader)

        _ = sampler.sample(now: 0)
        // 11s gap > the 10s maximumGap.
        let reading = sampler.sample(now: 11)

        #expect(reading.downloadBytesPerSecond == nil)
        #expect(reading.uploadBytesPerSecond == nil)
    }

    @Test("A non-increasing timestamp is ignored, not treated as a rate")
    func nonIncreasingTimeIsIgnored() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 1_000, sent: 1_000),
            NetworkCounters(received: 2_000, sent: 2_000)
        ])
        let sampler = NetworkSampler(reader: reader)

        _ = sampler.sample(now: 5)
        // `now` did not advance — should not divide by zero or go negative.
        let reading = sampler.sample(now: 5)

        #expect(reading.downloadBytesPerSecond == nil)
        #expect(reading.uploadBytesPerSecond == nil)
    }

    @Test("A failed read returns .initial without disturbing the baseline")
    func failedReadReturnsInitial() {
        let reader = StubNetworkCounterReader(readings: [
            NetworkCounters(received: 1_000, sent: 1_000),
            nil,
            NetworkCounters(received: 3_000, sent: 3_000)
        ])
        let sampler = NetworkSampler(reader: reader)

        _ = sampler.sample(now: 0)
        let failed = sampler.sample(now: 1)
        #expect(failed.downloadBytesPerSecond == nil)

        // Baseline from `now: 0` should still be intact for the rate calc —
        // elapsed is (2 - 0) = 2s, delta is (3000 - 1000) = 2000 → 1000 B/s.
        let recovered = sampler.sample(now: 2)
        #expect(recovered.downloadBytesPerSecond == 1_000)
    }
}