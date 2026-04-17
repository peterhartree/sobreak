# TakeBreak

Menu bar break reminder app for macOS.

## Install target: MacBook Pro only

**Do not install on `mini`.** The Mac Mini is a headless agent host with no one sitting in front of it — break reminders there are pointless and will spam `/tmp/break-reminder.log`.

`install.sh` enforces this with a hostname guard (refuses to run when `LocalHostName` is `mini`). If you're syncing this folder between machines via Syncthing, only run `./install.sh` on `mbp`.

To rebuild and reinstall on mbp: `./install.sh`

## Deploy

Deploy builds, tags, pushes to GitHub, creates a release with a zip, and updates the homebrew tap (`peterhartree/homebrew-takebreak`).

```bash
./deploy.sh <version>   # e.g. ./deploy.sh 1.2.0
```

The script:
1. Builds the release app bundle (`build.sh`)
2. Zips `TakeBreak.app` and computes SHA256
3. Pushes main to GitHub
4. Creates a tagged GitHub release with the zip attached
5. Clones the homebrew tap, updates the cask version + SHA256, pushes

**Prerequisites:** `gh` CLI authenticated, push access to both repos.

## Development

- `./build.sh` — build release
- `./build.sh --debug` — build with short timers (5s work duration)
- `./install.sh` — build + install to ~/Applications + LaunchAgent
- `Cmd+Option+D` — cycle through debug preview states (all views)
- `Cmd+Option+T` — start 25 min pomodoro timer
- `mockup.html` — HTML mockup of all views for rapid UI iteration
