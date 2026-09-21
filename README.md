<p align="center">
  <img src="docs/branding/app-icon-1024.png" width="128" alt="NetSpeed app icon">
</p>

<h1 align="center">NetSpeed</h1>

<p align="center">
  A tiny macOS menu-bar utility that displays current network download and upload speed.
</p>

<p align="center">
  <a href="https://github.com/bilalsh/NetSpeed/actions/workflows/build.yml"><img src="https://github.com/bilalsh/NetSpeed/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <a href="https://github.com/bilalsh/NetSpeed/releases/latest"><img src="https://img.shields.io/github/v/release/bilalsh/NetSpeed" alt="Release"></a>
</p>

Built for personal use on modern macOS.

<p align="center">
  <img src="docs/screenshots/menu-bar-both.png" alt="NetSpeed showing download and upload speed in the menu bar">
  &nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/menu-bar-download-only.png" alt="NetSpeed showing only download speed in the menu bar">
</p>

<p align="center">
  <img src="docs/screenshots/settings.png" width="380" alt="NetSpeed settings window">
</p>

## Display

```text
↓ 1.2 MB/s
↑ 84 kB/s
```

Traffic below 1 KiB/s is displayed as 1 kB/s when non-zero.

## Settings

Choose **Settings…** (⌘,) from the menu-bar item to configure:

- **Show download speed** / **Show upload speed**: show either line, or both. At least one always stays on.
- **Font size**: Small (9 pt), Medium (10 pt, default) or Large (11 pt).
- **Launch at login**: enabled automatically on first run; turn it off any time.

## Download

Grab the latest `NetSpeed-x.y.z.zip` from the [Releases](https://github.com/bilalsh/NetSpeed/releases/latest) page, unzip it, and move `NetSpeed.app` to `/Applications`. Moving it there before first launch means launch-at-login points at a stable location.

The app is ad-hoc signed and not notarized, so on first launch right-click → **Open** (or run `xattr -cr /Applications/NetSpeed.app`).

## Build

Requires Swift 6.2 and macOS 26.

```sh
./build.sh
open NetSpeed.app
```

Launch-at-login registers the app's location, so for a stable login item build
and install to `/Applications`:

```sh
./build.sh --install
```

## Project layout

```text
.github/workflows/         CI build and release workflows
Sources/NetSpeed/          Swift sources
Resources/AppIcon.iconset  App icon at all macOS sizes (built into AppIcon.icns)
docs/branding/             Icon and GitHub social-preview artwork (SVG + PNG)
build.sh                   Builds, signs and optionally installs NetSpeed.app
LICENSE                    GNU General Public License v3.0
```

## App icon

The master artwork is `docs/branding/app-icon.svg`. The rendered icon set in
`Resources/AppIcon.iconset` is committed, and `build.sh` turns it into
`AppIcon.icns` with `iconutil`.

To change the icon, edit the SVG, export it as PNGs at the sizes macOS expects
(16, 32, 128, 256 and 512 px, each with an `@2x` variant, e.g. `icon_16x16.png`
and `icon_16x16@2x.png`) into `Resources/AppIcon.iconset`, and rebuild. Use a
renderer with full SVG filter support, such as Chromium or Inkscape.

## Notes

Network traffic is measured from system interface byte counters and sampled once per second.

The project is intentionally minimal and has no external dependencies.

## License

NetSpeed is licensed under the GNU General Public License v3.0 or later. See
[LICENSE](LICENSE).

`NetworkCounterReader.swift` and `NetworkSampler.swift` are adapted from
[vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils), also
GPL-3.0-or-later. Their original copyright notices are kept in the file headers.
