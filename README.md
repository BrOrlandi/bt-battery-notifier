# BT Battery

A lightweight macOS menubar app that monitors your Bluetooth devices and notifies you about battery levels when they connect or disconnect.

## Features

- **Disconnect notifications** — get notified with the last known battery level when a device disconnects
- **Connect notifications** — optionally see battery status when a device connects
- **Low battery warnings** — configurable threshold to alert you when battery is low
- **Multi-battery support** — shows individual levels for devices like AirPods (left, right, case)
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
| Always notify on disconnect | On | Send a notification every time a device disconnects |
| Battery threshold | 50% | When "always notify" is off, only notify below this level |
| Notify on connect | Off | Send a notification when a device connects |
| Launch at login | Off | Start the app automatically at login |

## How it works

The app polls paired Bluetooth devices every 15 seconds using the IOBluetooth framework. It tracks connection state changes and caches battery values so the last known level is available even after a device disconnects.

## License

MIT
