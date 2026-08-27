# TWIN docs

Plain-language guides to this project. Read them in order if you're new, or jump
to what you need.

| Doc | What's in it |
| --- | --- |
| [01 — What this game is](01-what-the-game-is.md) | The rules, and how the scoring actually works |
| [02 — Setup from zero](02-setup-from-zero.md) | Every step to go from an empty folder to a working game |
| [03 — Building and sharing](03-building-and-sharing.md) | Making the app files, putting it on the web, how the share link works |
| [04 — How it works inside](04-how-it-works-inside.md) | The parts of the code and why they're arranged that way |
| [05 — Problems we hit](05-problems-we-hit.md) | Real bugs, what caused them, how they were fixed |
| [06 — Changing things](06-changing-things.md) | Common edits: round limits, word list, your own domain |

## The 30-second version

TWIN is a word game for two people, played **on the same side**. You both
type a word. Then you both try to name a word "in the middle" of the last two. You
keep going until you both type the same word.

No points, no winner. You find each other or you don't.

It works over the internet, so the two players can be anywhere.

**Live now:** https://twinnn.web.app

## Key facts about this specific setup

| Thing | Value |
| --- | --- |
| Firebase project | `naamkaran-31493` (immutable, predates the rename, invisible to players) |
| Hosting site | `twinnn` |
| Website | https://twinnn.web.app |
| Retired website | https://naamkaran-31493.web.app (kept so old invite links still work) |
| Database location | `asia-south1` (Mumbai) |
| Android package name | `com.twinnn.twin` |
| Invite scheme | `twin://join?code=ABCDE` |
| Sign-in method | Anonymous (no accounts, no passwords) |

If you're setting this up fresh under a different Firebase project, your project
ID and website address will be different. Doc 02 covers that.
