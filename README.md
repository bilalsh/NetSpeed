# NetSpeed

A tiny macOS menu-bar utility that displays current network download and upload speed.

Built for personal use on modern macOS.

## Display

```text
↓ 1.2 MB/s
↑ 84 KB/s
```

Traffic below 1 KiB/s is displayed as 1 kB/s when non-zero.

## Build

Requires Swift and macOS.

```sh
./build.sh
open NetSpeed.app
```

## Notes

Network traffic is measured from system interface byte counters and sampled once per second.

The project is intentionally minimal and has no external dependencies.

## Acknowledgements

The network counter reader and sampler are adapted from
[vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils),
copyright © 2026 Vorssaint, used under the GPL-3.0-or-later.

## License

NetSpeed is licensed under the [GNU General Public License v3.0 or later](LICENSE).