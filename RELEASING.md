# Building & Releasing

Guide for building, versioning, and publishing releases of BT Battery Notifier.

## Build Types

### Development Build

For local testing. No code signing — faster iteration.

```bash
cd macos-app
bash build.sh
```

The `.app` bundle is generated at `macos-app/build/BT Battery Notifier.app`.

### Release Build

Includes code signing with your Apple Development certificate. Required for TCC permissions (Bluetooth, Notifications) to persist across rebuilds.

```bash
cd macos-app
bash build.sh --release
```

The build script auto-detects the first Apple Development certificate via `security find-identity`. If none is found, it falls back to ad-hoc signing.

### Install Locally

Builds with release signing, copies to `/Applications`, and launches the app:

```bash
cd macos-app
bash install.sh
```

## Versioning

The project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`):

- **MAJOR** — breaking changes or significant redesigns
- **MINOR** — new features (e.g., new language, new notification type)
- **PATCH** — bug fixes and small improvements

The version is defined in two places in `macos-app/Resources/Info.plist`:

- `CFBundleVersion` — build number
- `CFBundleShortVersionString` — display version

Both must be updated together to the same value.

### Bumping the Version

1. Edit `macos-app/Resources/Info.plist` and update both `CFBundleVersion` and `CFBundleShortVersionString`
2. Commit the change:

```bash
git add macos-app/Resources/Info.plist
git commit -m "chore: bump version to X.Y.Z"
```

## Creating a Release

### 1. Bump the version

Update `Info.plist` as described above and commit.

### 2. Build the release

```bash
cd macos-app
bash build.sh --release
```

### 3. Create the release zip

```bash
cd macos-app/build
zip -r "BT-Battery-Notifier-X.Y.Z.zip" "BT Battery Notifier.app"
```

### 4. Push and create the GitHub release

```bash
git push

gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes "release notes here" \
  macos-app/build/BT-Battery-Notifier-X.Y.Z.zip
```

Or use a heredoc for multi-line release notes:

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes "$(cat <<'EOF'
## Bug Fixes

- **Fix description**: details about what was fixed and why.

## New Features

- **Feature description**: details about what was added.
EOF
)" macos-app/build/BT-Battery-Notifier-X.Y.Z.zip
```

## Release Notes Guidelines

### Structure

Use sections to categorize changes. Common sections:

- **New Features** — for `feat` commits
- **Bug Fixes** — for `fix` commits
- **Improvements** — for `refactor` or performance changes
- **Breaking Changes** — for anything that changes existing behavior

### Format

Each item should be a bullet point with a **bold title** followed by a description:

```markdown
## Bug Fixes

- **Fix battery reads after sleep**: IOBluetooth framework becomes stale after
  macOS sleep/wake cycles. Added subprocess fallback for reliable readings.
```

### What to Include

- Describe the **user-facing impact**, not implementation details
- Mention the **affected device or scenario** when relevant
- For bug fixes, briefly describe **what was broken** and **what changed**

### Footer Note

For releases distributed outside the App Store, include this note:

```markdown
---

> **Note:** Built for Apple Silicon (M1/M2/M3/M4). Not signed with Apple
> Developer ID — on first open, right-click > Open, or allow in
> System Settings > Privacy & Security.
```

## Commit Convention

The project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
type: description
```

Types used:

| Type       | When to use                          |
|------------|--------------------------------------|
| `feat`     | New feature                          |
| `fix`      | Bug fix                              |
| `docs`     | Documentation changes                |
| `chore`    | Version bumps, build changes, config |
| `refactor` | Code restructuring without behavior change |

## Checklist

Before publishing a release:

- [ ] Version bumped in `Info.plist` (both fields)
- [ ] Version bump committed
- [ ] Release build succeeds (`build.sh --release`)
- [ ] App tested locally (`install.sh`)
- [ ] Zip created with correct version in filename
- [ ] All changes pushed to `main`
- [ ] GitHub release created with tag `vX.Y.Z`
- [ ] Release notes describe user-facing changes
- [ ] Zip attached to the release
