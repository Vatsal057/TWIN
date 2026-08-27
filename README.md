# Naamkaran

A two-player, real-time word convergence game. You and one other person keep
naming words, each aiming at the middle of the last pair, until you both say the
same word.

**Play now:** https://naamkaran-31493.web.app

> **New here?** [`docs/`](docs/README.md) has the same material in plain language,
> broken into short guides: the rules, setup from scratch, building and sharing,
> how the internals fit together, the bugs we hit, and how to change things.
> This README is the condensed technical reference.

## The mechanic

1. **Round 1** — both players privately submit a word. Nothing is scored; this
   just sets the starting pair.
2. Both words are revealed **at the same time**. If they match, the game ends on
   the sync screen.
3. **Round 2 onward** — each player sees the previous round's two words and
   submits a new one. Each new word is scored by cosine similarity against the
   **midpoint vector** of the previous pair. Whoever is closer takes the point.
4. If the two similarities are within `tieThreshold` (default `0.02`), the round
   is a tie. Configurable: both players score, or neither does.
5. Repeat until you converge. The host can optionally set a round cap.
6. Every round is kept — words, similarities and who scored — for post-game
   review.

### Round limits

Unlimited by default: the game ends when you both say the same word. The host can
cap it at 5, 10, 15 or 25 rounds from the create-room sheet, and the choice is
written onto the room document so both clients apply the same rule.

Even an unlimited game stops at `GameConfig.hardCeiling` (500). The full round
history lives in an array on the room document and Firestore caps a document at
1 MiB, so without a ceiling a truly endless game would eventually fail to write
mid-round. At roughly 200 bytes per round, 500 leaves a wide margin and no real
game gets close.

Out-of-vocabulary words score `0`. The composer tells you before you commit,
so the rule never surprises you at reveal time.

## Scoring runs on-device

Similarity comes from a trimmed, quantized **GloVe 6B 50d** table bundled in the
app (`assets/embeddings/glove50.nkem`, ~5.4 MB): the 50,000 most frequent
alphabetic tokens, unit-normalized and stored as `int16`. No API call per round,
so scoring is instant, free and works on a bad connection.

Both clients load the identical asset, so both compute identical scores. That is
what makes it safe for either client to resolve a round.

Measured on this table: worst-case cosine error from quantization is `5.7e-5`,
three orders of magnitude below the `0.02` tie threshold. Parsing the asset at
startup takes ~55 ms.

Rows are stored in **descending frequency order**, so restricting a search to
common words is a plain row limit. A separate lexicographic index rides along for
the prefix fallback's binary search, which avoids sorting 50k strings at startup.

Out-of-vocabulary words fall through a chain before giving up:
exact match → multi-word centroid (`ice cream`) → punctuation stripped →
light suffix stripping (`cats` → `cat`, `running` → `run`) → longest
shared-prefix neighbour → `0`.

### Regenerating the asset

```bash
curl -L -o glove.6B.50d.txt.gz \
  https://raw.githubusercontent.com/uclnlp/inferbeddings/master/data/glove/glove.6B.50d.txt.gz
gunzip glove.6B.50d.txt.gz
python3 tools/build_embeddings.py \
  --input glove.6B.50d.txt \
  --output assets/embeddings/glove50.nkem \
  --limit 50000
```

The binary layout is documented at the top of `tools/build_embeddings.py`.

## Connecting two players

Firestore is the entire backend. There is no custom server and no socket layer —
both clients hold a live listener on `/rooms/{code}` and react to document
changes.

- Player A taps **Create room** and gets a 5-character code. Uniqueness is
  enforced by a transaction that only writes when the code document does not
  already exist, so two devices can never claim the same code.
- The code alphabet omits `I`, `L`, `O`, `0` and `1`, because codes get dictated
  over the phone and retyped from screenshots.
- A shares the code or link however they like — WhatsApp, SMS, anything. That
  handshake is deliberately outside the app.
- Player B taps **Join room**, and the room flips to `active`. Both clients are
  already listening, so they enter round 1 at the same moment.
- After the first successful connection both sides persist the pairing as a
  friend, and either can start the next game straight from the friends list with
  no code at all.

### Deep links

[Firebase Dynamic Links shut down on 25 August 2025](https://firebase.google.com/support/dynamic-links-faq/),
so this uses the native replacements plus the web build as the universal
fallback.

Shared link: `https://naamkaran-31493.web.app/join?code=ABCDE`

| Recipient | What happens |
| --- | --- |
| Android, app installed | App Links opens the app straight into the room |
| Android/iOS, no app | Plays in the browser |
| Desktop | Plays in the browser |

Nobody hits a dead end, which is the whole reason the web build exists. The
share sheet also includes the raw code, so manual entry is always available.

`naamkaran://join?code=ABCDE` is registered too, but most messaging apps will not
turn a custom scheme into a tappable link, so it is a fallback rather than the
primary path.

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

iOS Universal Links additionally need an `apple-app-site-association` file and
the `com.apple.developer.associated-domains` entitlement. That entitlement is not
committed, because adding it without a matching provisioning profile breaks local
signing.

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
Firestore database and deploys the security rules. It is idempotent, so re-run it
after fixing any failure.

It leaves exactly one manual step, because the Firebase CLI has no command for
auth providers: **enable Anonymous sign-in** in the console. The script prints
the direct URL. Skip it and every client fails to sign in, and the app falls back
to offline practice as if Firebase were absent.

Android needs no code changes — `android/app/google-services.json` is picked up
automatically, and the Gradle plugin is applied conditionally on that file
existing, so the project still builds before you have one.

### Manual path

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # writes lib/firebase_options.dart
```

Then uncomment the two lines in `lib/firebase_bootstrap.dart`:

```dart
import 'firebase_options.dart';
return DefaultFirebaseOptions.currentPlatform;
```

That hook is a separate file on purpose, so re-running `flutterfire configure`
never clobbers it. Only needed for platforms without a native config file
(notably web) — on Android and iOS, leave it returning `null` and Firebase reads
the native config automatically.

In the Firebase console, enable **Authentication → Anonymous** (every device gets
a stable uid with no sign-up friction, and the rules key off it) and create a
**Cloud Firestore** database, then:

```bash
firebase deploy --only firestore:rules
```

### Shipping to two phones

```bash
flutter build apk --release --split-per-abi
```

Install the `arm64-v8a` APK on both devices. Both builds must come from the same
Firebase project — two builds against different projects each work fine and still
never see each other, which is a confusing thing to debug later.

### Data model

```
/rooms/{roomCode}
  code, hostId, players[2], playerNames{}, status: waiting|active|finished,
  config: { maxRounds, tieThreshold, tieRule },
  currentRound, submittedBy[], scores{}, finishReason,
  rounds: [{ index, p1Word, p2Word, matched, scoreKind, scoreWinner,
             p1Sim, p2Sim, revealedAt }]

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

### How a round is resolved without a server

Both clients notice `submittedBy.size() == 2`, both read the pair, and both
compute the outcome from the same bundled embeddings. Each then attempts a
transaction that appends the round only if `rounds.length` still equals the
round index. One write lands, the other backs out. Because scoring is
deterministic, it does not matter which client won the race.

**Trade-off worth knowing:** with no server component, the rules can constrain
the *shape* of a round write but cannot recompute the similarity numbers. A
modified client could write a favourable score. For a game between two friends
that is fine. If you need it airtight, move `commitRound` into a Cloud Function
and change the rules to `allow update: if false` for the `rounds` and `scores`
fields — the `GameBackend` interface is the seam for that change.

## Play on the web

Live at **https://naamkaran-31493.web.app**

```bash
./tools/build_web.sh --deploy
```

Firebase Hosting rather than a separate static host, for four reasons that all
matter here:

- It is the same project as Firestore, so there is no second provider to manage.
- `*.web.app` and `*.firebaseapp.com` are **automatically authorized domains** in
  Firebase Auth, so anonymous sign-in works on the deployed site with no extra
  configuration.
- SPA rewrites give clean `/join?code=ABCDE` URLs. A plain static file host
  returns 404 for that path unless you fall back to hash-based routing.
- It serves `/.well-known/assetlinks.json`, which is what makes Android App
  Links work — so one link opens the app if installed and the web game if not.

### First-load size

Roughly 7–8 MB on first visit, then cached:

| | gzipped |
| --- | --- |
| `main.dart.js` | 0.8 MB |
| Renderer wasm (one variant) | 1.5–2.7 MB |
| Embedding table | 4.9 MB |

`build/web` is ~41 MB on disk, but 31 MB of that is every canvaskit/skwasm
variant and a browser downloads only the one it needs.

The embedding table dominates and barely compresses — quantized vectors are close
to incompressible (5.35 MB → 4.93 MB). It is served `immutable` with a one-year
cache, so it is a one-time cost per browser.

**Do not ship a smaller table on web only.** Round resolution is client-side and
assumes both clients compute byte-identical similarities from the same asset; a
trimmed web vocabulary would score words differently from mobile and the
idempotent-commit design would start producing inconsistent history. If web load
time matters, shrink the table for *every* platform by lowering `--limit` in
`tools/build_embeddings.py` and rebuilding all clients together.

## Offline practice

If Firebase is not configured, the app says so on the home screen and falls back
to `LocalBackend`, which implements the same `GameBackend` interface and plays
the second hand itself. The full loop — private submissions, simultaneous
reveal, midpoint scoring, convergence, chat, friends — is exercisable with no
cloud setup. It does **not** sync across devices.

The practice opponent aims at the previous pair's midpoint but picks from the top
few candidates rather than the single best, so it is beatable.

## In-game chat

A collapsible panel pinned to the bottom of the game screen, not a separate
screen or tab. Plain text only: no read receipts, no typing indicators, no
media, no reactions. Messages live in the room's subcollection and last as long
as the room. Closing the panel shows an unread count.

## Layout

```
lib/
  core/            config, word normalization
  game/            GameEngine + WordSimilarity contract   (pure Dart, no Flutter)
  models/          Room, GameRound, ChatMessage, Friend, GameInvite
  services/
    backend/       GameBackend interface, FirestoreBackend, LocalBackend
    embeddings/    binary table parser + GloVe similarity
    deep_link_service.dart, room_code.dart
  state/           AppSession, GameController, ChatController
  ui/              screens, views, widgets, theme
tools/             build_embeddings.py
firestore.rules
```

`lib/game/` has no Flutter or Firebase imports. `GameEngine.resolveRound` is a
pure function of (room snapshot, two words) and holds every rule: round 1 is
unscored, matching, midpoint scoring, the tie threshold, the round cap.

## Running

```bash
flutter pub get
flutter run                      # mobile / desktop
flutter run -d chrome            # web
```

### Pinned Firebase versions

`firebase_core`, `firebase_core_web`, `firebase_auth` and `cloud_firestore` are
pinned to exact versions as a matched set, not loose ranges. `firebase_core_web`
3.11.0 does not compile for web on this Flutter SDK — it calls
`e.isA<JSObject>()` in a catch block where `e` is typed `Object`, which dart2js
rejects. 3.10.0 has no such call, and the pinned trio is the newest combination
that accepts it.

Bumping any one of them pulls 3.11.0 back in and breaks the web build, so move
them together and re-run `tools/build_web.sh` afterwards.

## Attribution

Word vectors are GloVe (`glove.6B.50d`) from the Stanford NLP Group —
[nlp.stanford.edu/projects/glove](https://nlp.stanford.edu/projects/glove/),
released under the
[Public Domain Dedication and License v1.0](https://opendatacommons.org/licenses/pddl/1-0/).
The bundled asset is a trimmed and quantized subset; regenerate it with
`tools/build_embeddings.py`.
