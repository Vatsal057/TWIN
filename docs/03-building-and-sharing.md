# 03 — Building and sharing

How to produce the app files, put the web version online, and get a link that
works for everyone.

---

## Two people, two cities — what actually happens

1. You tap **Create room**. You pick a round limit and tie rule, and get a
   5-character code like `K7RQP`.
2. You share the code or the link. This happens **outside the app** — WhatsApp,
   SMS, whatever you already use. There's no friend-request system to build.
3. Your friend taps the link or types the code.
4. Both of you drop into round 1 at the same instant.

Step 4 works because both apps are *watching* the room's record in the database.
The moment your friend's name gets added, both screens change. Nobody is polling
or refreshing.

### About the room code

Five characters, from this alphabet:

```
ABCDEFGHJKMNPQRSTUVWXYZ23456789
```

Notice what's missing: **I, L, O, 0, 1**. Those are the characters people misread
when a code is read aloud or copied from a screenshot.

Two people can never get the same code. When the app makes one, it checks and
claims it in a single database operation, so there's no gap where another phone
could grab the same one.

---

## The share link

```
https://twinnn.web.app/join?code=K7RQP
```

One link, and nobody hits a dead end:

| Who taps it | What they get |
| --- | --- |
| Android, app installed | The app opens, straight into the room |
| Phone without the app | The game runs in their browser |
| Anyone on a laptop | The game runs in their browser |

The share message also includes the plain code, so typing it in always works as a
backup.

### Why there's a web version at all

Without it, sending a link to someone who doesn't have the app is useless. The web
version means anyone can play immediately, which is the whole point of a link.

### The Firebase Dynamic Links thing

If you search for how to do app links with Firebase, you'll find **Firebase
Dynamic Links**. Don't use it. Google shut it down on 25 August 2025 and existing
links stopped working.

This project uses the native replacements instead: **Android App Links** for the
https link, and a custom `twin://` scheme as a backup. The custom scheme
works with no setup at all, but most chat apps won't turn it into something
tappable, so it's a fallback rather than the main path.

---

## How App Links work (and how to not break them)

An App Link is an https link that opens an app instead of a browser. Android only
allows this if the *website* vouches for the *app*. That proof is a file:

```
https://twinnn.web.app/.well-known/assetlinks.json
```

It contains the app's package name and a fingerprint of the key used to sign the
app. Android downloads it, checks the fingerprint matches the installed app, and
only then starts opening links in the app.

You can check it yourself with Google's own verification API:

```bash
curl -s "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://twinnn.web.app&relation=delegate_permission/common.handle_all_urls"
```

If it says `"errorCode"` anything, links won't open the app.

### The trap to remember

The fingerprint in that file must match the key that signs your app.

**Right now it's the debug key.** Flutter signs release builds with a debug key
until you set up a proper signing config — the template even says so in
`android/app/build.gradle.kts`.

The day you add a real release key, links will silently stop opening the app.
Nothing errors; they just open the browser instead. To fix it:

```bash
keytool -list -v -keystore your-release.keystore -alias your-alias | grep SHA256
```

Put that value in `web/well-known/assetlinks.json`, then redeploy:

```bash
./tools/build_web.sh --deploy
```

### Why the folder is `well-known` and not `.well-known`

The web server needs it at `/.well-known/`, with a dot. But Flutter's build step
doesn't copy dot-prefixed folders out of `web/`. So the file lives at
`web/well-known/` and `tools/build_web.sh` renames it into place after building.

There's a matching trap in `firebase.json`. The default Firebase config includes
this line:

```json
"ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
```

That `"**/.*"` means "skip everything starting with a dot" — which skips
`.well-known` and quietly breaks App Links. It's been removed from this project's
config, with a comment explaining why.

---

## Building the phone app

```bash
flutter build apk --release --split-per-abi
```

| File | Size | Use it for |
| --- | --- | --- |
| `app-arm64-v8a-release.apk` | 24.5 MB | Basically every modern phone |
| `app-armeabi-v7a-release.apk` | 22.0 MB | Older 32-bit phones |
| `app-x86_64-release.apk` | 25.9 MB | Emulators |

`--split-per-abi` makes one file per processor type. Without it you get a single
file with all three bundled in, which is much bigger for no benefit.

Of that 24.5 MB, about 5.4 MB is the word dictionary.

---

## Building the website

```bash
./tools/build_web.sh                # build only
./tools/build_web.sh --deploy       # build and put it online
```

### Why the folder is 41 MB but the download is 8 MB

`build/web` contains every graphics engine Flutter might use — about 31 MB of
them. A browser downloads only the one it needs.

Actual first visit, after compression:

| Piece | Size |
| --- | --- |
| App code | 0.8 MB |
| Graphics engine (one) | 1.5–2.7 MB |

So roughly 2–3.5 MB, then cached.

This used to be 7–8 MB. Removing the scoring system removed a bundled 5 MB word
table with it, which was two thirds of the download.

### No service worker, on purpose

The build passes `--pwa-strategy=none`, so there's no offline caching layer. This
is deliberate: Flutter's service worker keeps serving the previous build after a
deploy until every tab is closed, which makes updates unpredictable.

**That flag is deprecated** ([flutter/flutter#156910](https://github.com/flutter/flutter/issues/156910))
and will be removed. So `tools/build_web.sh` checks the *outcome* rather than
trusting the flag, and fails the build if a worker reappears:

- `flutter_service_worker.js` must be 0 bytes (Flutter's placeholder)
- the generated tail of `flutter_bootstrap.js` must read `_flutter.loader.load();`
  with no arguments

Don't "simplify" that check by grepping `flutter_bootstrap.js` for
`serviceWorkerVersion`. That string lives in the minified loader library and is
present either way — it produces a false failure. Only a version with an actual
value assigned (`serviceWorkerVersion:"..."`) means a worker is registered.

`tools/sw_killswitch.js` is staged over the build output under the original
filename. It removes any worker a browser already has, then reloads the tab. Leave
it in place — it's harmless once a browser has run it, and removing it would strand
anyone who hasn't visited since.

Cache headers matter as much as the worker. Entry points are `no-cache`:

| File | Cache |
| --- | --- |
| `/`, `index.html`, `main.dart.js`, bootstrap | `no-cache` |
| Renderer (`canvaskit/`) | 1 week |

`main.dart.js` needs `no-cache` because its filename never changes between builds.
And `/` needs its own header rule — a rule for `/index.html` does not match a
request for the root.

## Using your own domain

```bash
TWIN_WEB_HOST=play.example.com ./tools/build_web.sh --deploy
```

Then two more edits:

1. In `android/app/src/main/AndroidManifest.xml`, change `android:host` to your
   domain.
2. In Firebase Console → Hosting, add the custom domain.

One thing to watch: `*.web.app` and `*.firebaseapp.com` are automatically trusted
by Firebase sign-in. A custom domain is not — you have to add it under
**Authentication → Settings → Authorized domains**, or sign-in will fail on the
new domain.
