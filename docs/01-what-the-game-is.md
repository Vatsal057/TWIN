# 01 — What this game is

TWIN is a word game for two people. You are **on the same side**. The goal is
to both say the same word.

There are no points, no winner, no loser. You either find each other or you
don't.

## How a game goes

**Round 1.** You both type a word in secret. Neither of you can see the other's
word until you've both locked yours in.

Then both words appear at the same time.

Say you typed **fire** and your friend typed **water**.

**Round 2.** Now you both try to name a word that sits *between* those two. You
might think "steam". Your friend might think "steam" too — and that's the game
over, you twinned.

More likely you say **steam** and they say **cloud**. So now you have a new pair,
and you both aim between steam and cloud. Maybe you both land on **mist**.

**The game ends** the moment your two words match. That's the win, and it belongs
to both of you.

## What decides whether you converge

You do. Nothing else.

The app doesn't judge your words, doesn't rank them, doesn't tell you who was
closer. It only checks one thing: are the two words the same? Everything else is
you two reading each other.

That's the whole game, and it's an old one — people have played this with no app
at all, sitting across a table.

### Words are compared loosely

Before comparing, the app tidies both words the same way: trims spaces, lowercases
them, collapses double spaces. So these all count as a match:

- `Steam` and `steam`
- `  mist ` and `mist`
- `ICE CREAM` and `ice cream`

What doesn't match is a different word. `run` and `running` are not the same, and
neither are `mist` and `mists`. If you want to give yourselves more slack, that's
a house rule you can agree in the chat.

## Round limits

By default there's **no limit**. You play until you converge.

When you create a room you can set a cap instead: 5, 10, 15 or 25 rounds. If you
hit the cap without matching, the game ends and shows how many rounds you played.

There's a hard stop at 500 rounds. You'll never reach it — it exists for a
technical reason explained in doc 04.

## The only number

How many rounds it took. Fewer is better, and it's a shared result — the end
screen shows *"Twinning!, in 4 rounds"* with both your names side by side, and the
share text reads the same way.

## Chat

There's a chat panel in the game screen. Plain text only: no read receipts, no
"typing…" dots, no photos, no reactions.

On a phone it's a bar at the bottom you tap to open. On a desktop browser it sits
docked on the right, always open.

Chat matters more here than in most games. Since nothing in the app guides you
toward each other, talking is how you build a shared sense of where you're both
heading. Messages last as long as the room.

## Friends

The first time you finish connecting with someone, the app remembers them. After
that you can start a game from the Friends list without sharing a code again.

One limitation: because there are no accounts, this memory is tied to the app
install. Reinstall or switch phones and the friends list is gone.

## A note on testing alone

You can't. Both players get an anonymous ID tied to their app install or browser,
and **two tabs of the same browser share one ID** — so typing your own room code
just tells you it's your own room.

To try it with yourself, use two different browsers, or a normal window and a
private window, or two devices.
