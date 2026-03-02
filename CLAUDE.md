# BT Battery - Project Guide

## Overview

macOS menubar app that monitors Bluetooth device battery levels and sends notifications on disconnect/connect events. Built with Swift, no Xcode project — compiled directly with `swiftc`.

## Project Structure

```
macos-app/
  Sources/
    App.swift            # NSApplication entry point, menubar widget, popover
    BluetoothDevice.swift # IOBluetooth device scanning via private APIs
    BluetoothMonitor.swift # Polling loop, state management, notifications
    NotificationManager.swift # UNUserNotificationCenter wrapper
    Settings.swift       # UserDefaults-backed settings (ObservableObject)
    SettingsView.swift   # SwiftUI settings popover
  Resources/
    Info.plist           # Bundle config (LSUIElement, bundle ID)
  build.sh              # Compile + optional codesign
  install.sh            # Build, kill, copy to /Applications, launch
```

## Build & Run

```bash
cd macos-app
bash build.sh           # Dev build (no codesign)
bash build.sh --release # Release build (codesigned)
bash install.sh         # Build + install to /Applications + launch
```

## Code Signing

**Only sign release builds** (`--release` flag). Signing on every dev build is unnecessary and slows iteration.

Why signing matters for release:
- macOS TCC (Transparency, Consent, Control) ties permissions (Bluetooth, Notifications) to the app's code signature
- Ad-hoc signing (`--sign -`) generates a different hash each build, causing macOS to re-prompt for Bluetooth permission on every launch
- Signing with an Apple Development certificate keeps a stable identity, so permissions persist across rebuilds
- The build script auto-detects the first Apple Development certificate via `security find-identity`

## Key Technical Details

- **No Xcode project**: Everything is compiled via `swiftc` in `build.sh`
- **IOBluetooth private APIs**: Battery levels are read via `perform(selector:)` on `IOBluetoothDevice` (batteryPercentSingle, batteryPercentLeft, batteryPercentRight, batteryPercentCase, isMultiBatteryDevice)
- **NSLog over print()**: Always use `NSLog` for logging — `print()` output is invisible in macOS GUI apps. Use `NSLog("%@", interpolatedString)` to avoid format string issues with `%` in battery percentages
- **Deferred first poll**: `IOBluetoothDevice.pairedDevices()` can block if called before the main runloop starts. The first poll is deferred via `DispatchQueue.main.async`
- **Battery caching**: Battery values are carried over from previous polls when current reading is 0 (device may not report battery every poll). State is persisted to UserDefaults across app restarts
- **UI language**: All user-facing strings are in Portuguese (pt-BR)
