# 05 — Problems we hit

Real problems from building this, what caused them, and how they were fixed. If
something breaks, check here first — there's a good chance it's one of these.

---

## "Could not create a room"

**Looked like:** Firebase was connected, but creating a room failed instantly with
a vague message.

**Actual cause:** a bug in the security rules.

To make sure a room code isn't already taken, the app reads the record it's about
to write. The rule said:

```
allow get: if signedIn()
  && (request.auth.uid in resource.data.players || ...)
```

For a record that **doesn't exist yet**, `resource` is empty. Asking for
`resource.data.players` on nothing is an error, and a rule that errors says no.

So every single room creation was blocked at the first step.

**Fix:** check for the empty case first.

```
allow get: if signedIn()
  && (resource == null
      || request.auth.uid in resource.data.players
      || resource.data.status == 'waiting');
```

**How it was confirmed:** signing in as a real anonymous user and reading a room
that doesn't exist returned `403 PERMISSION_DENIED`. After the fix, `404 NOT_FOUND`
— meaning the read was allowed, the record simply isn't there. Which is correct.

**Lesson:** in Firebase rules, always handle "the record doesn't exist" before
reading its fields.

---

## "Could not join that room" for every failure

**Looked like:** typing a code gave a vague "could not join that room", no matter
what was actually wrong.

**Cause:** all the helpful messages were being thrown from *inside* a Firestore
transaction, and the plugin wraps anything thrown in there.

`cloud_firestore_web` runs the transaction handler through
`convertWebExceptions`, so a `BackendException` raised inside comes back out as an
opaque `FirebaseException`. The error translator no longer recognised it and fell
through to the generic fallback. Five different, useful messages — your own room,
no such code, room full, game finished, network — all collapsed into one useless
sentence.

**Fix:** validate on a plain read *before* the transaction. The transaction now
only guards against two people racing for the last seat, and raises nothing of its
own.

```dart
final snapshot = await _guard(() => ref.get(), 'Could not reach that room.');
if (!snapshot.exists) throw const BackendException('No room with that code...');
// ... all the other checks, outside any transaction ...
await _guard(() => _db.runTransaction((tx) async { /* append only */ }), ...);
```

The translator also now keeps the plugin's own message text for unrecognised
codes, since that is the only clue left when something genuinely unexpected
happens.

**Lesson:** don't raise domain errors inside a Firestore transaction. Validate
first, then transact. The transaction is for atomicity, not for argument
checking.

## Typing a room code just showed "waiting for opponent"

**Looked like:** you type a valid code, the app navigates somewhere, and you land
on the lobby waiting for someone who never arrives.

**Actual cause:** you were joining **your own room**.

`joinRoom` had a branch meant to handle reconnecting after a dropped connection:
if you're already listed as a player, don't error, just carry on. Sensible. But it
also caught the case where the host types their own code — you're already a player,
so it did nothing at all and dropped you in the lobby with no explanation.

The database made this obvious. Three rooms sat like this:

```
7W3N2  waiting  1 player
HMSK7  waiting  1 player
PU6YJ  waiting  1 player
```

All created by the same person, all stuck at one player.

**Why it's easy to hit:** every player gets an anonymous ID tied to their install
or browser, and **two tabs of the same browser share one ID.** So the natural way
to test — create a room in one tab, join in another — looks exactly like the host
joining their own room, because that's what it is.

**Fix:** tell the two cases apart by whether the room is already full.

```dart
if (room.players.contains(_uid)) {
  if (!room.isFull) {
    throw const BackendException(
      'This is your own room. Send the code to the other player — you '
      'cannot be both players.',
      code: 'own-room',
    );
  }
  // genuine reconnect, carry on
}
```

**To actually test two players:** use two different browsers, a normal plus a
private window, or two devices.

## The practice opponent played nonsense (historical)

**Looked like:** the bot kept playing words like *along*, *across*, *around*,
*basin*, *blown*.

Look at that list again. They all start with a, b or c.

**Actual cause:** the dictionary file was sorted alphabetically. The code that
searched it had a setting meant to say "only look at the most common 12,000 words"
— but since the order was alphabetical, "the first 12,000 rows" actually meant
"words starting with a through c."

**Fix:** two parts.

1. The file now stores words in **frequency order**, with a separate alphabetical
   index for the lookups that need it. Now "the first 15,000 rows" genuinely means
   the 15,000 most common words.
2. Added a list of 171 function words (*the*, *of*, *around*) that never get
   suggested. Even with correct ordering, these sit near the centre of
   meaning-space and win almost any midpoint search.

**Before and after**, for the pair (king, queen):

| Before | After |
| --- | --- |
| along, across, around | prince, throne, princess |

**Lesson:** if a setting says "most common N", make sure the data is actually
ordered by commonness.

**No longer applicable.** The scoring system and its bundled word table were later
removed when the game became purely collaborative. Kept here because the mistake
— assuming an ordering the data didn't have — is an easy one to repeat.

---

## Chat panel overflowed

**Looked like:** yellow-and-black striped overflow warnings, twice, for two
different reasons.

**Problem one, 1 pixel.** The panel had a line along its top edge. That border
counts toward the panel's total height, so the bar inside was 1 pixel too tall.
Fixed by making the bar 1 pixel shorter.

**Problem two, 67 pixels.** The panel grew from 56 pixels tall to 330 when opened.
But its contents — the message list and the text box — have a minimum height of
about 120. So for the first few frames of the animation, the contents were bigger
than the box.

Fixed by switching from an animated height to `AnimatedSize`, which trims what
doesn't fit instead of complaining.

**Lesson:** if you animate a container's size, its contents must be able to
survive being small.

---

## Chat panel hidden behind the navigation bar

**Looked like:** the chat's send button sat under Android's navigation bar, or
under the gesture pill.

**Cause:** the panel is pinned to the bottom of the window and had no awareness of
the space the system reserves down there.

**Fix:** the panel now reads that reserved space and pads itself. Two details that
matter:

- The padding is **inside** the panel's background, so the background still runs
  to the very bottom of the screen. Outside, you'd see a gap.
- When the keyboard is open, the reserved space is treated as zero — the keyboard
  covers the navigation bar, so counting both would leave a floating gap.

---

## Web build wouldn't compile

**Looked like:**

```
Error: The method 'isA' isn't defined for the type 'Object'.
  if (!e.isA<JSObject>()) {
```

**Cause:** not our code. A Firebase package, `firebase_core_web` 3.11.0, contains
code that doesn't compile against this version of Flutter.

The awkward part: 3.11.0 was the **newest** version. Upgrading wasn't an option.

**Fix:** pinned an exact set of versions that work together:

```yaml
firebase_core: 4.13.0
firebase_core_web: 3.10.0
firebase_auth: 6.5.7
cloud_firestore: 6.8.0
```

Version 3.10.0 doesn't have the broken code, and 4.13.0 is the newest
`firebase_core` that accepts 3.10.0. The other two had to come down to match.

**Important:** these move together. Bumping any one pulls the broken version back
in and breaks the web build. Always run `./tools/build_web.sh` after touching them.

---

## Website showed an old version after deploying

**Looked like:** the deploy succeeded, the new code was definitely on the server,
but the browser kept showing the previous build. Reloading didn't help.

**Cause:** Flutter's web build ships a **service worker** — a script the browser
installs that caches the whole app and serves it from disk before touching the
network. Great for offline use, terrible for updates.

The specific trap: when you deploy, the new worker installs but **the old one
stays in charge until every tab of the site is closed.** So a reload, even a hard
one, still gets the old app.

**Fix, in two parts.**

First, the service worker is no longer generated. `tools/build_web.sh` passes
`--pwa-strategy=none`. This costs almost nothing here — the game needs the network
to play anyway, and the 5 MB word table is still cached by the browser's ordinary
HTTP cache.

Second, and this is the part that's easy to miss: **deleting the worker is not
enough.** A browser that already has the old one registered will keep using it
forever. It serves the cached `index.html` from its own cache, so any cleanup
script inside the page never runs.

So instead of removing the file, it's replaced with a worker whose only job is to
destroy itself — `tools/sw_killswitch.js`, staged over the build output. It takes
over immediately, deletes every cache, unregisters, and reloads open tabs.

It must keep the filename `flutter_service_worker.js`, because that's the URL
browsers already have registered.

**A second cause, found while fixing the first.** The cache headers were wrong
too. `index.html` was being served with `max-age=3600` despite a rule for it,
because the rule matched the path `/index.html` and browsers request `/`. Those
are different paths as far as the header rules are concerned.

`main.dart.js` had the same problem. Its filename never changes between builds, so
an hour of caching means up to an hour of stale app.

Now the entry points are `no-cache` and only genuinely stable files get long
caching:

| File | Cache |
| --- | --- |
| `/`, `index.html`, `main.dart.js`, bootstrap | `no-cache` |
| Renderer (`canvaskit/`) | 1 week |

**Lesson:** if a static host serves a stale page, check two things — a service
worker, and whether your header rule matches the path the browser actually
requests.

## Setup script stopped silently

**Looked like:** the script created the project and registered the Android app,
then just stopped.

**Two bugs, back to back.**

**First:** the script read the app's ID out of a table printed by the Firebase CLI.
That table is drawn with box characters (`│`), so splitting the line by spaces
returned a `│` instead of the ID. Worse, the table has no package-name column, so
the filter matched nothing at all and the ID came out empty.

Fixed by matching the ID's own shape instead — `1:<numbers>:android:<letters>` —
which doesn't care how the table is formatted.

**Second, hiding right behind it:** creating the database fails on a brand-new
project with:

```
403 Cloud Firestore API has not been used in project ... before or it is disabled
```

The create command doesn't switch the database service on. The script now switches
it on first and waits for that to take effect.

**Lesson:** don't parse pretty-printed CLI tables by column position.

---

## Anonymous sign-in can't be scripted

**Attempted:** enabling it through the web API.

**Result:**

```
BILLING_NOT_ENABLED : Identity Platform feature requires billing to be enabled.
```

**Why:** that API belongs to Identity Platform, a paid product. Plain Firebase
Authentication on the free plan is only switchable from the console.

**Do not turn on billing to get around this.** The console's "Get started" button
does exactly the same thing for free.

This is genuinely a manual step. There's no clever way around it.

---

## Gradle plugin breaks builds when config is missing

**Problem:** adding the Google services plugin the normal way makes the Android
build fail whenever `google-services.json` is absent:

```
File google-services.json is missing
```

Which means you can't build at all before setting up Firebase.

**Fix:** apply the plugin only when the file exists.

```kotlin
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("TWIN: google-services.json not found - building without Firebase.")
}
```

Now the project builds either way, and drops into Firebase mode the moment the
file appears. No code edits needed.

Both branches were checked: without the file the build succeeds and logs the
message; with a test file dropped in, the project ID showed up inside the built
APK, proving the plugin ran.

---

## Quick diagnosis table

| Symptom | Likely cause |
| --- | --- |
| Amber "Firebase not configured" box | Anonymous sign-in off, or `google-services.json` missing |
| "Could not create a room" | Rules not deployed: `firebase deploy --only firestore:rules` |
| Room codes work, links don't open the app | Signing key changed, `assetlinks.json` fingerprint stale |
| Web build fails on `isA` | Firebase versions got bumped |
| Website shows an old build after deploy | Service worker, or a header rule that doesn't match `/` |
| Web deploy works, sign-in fails on custom domain | Domain not in Authentication → Authorized domains |
| Both phones work but never see each other | Built from different Firebase projects |
| Practice bot instead of your friend | App is in offline mode; see the first row |
| Code accepted but nobody joins | You typed your own room's code, or you're testing in two tabs of one browser |
| Vague "could not join that room" | Stale build — the app now names the actual reason |
