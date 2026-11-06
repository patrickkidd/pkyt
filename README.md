# pkyt

A personal iOS app: paste a YouTube link and it plays, with audio continuing in the background and on the lock screen (play/pause/scrub/±15s from the lock screen and Control Center). Starts at the link's `t=`/`start=` time. Streams are extracted on-device with [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit), falling back to its remote extractor.

- **Paste & Play** reads the clipboard and plays it.
- Opening the app with a new YouTube link on the clipboard plays it automatically. To skip iOS's "Allow Paste" prompt, set Settings > pkyt > Paste from Other Apps > Allow.
- Two tabs along the bottom: **Home** (feed and search) and **Playlist** (the link field, player and downloads).
- **Audio** and **Video** under the video save it for offline playback: Audio is the best audio-only m4a, Video the best combined MP4 (an error shows if the video has none). Each kind is saved once per video and continues with the phone locked. Downloads list below the video with an AUDIO or VIDEO badge: tap to play, long-press and drag to reorder, swipe left to delete. When one finishes, the next in the list plays; playback stops after the last.
- `pkyt://play?url=<url-encoded link>` plays a link (for an iOS Shortcut).

## Rebuild and reinstall

Needs Xcode signed in to your Apple developer account, xcodegen, and the iPhone connected or on the same network. Create a git-ignored `.env`:

    PKYT_TEAM=<Apple team ID>
    PKYT_DEVICE=<CoreDevice id from `xcrun devicectl list devices`>

then run:

    ./scripts/install.sh

The paid-team provisioning profile lasts 1 year; after it expires the app will not launch until you run the script again.

## Tests

    PKYT_TEAM=<team> xcodegen generate && xcodebuild test -project pkyt.xcodeproj -scheme pkyt -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
