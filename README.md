# islet

A macOS menubar app that puts a Dynamic Island-style live activity HUD in your MacBook's notch. Displays now-playing, volume, weather, system stats, clipboard history, camera/mic status, build output, and more — all in a pill-shaped overlay that animates over the notch.

Requires macOS 12.0+. Works best on MacBooks with a physical notch (M1 Pro/Max, M2, M3 series). Falls back to a top-of-screen position on non-notched Macs.

---

## Install from DMG (easiest)

1. Download `Islet.dmg` from the [Releases](../../releases) page
2. Open the DMG — a Finder window appears with the Islet icon and an Applications shortcut
3. Drag **Islet** into **Applications**
4. Eject the DMG
5. Open **Islet** from Applications or Spotlight

> **Gatekeeper warning on first launch:** macOS may say "Islet can't be opened because it's from an unidentified developer." To get past this:
> - Right-click (or Control-click) `Islet.app` → **Open** → click **Open** in the dialog
> - You only need to do this once

Once running, Islet has no Dock icon. Look for the small icon in your **menu bar** (top-right area). The island HUD will appear over your notch automatically when there is activity to show.

---

## Install from source

### Prerequisites

- **Xcode** (free, from the Mac App Store or https://developer.apple.com/download/all/)
- macOS 12.0 or later

After installing Xcode, run once in Terminal to accept the license and point the toolchain:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version   # should print Xcode 16.x
```

### Build and run

```bash
git clone https://github.com/YOUR_USERNAME/islet.git
cd islet

xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build \
  2>&1 | grep -E "(error:|warning:|BUILD)"

open .build/xcode/Build/Products/Debug/Islet.app
```

### Build a DMG for distribution

```bash
./scripts/build-dmg.sh
# Output: dist/Islet.dmg

# To also ad-hoc sign the app (reduces Gatekeeper friction):
./scripts/build-dmg.sh --sign
```

The DMG is written to `dist/Islet.dmg`. You can attach it to a GitHub Release or share it directly.

---

## Usage

- **Island appears automatically** when there is something to show (volume change, music playing, camera active, etc.)
- **Hover** over the island to expand it and see more detail
- **Click** on content to trigger the primary action (e.g. click a clipboard item to copy it, click the restore button to undelete a file)
- **Right-click** the island for a context menu (Dismiss, Settings)
- **Menu bar icon** → Settings to configure modules, clipboard size, weather refresh rate, environment configs, and island position offset

### `island-notify` CLI

Pipe any build tool's output into the island:

```bash
xcodebuild 2>&1 | island-notify --mode build
npm run build 2>&1 | island-notify --mode build
tail -f /var/log/system.log | island-notify --mode log
```

`island-notify` is built as part of the Xcode project and needs to be on your PATH:

```bash
# After building, install the CLI:
cp .build/xcode/Build/Products/Debug/island-notify /usr/local/bin/
```

---

## Permissions

On first launch the app will request:

| Permission | Used for |
|---|---|
| Notifications | Showing system notifications inside the island instead of as banners |
| Microphone | FFT audio spectrum visualization |
| Location | Fetching local weather (falls back to IP geolocation if denied) |
| Bluetooth | Showing battery level of connected peripherals |
| Accessibility | Global keyboard shortcut for the color sampler (⌥⇧C) |

All permissions are optional — denying one disables that feature, everything else keeps working.
