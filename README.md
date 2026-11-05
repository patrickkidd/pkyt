# pkyt

A personal iOS app: paste a YouTube link and it plays, with audio continuing in the background and on the lock screen (play/pause/scrub/±15s from the lock screen and Control Center). Starts at the link's `t=`/`start=` time. Streams are extracted on-device with [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit), falling back to its remote extractor.

- **Paste & Play** reads the clipboard and plays it.
- Opening the app with a new YouTube link on the clipboard plays it automatically. To skip iOS's "Allow Paste" prompt, set Settings > pkyt > Paste from Other Apps > Allow.
- `pkyt://play?url=<url-encoded link>` plays a link (for an iOS Shortcut).

## Rebuild and reinstall

Needs Xcode signed in to your Apple developer account, xcodegen, and the iPhone connected or on the same network. Create a git-ignored `local.env`:

    PKYT_TEAM=<Apple team ID>
    PKYT_DEVICE=<CoreDevice id from `xcrun devicectl list devices`>

then run:

    ./scripts/install.sh

The paid-team provisioning profile lasts 1 year; after it expires the app will not launch until you run the script again.

## Tests

    PKYT_TEAM=<team> xcodegen generate && xcodebuild test -project pkyt.xcodeproj -scheme pkyt -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
