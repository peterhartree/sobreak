# TakeBreak

Menu bar break reminder app for macOS.

## Install target: MacBook Pro only

**Do not install on `mini`.** The Mac Mini is a headless agent host with no one sitting in front of it — break reminders there are pointless and will spam `/tmp/break-reminder.log`.

`install.sh` enforces this with a hostname guard (refuses to run when `LocalHostName` is `mini`). If you're syncing this folder between machines via Syncthing, only run `./install.sh` on `mbp`.

To rebuild and reinstall on mbp: `./install.sh`
