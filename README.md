# Naamkaran

A two-player, real-time word convergence game. You and one other person keep
naming words, each aiming at the middle of the last pair, until you both say the
same word.

Collaborative: no points, no winner, no loser. You find each other or you don't.

**Play now:** https://naamkaran-31493.web.app

> **New here?** [`docs/`](docs/README.md) has the same material in plain language,
> broken into short guides: the rules, setup from scratch, building and sharing,
> how the internals fit together, the bugs we hit, and how to change things.
> This README is the condensed technical reference.

## The mechanic

1. Both players privately submit a word.
2. Both words are revealed **at the same time**. If they match, the game ends on
   the sync screen.
3. If not, both players see the pair and aim for a word between them.
4. Repeat until you converge, or until the optional round cap.
5. Every round is kept for post-game review.

The only rule is `normalizeWord(a) == normalizeWord(b)` — trim, lowercase, collapse
whitespace, compare. The app never ranks or judges a word; convergence is entirely
up to the two players reading each other.

### Round limits

Unlimited by default. The host can cap a game at 5, 10, 15 or 25 rounds from the
create-room sheet, and the choice is written onto the room document so both clients
apply the same rule.

Even an unlimited game stops at `GameConfig.hardCeiling` (500). The full round
history lives in an array on the room document and Firestore caps a document at
1 MiB, so without a ceiling a truly endless game would eventually fail to write
mid-round.

## Connecting two players

Firestore is the entire backend. There is no custom server and no socket layer —
both clients hold a live listener on `/rooms/{code}` and react to document
changes.

- Player A taps **Create room** and gets a 5-character code. Uniqueness is
  enforced by a transaction that only writes when the code document does not
  already exist.
- The code alphabet omits `I`, `L`, `O`, `0` and `1`, because codes get dictated
  over the phone and retyped from screenshots.
- A shares the code or link however they like — WhatsApp, SMS, anything. That
  handshake is deliberately outside the app.
- Player B taps **Join room**, and the room flips to `active`. Both clients are
  already listening, so they enter round 1 at the same moment.
- After the first successful connection both sides persist the pairing as a
  friend, and either can start the next game straight from the friends list with
  no code at all.

**You cannot test with yourself in one browser.** Anonymous auth gives each
install/browser one id, shared across tabs, so joining your own code is rejected
with a clear message. Use two browsers, or a private window, or two devices.

### Deep links

[Firebase Dynamic Links shut down on 25 August 2025](https://firebase.google.com/support/dynamic-links-faq/),
so this uses the native replacements plus the web build as the universal fallback.

Shared link: `https://naamkaran-31493.web.app/join?code=ABCDE`

| Recipient | What happens |
| --- | --- |
| Android, app installed | App Links opens the app straight into the room |
| Android/iOS, no app | Plays in the browser |
| Desktop | Plays in the browser |

**Android App Links are live.** `web/well-known/assetlinks.json` is staged to
`/.well-known/assetlinks.json` by `tools/build_web.sh`, and Google's Digital
Asset Links API validates it with no errors.

The fingerprint in that file must match the key that signs the APK. Right now
that is the **debug** keystore, because the Flutter template signs release builds
with debug keys until you add a signing config. When you add a real release key,
update the fingerprint and redeploy hosting, or links will silently stop opening
the app:

```bash
keytool -list -v -keystore <your.keystore> -alias <alias> | grep SHA256
```

To move to your own domain:

```bash
NAAMKARAN_WEB_HOST=play.example.com ./tools/build_web.sh --deploy
```

and update `android:host` in `android/app/src/main/AndroidManifest.xml` to match.

## Firebase setup

The app runs without Firebase — see *Offline practice* below — but real
two-player games need a project.

### Scripted path

```bash
npm install -g firebase-tools
firebase login                 # browser OAuth, cannot be scripted
./tools/setup_firebase.sh      # everything else
```

The script creates or selects a project, registers the Android and iOS apps,
downloads `google-services.json` / `GoogleService-Info.plist`, creates the
Firestore database and deploys the security rules. It is idempotent.

It leaves exactly one manual step, because the Firebase CLI has no command for
auth providers: **enable Anonymous sign-in** in the console. The script prints the
direct URL. Skip it and every client fails to sign in, and the app falls back to
offline practice as if Firebase were absent.

Android needs no code changes — `android/app/google-services.json` is picked up
automatically, and the Gradle plugin is applied conditionally on that file
existing, so the project still builds before you have one.

### Web

Web has no native config file, so it needs explicit options:

```bash
flutterfire configure --project=<id> --platforms=web,android
```

`lib/firebase_bootstrap.dart` reads the generated file and falls back to native
config on platforms not listed.

### Shipping to two phones

```bash
flutter build apk --release --split-per-abi
```

Install the `arm64-v8a` APK (19.3 MB) on both devices. Both builds must come from
the same Firebase project — two builds against different projects each work fine
and still never see each other.

### Data model

```
/rooms/{roomCode}
  code, hostId, players[2], playerNames{}, status: waiting|active|finished,
  config: { maxRounds },
  currentRound, submittedBy[], finishReason,
  rounds: [{ index, p1Word, p2Word, matched, revealedAt }]

/rooms/{roomCode}/submissions/{roundIndex}_{playerId}
  playerId, roundIndex, word, submittedAt

/rooms/{roomCode}/messages/{messageId}
  senderId, text, sentAt

/users/{userId}/friends/{friendId}      persisted pairing
/users/{userId}/invites/{roomCode}      direct invite from a saved friend
```

`players[0]` is always the host, so `p1Word` and `p2Word` never swap meaning
part-way through a game.

### Why submissions live in a subcollection

Firestore cannot hide a *field* from someone who can read the document. If the
in-flight words sat on the room doc, either client could read the opponent's word
before committing their own — which would break the game.

So each word goes to `/submissions/{roundIndex}_{playerId}`, and the rules only
release the opponent's doc once `submittedBy` contains both players:

```
allow get: if isPlayerIn(code)
  && (submissionId.split('_')[1] == request.auth.uid || roundLocked(code));
```

Submissions are create-only. You cannot revise a word after seeing the
opponent's.

Note also that `allow get` on a room checks `resource == null` first. Room
creation reserves a code by reading the document it is about to write, and for a
document that does not exist `resource` is null — dereferencing it errors, and a
rule that errors denies. That bug blocked every room creation once.

### How a round is resolved without a server

Both clients notice `submittedBy.size() == 2`, both read the pair, and both
compute the outcome. Each then attempts a transaction that appends the round only
if `rounds.length` still equals the round index. One write lands, the other backs
out.

This is safe because the rule is string equality. Two clients cannot disagree
about it — there is no model or data file that could drift between them.

## Play on the web

Live at **https://naamkaran-31493.web.app**

```bash
./tools/build_web.sh --deploy
```

Firebase Hosting rather than a separate static host, for four reasons:

- Same project as Firestore, so there is no second provider to manage.
- `*.web.app` and `*.firebaseapp.com` are **automatically authorized domains** in
  Firebase Auth, so anonymous sign-in works on the deployed site with no extra
  configuration.
- SPA rewrites give clean `/join?code=ABCDE` URLs.
- It serves `/.well-known/assetlinks.json`, which is what makes Android App Links
  work.

First load is roughly 2–3.5 MB gzipped (0.8 MB app code plus one renderer), then
cached. `build/web` is ~41 MB on disk, but 31 MB of that is every renderer variant
and a browser downloads only one.

**No service worker.** The build passes `--pwa-strategy=none` because Flutter's
service worker keeps serving the previous build after a deploy until every tab is
closed. `tools/sw_killswitch.js` is staged over the build output to evict any
worker a browser already registered. Entry points are served `no-cache`; note that
`/` needs its own header rule, since a rule for `/index.html` does not match a
request for the root.

## Offline practice

If Firebase is not configured, the app says so on the home screen and falls back
to `LocalBackend`, which implements the same `GameBackend` interface and plays the
second hand itself. It does **not** sync across devices.

The practice opponent cannot be clever — the app ships no word list, so nothing
knows which words sit "between" two others. Instead it behaves like a cooperative
human: with a chance that rises each round it plays back the word you just used.
Hold a word steady and it will meet you.

## In-game chat

Inside the game screen, never a separate screen or tab. Plain text only: no read
receipts, no typing indicators, no media, no reactions. Messages live in the
room's subcollection and last as long as the room.

The layout adapts at 900px:

| Width | Chat |
| --- | --- |
| ≥ 900px (desktop web) | Docked on the right, 360px, permanently open |
| < 900px (phones) | Collapsible sheet at the bottom, with an unread badge |

Chat carries more weight here than in most games: since nothing in the app guides
players toward each other, talking is how they build a shared sense of direction.

## Responsive layout

`lib/ui/layout.dart` holds the breakpoints. Every screen is wrapped in
`PageShell`, which centres content and caps it at 560px — without it, a desktop
browser gets buttons a metre wide and text lines too long to scan.

## Layout

```
lib/
  core/            config, word normalization
  game/            GameEngine                              (pure Dart, no Flutter)
  models/          Room, GameRound, ChatMessage, Friend, GameInvite
  services/
    backend/       GameBackend interface, FirestoreBackend, LocalBackend
    deep_link_service.dart, room_code.dart
  state/           AppSession, GameController, ChatController
  ui/              screens, views, widgets, theme
tools/             setup_firebase.sh, build_web.sh, sw_killswitch.js
firestore.rules
```

`lib/game/` has no Flutter or Firebase imports, and after scoring was removed it
needs no data either — `GameEngine` is a `const` object. `resolveRound` is a pure
function of (room snapshot, two words) and holds the whole rule set.

## Running

```bash
flutter pub get
flutter run                      # mobile / desktop
flutter run -d chrome            # web
```

### Pinned Firebase versions

`firebase_core`, `firebase_core_web`, `firebase_auth` and `cloud_firestore` are
pinned to exact versions as a matched set. `firebase_core_web` 3.11.0 does not
compile for web on this Flutter SDK — it calls `e.isA<JSObject>()` in a catch block
where `e` is typed `Object`, which dart2js rejects. 3.10.0 has no such call, and
the pinned trio is the newest combination that accepts it.

Bumping any one of them pulls 3.11.0 back in and breaks the web build, so move
them together and re-run `tools/build_web.sh` afterwards.
