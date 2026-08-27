# 06 — Changing things

Common edits, and what to watch out for with each.

---

## Change the round limit options

The choices shown when creating a room:

`lib/core/game_config.dart`

```dart
static const presetLimits = <int?>[null, 5, 10, 15, 25];
```

`null` means "no limit". Add or remove numbers freely.

The absolute ceiling is separate:

```dart
static const hardCeiling = 500;
```

Raising that is risky. The full round history is stored inside one database record
and Firebase caps a record at 1 MB. At roughly 200 bytes a round, 500 uses about
100 KB. Going far beyond a few thousand would eventually break saving mid-game.

---

## Change how strict a tie is

`lib/core/game_config.dart`

```dart
this.tieThreshold = 0.02,
```

Two words within 2% closeness count as a tie. Raise it for more ties, lower it for
fewer.

Don't go below about `0.001`. Squashing the dictionary numbers introduced a tiny
error of `0.000057`, and a threshold near that size would make results depend on
rounding noise rather than the words.

---

## Change the word dictionary size

```bash
python3 tools/build_embeddings.py \
  --input glove.6B.50d.txt \
  --output assets/embeddings/glove50.nkem \
  --limit 30000
```

Roughly 112 bytes per word, so:

| Words | File size |
| --- | --- |
| 20,000 | 2.2 MB |
| 30,000 | 3.4 MB |
| 50,000 | 5.4 MB (current) |

**Rebuild every version at the same time.** Phones and the website must have the
identical file. If they differ, they'll score words differently, and since either
device can be the one that records a round result, you'd get inconsistent history.
Doc 04 explains why.

Fewer words also means more "unknown word, scores 0" for players.

---

## Change which words the app never suggests

`lib/services/embeddings/glove_similarity.dart`, the `_unplayable` set.

These are excluded from the practice opponent's choices and from the post-game
"closest words" list. Players can still type them — this only affects suggestions
the app makes itself.

Add a word if the bot keeps playing something that feels like cheating.

---

## Change the colours

`lib/ui/app_theme.dart`

```dart
static const seed = Color(0xFFE0A93B);       // amber accent
static const ink = Color(0xFF14120F);        // background
static const parchment = Color(0xFFF3EADA);  // text
static const playerOne = Color(0xFFE0A93B);  // host's words
static const playerTwo = Color(0xFF6FB3C6);  // guest's words
static const converged = Color(0xFF7FC08A);  // matched
```

If you change `ink`, also change it in two other places or the web page will flash
the old colour before the app loads:

- `web/index.html` — the `background-color` in the style block
- `web/manifest.json` — `background_color` and `theme_color`

Careful with lightening the faded text. Several labels sit around 60% opacity,
which was chosen to stay readable. Going much lower makes them fail contrast
guidelines.

---

## Change how long the reveal lasts

`lib/state/game_controller.dart`

```dart
static const revealDuration = Duration(milliseconds: 2600);
```

Players can always tap to skip ahead.

---

## Use your own domain

```bash
NAAMKARAN_WEB_HOST=play.example.com ./tools/build_web.sh --deploy
```

Then three more things:

1. `android/app/src/main/AndroidManifest.xml` — change `android:host` to match.
2. Firebase Console → Hosting → add the custom domain.
3. Firebase Console → Authentication → Settings → **Authorized domains** → add it.

Step 3 is the one people forget. `*.web.app` is trusted automatically; your own
domain isn't, and sign-in will fail without it.

---

## Set up a real signing key

Right now release builds are signed with a debug key, which is fine for sharing
files directly but not for the Play Store.

After creating a proper key, **you must update the App Links fingerprint** or
shared links will stop opening the app — silently, with no error.

```bash
keytool -list -v -keystore your-release.keystore -alias your-alias | grep SHA256
```

Put that in `web/well-known/assetlinks.json`, then:

```bash
./tools/build_web.sh --deploy
```

Verify it took:

```bash
curl -s "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://YOUR-HOST&relation=delegate_permission/common.handle_all_urls"
```

You want `errors: none`.

---

## Add iOS

Partly ready — the custom URL scheme is registered in `ios/Runner/Info.plist`.

Still to do:

1. `flutterfire configure --platforms=ios` and add the downloaded
   `GoogleService-Info.plist` to the Runner target in Xcode.
2. Install CocoaPods (`brew install cocoapods`) — it isn't installed here, which is
   why iOS was never built.
3. For Universal Links (the iOS equivalent of App Links): host an
   `apple-app-site-association` file and add the
   `com.apple.developer.associated-domains` entitlement.

That entitlement was deliberately left out. Adding it without a matching Apple
provisioning profile breaks local builds, which is a bad trade before you need it.

---

## Make scores tamper-proof

Only worth doing if you stop trusting the players.

Today each device works out the round result and one of them records it. The rules
can check the shape of what's written but can't recalculate the numbers, so a
modified app could award itself points.

To close that:

1. Move the logic in `FirestoreBackend.commitRound` into a Cloud Function.
2. Change the rules so clients can't write `rounds` or `scores`.
3. Have the app call the function instead of writing directly.

The `GameBackend` interface exists partly so this swap touches one file. Note it
requires the Blaze plan, since Cloud Functions aren't on the free tier.

---

## Before you ship any change

```bash
flutter analyze                              # no issues
flutter build apk --release --split-per-abi   # phone app builds
./tools/build_web.sh                         # website builds
```

If you touched the rules:

```bash
firebase deploy --only firestore:rules --project naamkaran-31493
```

If you touched anything Firebase-related, open the app and confirm the amber
"not configured" box is **absent**. That box is the fastest signal that something
in the Firebase wiring broke.
