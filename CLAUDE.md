# CLAUDE.md

Guidance for Claude Code (and other coding agents) working in this repository.

## Project overview

NetSpeed is a tiny macOS menu-bar utility that displays live network download
and upload speed. It's a personal-use, intentionally minimal app: no external
dependencies, no telemetry, no unnecessary configurability.

Read `README.md` first — it covers what the app does, how it's built, and how
it's distributed. This file covers how to *work on* the repo.

## Tech stack and constraints

- **Language**: Swift 6.2 (`swift-tools-version: 6.2` in `Package.swift`)
- **Platform**: macOS 26 ("Tahoe") minimum — `.macOS(.v26)`, `LSMinimumSystemVersion` 26.0
- **UI**: AppKit for the status item / menu bar rendering, SwiftUI for the Settings window
- **App type**: `LSUIElement` (accessory app, no Dock icon), driven entirely by an `NSStatusItem`
- **Dependencies**: none. Keep it that way — a core project goal is staying dependency-free
- **Signing**: ad-hoc only (`codesign --force --deep --sign -`), not notarized
- **License**: GPL-3.0-or-later. `NetworkCounterReader.swift` and
  `NetworkSampler.swift` are adapted from
  [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils)
  (also GPL-3.0-or-later) — keep their original copyright headers intact
  when editing those files

## File structure

```text
.github/workflows/         CI build and release workflows
Sources/NetSpeed/          Swift sources
Resources/AppIcon.iconset  App icon at all macOS sizes (built into AppIcon.icns)
docs/branding/              Icon and GitHub social-preview artwork (SVG + PNG)
build.sh                   Builds, signs and optionally installs NetSpeed.app
LICENSE                    GNU General Public License v3.0
```

Key source files and their responsibilities:

| File | Responsibility |
|---|---|
| `NetSpeedApp.swift` | App entry point, `AppDelegate`, `NetworkModel` (sampling loop) |
| `AppSettings.swift` | `UserDefaults`-backed preferences + `SMAppService` login-item state |
| `NetworkSampler.swift` | Turns raw byte counters into a bytes/sec rate between two samples |
| `NetworkCounterReader.swift` | Low-level `sysctl`/`if_msghdr2` interface byte-counter reading |
| `StatusBarController.swift` | Renders the status item content as a single hand-drawn `NSImage`; menu |
| `SettingsWindowController.swift` | Hosts `SettingsView` in a plain `NSWindow` (no SwiftUI `Settings` scene) |
| `SettingsView.swift` | The Settings window UI |

## Build and run commands

Must be run on macOS with Swift 6.2 toolchain installed.

```sh
./build.sh             # build NetSpeed.app in the repo root
open NetSpeed.app

./build.sh --install   # also copy to /Applications (needed for a stable
                        # launch-at-login registration — SMAppService
                        # registers the bundle's path)
```

`build.sh` also:
- Runs `swift build -c release`
- Builds `AppIcon.icns` from `Resources/AppIcon.iconset` via `iconutil`
- Generates `Info.plist` from the `VERSION` / `BUILD_NUMBER` vars at the top of the script
- Ad-hoc signs the bundle and verifies the signature

There is no separate test command yet — no test target exists (see
"Known gaps / open questions" below).

## Coding style and standards

- Match the existing style in each file — this is a small codebase and
  consistency matters more than any external style guide.
- Conventional Swift formatting: 4-space indent, `// MARK: -` section
  dividers where a file has distinct areas of responsibility (see
  `StatusBarController.swift`, `AppSettings.swift`).
- Prefer explaining *why* over *what* in comments. This codebase already
  leans on doc comments to record non-obvious constraints (e.g. why the
  Settings window isn't a SwiftUI `Settings` scene, why status-item content
  is drawn as one bitmap instead of stacked views). Keep that up.
- Every source file carries an SPDX header and the GPL-3.0-or-later
  boilerplate — copy the existing header block into any new file. Files
  adapted from vorssaint/vorssaint-utils carry their own attribution block
  on top of that; don't merge it into the standard header.
- No external dependencies. If a task seems to need one, stop and flag it
  rather than adding it.
- Keep the app's minimalism: don't add settings, options, or UI surface
  area beyond what's asked for.

## Key architecture & integration rules

- **Settings window is a plain `NSWindow`, not a SwiftUI `Settings` scene.**
  In an `LSUIElement` app driven by an `NSStatusItem` there's no reliable way
  to open a `Settings` scene programmatically, so `SettingsWindowController`
  owns the window directly. Don't "simplify" this back to a `Settings` scene.
- **Status item content is one hand-drawn `NSImage`**, not a view hierarchy.
  `StatusBarController.renderContent` draws the glyph and one or two lines
  of text into a single bitmap with explicit Y-coordinates. This replaced an
  earlier `NSStackView` + `NSTextField` approach that fought AppKit
  auto-layout for tight two-line spacing — don't reintroduce that.
- **The menu-bar glyph is drawn from the exact path data of `app-icon.svg`**
  (see the long comment above `drawGlyph` in `StatusBarController.swift`),
  not a simplified approximation. If the icon artwork changes, the glyph
  path data needs to be regenerated to match, and the transform math
  documented in that comment re-derived.
- **Launch-at-login is never stored locally.** `AppSettings` deliberately
  does *not* persist a `launchAtLogin` flag in `UserDefaults` — the system
  owns that state via `SMAppService.mainApp.status`, since the user can
  change it in System Settings at any time outside the app. Always read
  it back from `SMAppService`, never trust a cached copy.
- **`showDownload` and `showUpload` can never both be false.** This
  invariant is enforced in both `AppSettings` (repairs bad stored state on
  init) and `SettingsView` (disables whichever toggle is the last one on).
  Preserve both enforcement points if you touch this logic.
- **Interface filtering in `NetworkCounterReader`** excludes loopback, VPN
  tunnels, bridges, AirDrop, and other virtual interfaces by prefix so the
  same traffic isn't double-counted. If you add support for a new kind of
  virtual interface on macOS, extend `excludedPrefixes` rather than
  changing the overall approach.
- **Counter resets/decreases are treated as zero rate**, not a spike, in
  both `NetworkSampler` and the reader. Preserve this when touching the
  sampling math.

## Git workflow

- **No direct pushes to `main`.** A branch ruleset on `main` enforces: no
  bypass, restrict deletions, block force pushes, require a PR (0 required
  approvals, since this is a personal-use project), require the CI build
  check to pass, require linear history, and squash/rebase merges only
  (merge commits are disallowed).
- **Always work on a feature branch**, open a PR, let CI run, then merge.
- **Conventional commits**: `feat:`, `fix:`, `chore:`, `docs:`, `build:`,
  `ci:` — small, focused commits.
- **Merge strategy**:
  - Single-commit PR → **squash merge**
  - Multi-commit PR → **rebase merge**
  - Auto-merge is enabled on the repo — typical flow is
    `gh pr merge --squash --auto` (or `--rebase --auto`), which merges
    automatically once the required CI check passes.
- **Split unrelated changes into separate PRs**, merged independently in
  order, rather than bundling them — e.g. a feature change, a version bump,
  a tag, and a README update each get their own PR rather than one big PR.
  This keeps history and review scope clean.

### Branch naming

Prefix matches the commit type, followed by a short dash-separated
description:

```text
feat/two-line-status-item
fix/counter-reset-spike
chore/remove-unused-import
docs/readme-screenshots
build/bump-version-0-2-2
ci/actions-checkout-v7
```

### Commit messages

Conventional Commits format: `<type>: <short imperative summary>`.

```text
feat: render status item as single hand-drawn NSImage
fix: treat counter decrease as zero rate instead of spike
chore: remove unused import SwiftUI from StatusBarController
docs: add menu bar and settings screenshots to README
build: bump version to 0.2.2
ci: bump actions/checkout from v4 to v7
```

Keep the summary line short and imperative; add a body only if the "why"
isn't already obvious from the diff (this repo prefers explanatory code
comments over long commit bodies — see "Coding style" above).

### Full command sequence

```sh
# 1. Branch off main
git checkout main
git pull
git checkout -b feat/short-description

# 2. Commit (small, conventional commits as you go)
git add <files>
git commit -m "feat: short imperative summary"

# 3. Push and open a PR
git push -u origin feat/short-description
gh pr create --title "feat: short imperative summary" --body "<what/why>"

# 4. Merge once CI passes — pick ONE based on commit count:
gh pr merge --squash --auto   # single-commit PR
gh pr merge --rebase --auto   # multi-commit PR

# 5. Clean up locally after merge
git checkout main
git pull
git branch -d feat/short-description
```

`--auto` queues the merge to happen automatically as soon as the required
`build` status check passes — no need to poll CI manually before merging.

## Release workflow

1. Land the feature/fix work first, as its own PR(s).
2. **Version bump PR** (separate from the feature PR, since direct pushes to
   `main` are blocked): bump both `VERSION` and `BUILD_NUMBER`
   (`CFBundleVersion`) at the top of `build.sh`. Squash merge with
   `--auto`.
3. **Verify the merge actually landed** before tagging:
   ```sh
   gh pr view <PR> --json state,mergedAt
   git show HEAD:build.sh   # confirm VERSION/BUILD_NUMBER on main
   ```
4. **Tag** `main` at the merged commit: `git tag vX.Y.Z && git push --tags`.
   Pushing a `v*` tag triggers `.github/workflows/release.yml`, which runs
   `build.sh`, zips the app with `ditto`, and publishes a GitHub release via
   `gh release create`.
5. Follow up with any README/docs PR (e.g. updated screenshots or download
   links) as its own PR, merged after the release is live.

No `CHANGELOG.md` or `CONTRIBUTING.md` — GitHub Releases serve as the
changelog, and this is a personal-use project without an external
contribution process in mind.

## Distribution notes

- Not notarized — first launch requires right-click → Open, or
  `xattr -cr /Applications/NetSpeed.app`.
- Homebrew distribution was considered and deliberately deferred: an
  official `homebrew/cask` entry needs notarization, and a personal tap was
  judged not worth it for now.

## Known gaps / open questions

- No unit test target exists yet. A test target for `NetworkSampler` has
  been discussed, but the executable target would likely need to be
  restructured into a library target first — don't assume `swift test`
  works without checking `Package.swift` first.
- If you add CI changes, note the required status check name is tied to the
  branch ruleset on `main` — renaming the build job will break the ruleset
  until it's updated to match.