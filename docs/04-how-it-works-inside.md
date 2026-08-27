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
    embeddings/ the word dictionary
  state/       glue between rules and screens
  ui/          screens and widgets
tools/         helper scripts
```

The important line is **`lib/game/` contains no Flutter code and no Firebase
code.** It's pure logic: give it a room and two words, it tells you who won. That
means the rules can be reasoned about and tested without a phone, a screen, or an
internet connection.

`GameEngine.resolveRound` holds every rule in one place: round 1 isn't scored,
matching words end the game, closer word wins, ties use the configured rule, the
round cap stops play.

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

When the second word lands, **both** phones notice, both look up the two words,
and both work out the result. Then each tries to write it down, with the condition
"only if nobody's written round 4 yet."

One write succeeds. The other harmlessly does nothing.

This is safe only because both phones have the identical word dictionary, so they
always compute the identical result. It genuinely doesn't matter which one wins
the race.

That's also why doc 03 warns against giving the web version a smaller dictionary —
it would break this whole arrangement.

### The honest weakness

Because there's no server, the security rules can check the *shape* of a result
being written but can't recalculate the scores. Someone running a modified app
could give themselves points.

For a game between two friends, that's fine.

If you ever needed it airtight, move the round calculation into a Cloud Function
and change the rules to forbid clients writing `rounds` and `scores` directly. The
`GameBackend` interface is the seam designed for that swap.

---

## Why there are two backends

`GameBackend` is a list of things the game needs — create a room, join, submit a
word, send a message. Two things implement it:

**`FirestoreBackend`** — the real one.

**`LocalBackend`** — used when Firebase isn't configured. Everything stays on the
one device, and it plays the second hand itself so you can see the full game loop.

The fallback isn't decoration. It means the app never dead-ends on a crash if
Firebase is missing — it explains itself and stays usable. It also made the whole
game testable before any Firebase project existed.

The practice opponent aims at the midpoint but picks from the top few options
rather than the single best, so it's beatable.

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

## The word dictionary file

Custom format, `assets/embeddings/glove50.nkem`:

```
header      magic bytes, version, 50 dimensions, 50000 words
words       the words themselves, most common first
sort index  the same words in alphabetical order
numbers     50000 x 50 squashed numbers
```

Two orderings, on purpose.

**Frequency order** is the main one. "Search only the 15,000 most common words"
becomes "look at the first 15,000 rows" — nothing to filter.

**Alphabetical order** is a separate index used for the fallback that finds a
similar-looking word. Binary search needs sorted data, and sorting 50,000 words
every time the app starts would waste time on every launch.

An earlier version stored only alphabetical order, and this caused a real bug —
see doc 05.

Loading the whole file takes about 55 milliseconds.

### Function words are filtered out

Words like *the*, *of*, *around*, *through* sit near the centre of meaning-space,
so they come out "close to the middle" of almost any pair. Left alone, the practice
opponent would just play prepositions forever.

There's a list of 171 such words that never get suggested. Players can still
type them; they're only excluded from the app's own suggestions.

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
