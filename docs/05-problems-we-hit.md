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

## The practice opponent played nonsense

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
    logger.lifecycle("Naamkaran: google-services.json not found - building without Firebase.")
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
| Web deploy works, sign-in fails on custom domain | Domain not in Authentication → Authorized domains |
| Both phones work but never see each other | Built from different Firebase projects |
| Practice bot instead of your friend | App is in offline mode; see the first row |
