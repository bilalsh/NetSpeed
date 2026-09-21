// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is adapted from the network counter implementation in
// vorssaint/vorssaint-utils.
// Original project: https://github.com/vorssaint/vorssaint-utils
//
// Copyright (C) 2026 Vorssaint
//
// This adapted work is distributed under the terms of the
// GNU General Public License version 3 or later.

import Darwin

struct NetworkCounters: Equatable, Sendable {
    var received: UInt64 = 0
    var sent: UInt64 = 0
}

struct NetworkCounterReader {

    func read() -> NetworkCounters? {
        var mib: [Int32] = [
            CTL_NET,
            PF_ROUTE,
            0,
            0,
            NET_RT_IFLIST2,
            0
        ]

        var length = 0

        guard sysctl(
            &mib,
            6,
            nil,
            &length,
            nil,
            0
        ) == 0, length > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: length)

        guard sysctl(
            &mib,
            6,
            &buffer,
            &length,
            nil,
            0
        ) == 0 else {
            return nil
        }

        var counters = NetworkCounters()

        buffer.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var offset = 0
            let headerSize = MemoryLayout<if_msghdr>.size

            while offset + headerSize <= length {
                let header = baseAddress
                    .advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr.self)
                    .pointee

                let messageLength = Int(header.ifm_msglen)

                guard messageLength > 0,
                      offset + messageLength <= length else {
                    break
                }

                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {

                    let info = baseAddress
                        .advanced(by: offset)
                        .assumingMemoryBound(to: if_msghdr2.self)
                        .pointee

                    var nameBuffer = [CChar](
                        repeating: 0,
                        count: Int(IFNAMSIZ)
                    )

                    if if_indextoname(
                        UInt32(info.ifm_index),
                        &nameBuffer
                    ) != nil {
                        let name = nameBuffer.prefix {
                            $0 != 0
                        }

                        let interfaceName = String(
                            decoding: name.map { UInt8(bitPattern: $0) },
                            as: UTF8.self
                        )

                        if Self.shouldInclude(interface: interfaceName) {
                            counters.received += info.ifm_data.ifi_ibytes
                            counters.sent += info.ifm_data.ifi_obytes
                        }
                    }
                }

                offset += messageLength
            }
        }

        return counters
    }

    private static func shouldInclude(interface name: String) -> Bool {
        guard !name.isEmpty else {
            return false
        }

        // Physical/real network interfaces are what we're interested in.
        //
        // In particular, don't count VPN tunnels, loopback, bridges,
        // AirDrop-related interfaces, etc. alongside the physical interface,
        // otherwise the same traffic can be counted more than once.
        let excludedPrefixes = [
            "lo",
            "gif",
            "stf",
            "awdl",
            "llw",
            "nan",
            "utun",
            "bridge",
            "ap",
            "anpi",
            "p2p",
            "XHC",
            "vmenet",
            "tap",
            "tun"
        ]

        return !excludedPrefixes.contains {
            name.hasPrefix($0)
        }
    }
}