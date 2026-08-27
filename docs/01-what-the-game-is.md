# 01 — What this game is

Naamkaran is a two-player word game. The goal is to end up saying the **same
word** as the other person.

## How a game goes

**Round 1.** You both type a word in secret. Neither of you can see the other's
word until you've both locked yours in. Nobody scores this round. It just gives
the game a starting pair.

Then both words appear at the same time.

Say you typed **fire** and your friend typed **water**.

**Round 2 onward.** Now you both try to name a word that sits *between* the last
two. Between fire and water, you might say **steam**. Your friend might say
**hammer**.

The app measures how close each word is to the "middle" of fire and water:

- steam → 63% close
- hammer → 41% close

Steam wins, so you get 1 point.

Now steam and hammer become the new pair, and you go again.

**The game ends** the moment you both type the same word. That's the win. There's
no points target — points are just a side-score showing who aimed better along
the way.

## Round limits

By default there's **no limit**. You play until you converge.

When you create a room you can set a cap instead: 5, 10, 15 or 25 rounds. If you
hit the cap without matching, the game ends and shows how close you got.

There's a hidden hard stop at 500 rounds. You'll never reach it — it exists for a
technical reason explained in doc 04.

## What "in the middle" actually means

This is the interesting part.

Every word in the app's dictionary has a list of 50 numbers attached to it. Those
numbers describe the word's meaning. Words with similar meanings have similar
numbers. This isn't something we invented — it's a well-known technique, and we
use a public dataset called **GloVe** made by Stanford.

So the app:

1. Looks up the 50 numbers for **fire**
2. Looks up the 50 numbers for **water**
3. Averages them, giving the "midpoint" — a meaning halfway between the two
4. Compares your word's numbers to that midpoint
5. Whoever's closer wins the round

That's why *steam* beats *hammer*. Steam genuinely sits between fire and water in
meaning. A hammer doesn't.

## Ties

If both words are almost exactly equally close (within 2%), it's a tie. When you
create the room you choose what happens: **both players score**, or **nobody
scores**.

## Words the app doesn't know

The dictionary holds the 50,000 most common English words. If you type something
outside that, the app tries a few sensible fallbacks before giving up:

| You type | What happens |
| --- | --- |
| `cats` | Found directly |
| `running` | Found directly |
| `ice cream` | Averages "ice" and "cream" |
| `bunnies` | Falls back to "bunny" |
| `zzqxwvplop` | Not found — scores 0 |

The text box tells you which of these is happening **before** you commit, so you
never get surprised at the reveal. It says one of:

- *"in the dictionary"* — good to go
- *"scored as bunny"* — it found something close
- *"unknown word, scores 0"* — you'll get zero points

## Chat

There's a chat panel at the bottom of the game screen. Tap it to open. It's
deliberately plain: just messages. No read receipts, no "typing…" dots, no
photos, no emoji reactions. Messages live as long as the room does.

## Friends

The first time you finish connecting with someone, the app remembers them. After
that you can start a game with them from the Friends list without sharing a code
again.

One limitation: because there are no accounts, this memory is tied to the app
install. Reinstall the app or switch phones and the friends list is gone.
