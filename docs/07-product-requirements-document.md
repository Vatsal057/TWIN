# Product Requirements Document (PRD)

## 1. Product Overview

**TWIN** is a real-time, cooperative two-player word convergence game. Unlike adversarial word games, both players are on the same team trying to find the conceptual middle ground between two words until they simultaneously submit the exact same word.

### Core Philosophy
* **Zero friction**: No mandatory logins, no email signups, no passwords. Tap a link and play within 5 seconds.
* **Warm human connection**: High-signal social play tailored for WhatsApp and direct messaging channels.
* **Pure craft**: Minimalist, warm editorial ink-and-parchment aesthetic with zero AI slop (no decorative emojis, no synthetic hype, no em dashes).

---

## 2. Target Audience & Personas

1. **The Casual Messaging Pair (Primary)**:
   * Friends or couples texting on WhatsApp or iMessage who want a quick 2-minute shared mental puzzle during downtime.
   * *Needs*: Instant link opening, zero install requirement, obvious turn feedback.
2. **The Group Chat Challenger**:
   * Competitive friend groups looking to see which duo has the highest telepathic chemistry or fastest convergence.
   * *Needs*: Spoiler-free share cards, resonance percentages, rematch flow.
3. **The Daily Word Puzzle Enthusiast**:
   * Players of Wordle, Connections, and Strands who want a daily ritual.
   * *Needs*: Daily global challenge, streak tracking, stats.

---

## 3. Product Goals & Success Metrics (KPIs)

* **Virality ($K$-factor > 1.2)**: Every active player brings at least 1.2 new players via challenge links.
* **Drop-off Reduction (< 15% abandon rate)**: Reduce stalled round-1 games through host-set anchors and turn nudges.
* **Day-7 Retention (> 35%)**: Drive re-engagement via the Daily Twin ritual and head-to-head friend stats.
* **Convergence Experience**: > 80% of completed games reach a synchronized convergence within 6 rounds.

---

## 4. Feature Specifications

### 4.1. Game Master Setup ("Set the Game") — *Implemented*
* **Anchor Words**: The room creator can specify two starting words (e.g. `"Coffee"` and `"Sleep"`). Round 1 skips blind typing and immediately shows the pair to bridge.
* **Thematic Packs**: Host can pick a curated category:
  * Food & Drink
  * Cinema & TV
  * Tech & Gaming
  * Geography
  * Pop Culture
  * Everyday Life
* **Round Limit Guardrails**: Host can set max rounds (3, 5, 10, or unlimited).
* **Surprise Pair Generator**: 1-tap shuffle button to randomize creative starting pairs.

### 4.2. Frictionless Social Inviting & Onboarding
* **High-Intent Challenge Copy**: Deep links carry punchy human challenge copy:
  > *"[Name] challenged you to TWIN! Can you bridge 'Batman' and 'Joker'? Tap to play: https://twinnn.web.app/join?code=ABCDE"*
* **1-Tap WhatsApp Quick Share**: Direct `wa.me` shortcut in the lobby prefilling custom challenge text.
* **Warm Guest Onboarding**: When a recipient clicks an invite link without a custom profile name, present a lightweight 2-second name prompt (*"Vatsal invited you! What is your name?"*) so they don't enter as `"Player"`.
* **Zero-Install Web to Android Bridge**: Friends play instantly in mobile Chrome/Safari. On game completion, offer a subtle APK installation prompt for background notifications.

### 4.3. In-Game Flow & Turn Alerts
* **Dual Simultaneous Input**: Neither player sees what the other typed until both have locked in their word.
* **Simultaneous Reveal & Haptic Punch**: Synchronized card flip with heavy native haptics upon reveal.
* **Turn Chime & Nudge Button**:
  * Audio chime when an opponent locks in their submission.
  * After 20 seconds of waiting on a committed turn, display a *"Nudge [Friend]"* button to send a lightweight vibration/chime.
* **Instant Rematch Prompt**: When either player taps "Play again", the other player's screen immediately presents an active banner: *"[Friend] wants a rematch! [Accept]"*.

### 4.4. Telepathy Resonance & Group Chat Virality
* **Animated Convergence Hero** (*Implemented*):
  * Dual orbital resonance arcs fusing into a convergence sage ring.
  * Ease-out score counter (`0% -> score%`).
  * Tier ratings: Instant Resonance, Synchronized, Harmonious, Aligned, Converged.
* **Spoiler-Free WhatsApp Share Cards**:
  * Clean text share displaying round count, twinned word, and resonance score without revealing intermediate words.

### 4.5. Retention & Rituals
* **The Daily Twin**: A single global word pair seeded every 24 hours. Players worldwide attempt to converge in the fewest rounds with streak tracking.
* **Duo Chemistry & Memory Bank**:
  * Tracks best syncs, average rounds, and friendship streaks between specific friend pairs on the home screen.
* **Lifetime Stats**:
  * Total games twinned, fastest convergence, and "Most Frequent Bridge Words" (the conceptual hubs a player repeatedly uses).

### 4.6. Public & Solo Play
* **1v1 Quick Play Matchmaking**: Enqueue into a public pool and match with an online stranger in under 5 seconds.
* **10-Second AI Safety Fallback**: If no human player matches within 10 seconds, transparently spin up an intelligent solo room.
* **Semantic AI Partner**: Replace basic repetition bot with word-association embeddings (e.g. vector distance midpoints) to create a lifelike practice opponent.

---

## 5. Monetization Strategy

1. **Sponsored Category Packs**: Branded/college/event-themed starter packs (e.g., Marvel, Premier League, University slang).
2. **Cosmetic Board & Dial Themes**: High-craft colorways (Monochrome Noir, Cyberpunk Amber, Forest Moss) for the convergence hero dial.
3. **Creator Decks**: User-created and shareable deck collections.
