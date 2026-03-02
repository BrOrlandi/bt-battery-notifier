# BT Battery

A lightweight macOS menubar app that monitors your Bluetooth devices and notifies you about battery levels when they connect or disconnect.

## Features

- **Menubar battery display** — show battery levels for selected devices right in the menubar (icon, percentage, or both)
- **Multi-device support** — monitor multiple Bluetooth devices simultaneously
- **Instant disconnect notifications** — get notified with the last known battery level the moment a device disconnects
- **Connect notifications** — optionally see battery status when a device connects
- **Low battery warnings** — configurable threshold to alert you when battery is low
- **Multi-battery support** — shows individual levels for devices like AirPods (left, right, case)
- **Battery persistence** — remembers battery levels across app restarts
- **Launch at login** — start automatically when you log in
- **Menubar only** — runs quietly in the menubar with no dock icon

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone https://github.com/BrOrlandi/notify-bt-battery.git
cd notify-bt-battery
bash macos-app/install.sh
```

This builds the app, copies it to `/Applications`, and launches it.

## Uninstall

```bash
bash macos-app/uninstall.sh
```

## Settings

Click the battery icon in the menubar to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Menubar devices | None | Select which devices show battery in the menubar |
| Display mode | Icon + % | Choose icon only, percentage only, or both |
| Always notify on disconnect | On | Send a notification every time a device disconnects |
| Low battery notification | On | Notify when battery is below threshold on disconnect |
| Battery threshold | 50% | Low battery level for notifications |
| Notify on connect | Off | Send a notification when a device connects |
| Launch at login | Off | Start the app automatically at login |

## How it works

The app uses the IOBluetooth framework to monitor paired Bluetooth devices. It registers for real-time connect/disconnect events for instant notifications, and polls every 15 seconds to keep battery levels up to date. Battery values are cached so the last known level is available even after a device disconnects, and state is persisted across app restarts.
