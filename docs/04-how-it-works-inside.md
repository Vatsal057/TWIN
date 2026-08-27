# 04 — How it works inside

The main ideas behind the code, in plain language. You don't need this to run the
game, but you do need it to change it safely.

---

## The folders

```
lib/
  core/        settings and word tidying
  game/        the rules            <- no Flutter, no Firebase
  models/      the shapes of things (room, round, message, friend)
  services/
    backend/   talking to Firebase
  state/       glue between rules and screens
  ui/          screens and widgets
tools/         helper scripts
```

The important line is **`lib/game/` contains no Flutter code and no Firebase
code.** It's pure logic, and after removing the scoring system it is very small:
give it two words and it tells you whether they match and whether the game is
over.

`GameEngine.resolveRound` holds the whole rule set — tidy both words, compare
them, stop if they match or the round cap is reached. That's it. It needs no data,
which is why `GameEngine` is a `const` object with no dependencies.

---

## There is no server

Worth saying clearly, because it shapes everything else.

There's no code of ours running anywhere except on the two players' devices.
Firebase's database *is* the connection between them.

```
Phone A  <-->  Firestore database  <-->  Phone B
```

Each phone keeps an open connection to the room's record. When one writes, the
other hears about it immediately.

---

## Where things are stored

```
/rooms/K7RQP
    who's playing, whose turn it is, the score,
    and the full list of finished rounds

/rooms/K7RQP/submissions/2_abc123
    one player's word for one round, kept private

/rooms/K7RQP/messages/xyz
    chat

/users/abc123/friends/def456
    remembered pairings

/users/abc123/invites/K7RQP
    "come play" note from a friend
```

---

## Keeping words secret until the reveal

This is the trickiest requirement in the whole game, and it's why the layout above
looks the way it does.

**The problem:** Firebase can't hide *part* of a record. If you can read a record,
you can read all of it. So if in-flight words sat on the room record, either player
could peek at the other's word before choosing their own. That would ruin the
game.

**The fix:** each word goes into its own small record, and the security rules
refuse to hand over your opponent's until you've both submitted:

```
allow get: if isPlayerIn(code)
  && (submissionId.split('_')[1] == request.auth.uid || roundLocked(code));
```

In words: you can always read your own word. You can read your opponent's only
once the room says both players have submitted.

Words can also only be *created*, never edited. You can't change your answer after
seeing theirs.

---

## Who decides the result?

Nobody, and both of them.

When the second word lands, **both** clients notice, both read the two words, and
both work out the result. Then each tries to write it down, with the condition
"only if nobody's written round 4 yet."

One write succeeds. The other harmlessly does nothing.

This is safe because the rule is `word A == word B` after tidying. Two clients
cannot disagree about that. There is no model, no data file, no numbers to drift.

### This used to be the risky part

An earlier version scored each round by comparing words against a bundled table of
word-meaning vectors, and awarded points to whoever was closer.

That made the arrangement above fragile in two ways. Both clients had to hold a
byte-identical copy of a 5 MB data file or they'd compute different scores — which
also meant the web version couldn't ship a smaller file to load faster. And the
security rules could check the *shape* of a result but not recompute it, so a
modified client could quietly award itself points.

Removing scoring removed both problems. There is nothing left to compute, nothing
to keep in sync, and nothing to cheat at — a client could write `matched: true`
dishonestly, but since nobody wins anything, there's no reason to.

## Why there are two backends

`GameBackend` is a list of things the game needs — create a room, join, submit a
word, send a message. Two things implement it:

**`FirestoreBackend`** — the real one.

**`LocalBackend`** — used when Firebase isn't configured. Everything stays on the
one device, and it plays the second hand itself so you can see the full game loop.

The fallback isn't decoration. It means the app never dead-ends on a crash if
Firebase is missing — it explains itself and stays usable. It also made the whole
game testable before any Firebase project existed.

The practice opponent can't be clever — with no word list, nothing in the app
knows which words sit "between" two others. So it behaves like a cooperative
human: with a chance that rises each round it plays back the word *you* just used,
trying to meet you where you are. Hold a word steady and the game converges.

---

## The round cap that exists even when there's no cap

`GameConfig.hardCeiling = 500`.

The full round history is stored as a list *inside* the room record, and Firebase
limits one record to 1 MB. A round costs roughly 200 bytes. Without a ceiling, a
truly endless game would eventually fail to save mid-round — a confusing way to
break.

500 rounds is about 100 KB, well clear of the limit, and far past what any real
game reaches.

---

## Screens

One page owns the whole room and swaps what it shows:

```
RoomPage
  ├─ LobbyView    waiting for the second player
  ├─ GameView     typing, history, chat
  └─ ResultView   final score
```

They share one connection and one chat stream, so the chat doesn't reset when the
game moves from lobby to play to result.

---

## Two layouts, one codebase

The game was designed for phones. Dropped onto a desktop browser unchanged, it
looked broken — buttons stretched a metre wide, text lines too long to read, and
chat hidden behind a tap for no reason when there was obviously room for it.

So there are two layouts, decided by window width at 900 pixels.

**Narrow (phones, small windows).** One column. Chat is a collapsible sheet at the
bottom with an unread badge.

**Wide (desktop browsers).** Two columns. The game sits in the middle, capped at
560 pixels so the text stays readable, and chat is **docked on the right at 360
pixels and always open**. The collapse control is gone entirely — there is
nothing to toggle, and no unread badge, because you can already see everything.

```
narrow                        wide
┌──────────────┐              ┌───────────────┬──────────┐
│  score       │              │   score       │  chat    │
│  word pair   │              │   word pair   │  ······  │
│  type here   │              │   type here   │  ······  │
│  history     │              │   history     │ [_____]▲ │
├──────────────┤              │               │          │
│ Chat  (tap)  │              │               │          │
└──────────────┘              └───────────────┴──────────┘
```

Two pieces make this cheap to maintain:

**`PageShell`** centres content and caps its width. Every screen is wrapped in it,
so nothing stretches on a large monitor.

**`ChatMessageList` and `ChatComposer` are shared.** The bottom sheet and the side
panel are both thin frames around the same two widgets. Fix a bug in the message
list and both layouts get the fix.

One detail worth knowing: the docked panel marks chat as read when it mounts, and
it does that *after* the first frame rather than during it. Notifying listeners
mid-build is an error in Flutter.

The reveal overlay is also capped and centred, otherwise the two words drift to
opposite edges of a wide screen and stop reading as a pair.

---

## Things in the code worth not undoing

A few decisions look odd until you know why.

**`GameConfig.copyWith` uses a sentinel value.** Normally you'd write
`maxRounds ?? this.maxRounds`. But `null` here *means* "no limit", so that pattern
would make it impossible to set. The sentinel distinguishes "not passed" from
"passed as null".

**The chat panel uses `AnimatedSize`, not an animated height.** Its contents have a
minimum height. If the box grew from 56 pixels while the contents were already
full-size, they'd overflow for the first few frames. `AnimatedSize` clips instead.

**The chat panel's padding is inside its decoration.** So the background still
reaches the bottom edge of the screen while the buttons sit above the phone's
navigation bar. Padding on the outside would leave a visible gap.

**The chat bar is 1 pixel shorter than it looks.** Its top border counts toward its
height. Without the adjustment the collapsed panel overflows by exactly 1 pixel.

**Firebase package versions are pinned exactly.** Not ranges. Doc 05 explains what
breaks otherwise.
