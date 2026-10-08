# Features Registry & Engineering Roadmap

This document catalogs all proposed, in-flight, and completed features for TWIN, detailing implementation status, dependencies, and rollout priorities.

---

## 1. Master Feature Matrix

| ID | Feature Name | Pillar | Priority | Status | Target Platform |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **FEAT-01** | **Host-Curated Anchor Words** | Gameplay Setup | P0 | **Implemented** | Web & Android |
| **FEAT-02** | **Thematic Packs & Categories** | Gameplay Setup | P0 | **Implemented** | Web & Android |
| **FEAT-03** | **Surprise Pair Generator** | Gameplay Setup | P1 | **Implemented** | Web & Android |
| **FEAT-04** | **Punchy Human Challenge Links** | Inviting & Virality | P0 | **Implemented** | Web & Android |
| **FEAT-05** | **Animated Convergence Hero Dial** | Results Polish | P0 | **Implemented** | Web & Android |
| **FEAT-06** | **Clean WhatsApp Share Text** | Results Polish | P0 | **Implemented** | Web & Android |
| **FEAT-07** | **Warm Friend Onboarding Modal** | Onboarding | P0 | **Implemented** | Web & Android |
| **FEAT-08** | **Direct WhatsApp Button in Lobby** | Inviting | P1 | **Implemented** | Web & Android |
| **FEAT-09** | **Turn Nudge & Audio Chime** | In-Game Flow | P1 | **Implemented** | Web & Android |
| **FEAT-10** | **Instant Rematch Acceptance Banner**| In-Game Flow | P1 | **Implemented** | Web & Android |
| **FEAT-11** | **Zero-Install Web to APK Prompt** | Cross-Platform | P2 | **Implemented** | Web Only |
| **FEAT-12** | **FCM Push Notifications & Cloud Functions**| Cross-Platform | P1 | **Implemented** | Android APK |
| **FEAT-13** | **Head-to-Head Duo Chemistry Stats**| Retention | P1 | **Implemented** | Web & Android |
| **FEAT-14** | **Personal Lifetime Stats & Bridge Words** | Retention | P2 | **Implemented** | Web & Android |
| **FEAT-15** | **The Daily Twin (Global Puzzle)** | Retention & Habit | P1 | **Implemented** | Web & Android |
| **FEAT-16** | **Firestore TTL & Code Recycling** | Infrastructure | P0 | **Implemented** | Backend |
| **FEAT-17** | **Public 1v1 Matchmaking (Quick Play)**| Solo & Matchmaking | P2 | **Dropped** (Anti-pattern for intimate word game) | — |
| **FEAT-18** | **Semantic AI Practice Partner** | Solo & Matchmaking | P2 | Planned | Web & Android |
| **FEAT-19** | **Hardcore / Abstract Mode Deck** | Content | P2 | **Implemented** | Web & Android |

---

## 2. Pillar Breakdown & Feature Details

### Pillar 1: Gameplay Setup ("Set the Game")
* **FEAT-01: Host-Curated Anchor Words** (`lib/core/game_config.dart`, `lib/ui/widgets/create_room_sheet.dart`)
  * *Status*: Implemented.
  * Host defines `startWordA` and `startWordB`. Round 1 skips blind typing and prompts both players to bridge the pair.
* **FEAT-02: Curated Category Decks**
  * *Status*: Implemented.
  * Categories supported: Food & Drink, Cinema & TV, Tech & Gaming, Geography, Pop Culture, Everyday Life.
* **FEAT-03: Surprise Pair Generator**
  * *Status*: Implemented.
  * Shuffles through curated, high-tension word pairings with 1 tap.

### Pillar 2: Inviting, Onboarding & Friction Reduction
* **FEAT-04: Punchy Challenge Copy** (`lib/services/deep_link_service.dart`)
  * *Status*: Implemented.
  * Formats challenge messages as: `"$who challenged you to TWIN! Can you bridge '$wordA' and '$wordB'?"`
* **FEAT-07: Warm Friend Onboarding Modal**
  * *Status*: In Progress.
  * When a player opens a join link with a default anonymous name (`"Player"`), present a 2-second dialog: *"Vatsal invited you! What is your name?"*. Updates Firestore `displayName` before entering the lobby.
* **FEAT-08: Direct WhatsApp Button in Lobby** (`lib/ui/views/lobby_view.dart`)
  * Dedicated button opening `https://api.whatsapp.com/send?text=...` directly, bypassing OS share sheet friction.
* **FEAT-11: Zero-Install Web to APK Prompt**
  * On the result screen on mobile web browsers, show a subtle banner to download the native APK for push notification support.

### Pillar 3: In-Game Flow & Turn Alerts
* **FEAT-09: Turn Nudge & Audio Chime** (`lib/ui/views/game_view.dart`)
  * Subtle sound/vibration pulse when opponent submits their word.
  * "Nudge [Friend]" button enabled after 20 seconds of waiting.
* **FEAT-10: Instant Rematch Acceptance Banner** (`lib/ui/views/result_view.dart`)
  * High-visibility prompt when opponent hits "Play again" so both players transition smoothly into round 1 of the new room.

### Pillar 4: Virality, Stats & Retention
* **FEAT-05: Animated Convergence Hero Dial** (`lib/ui/widgets/convergence_hero.dart`)
  * *Status*: Implemented.
  * Dual-arc converging canvas visualization with count-up score animation and resonance tiers.
* **FEAT-06: Clean WhatsApp Share Text** (`lib/ui/views/result_view.dart`)
  * *Status*: Implemented.
  * Formatted score and round history without spoiler words or decorative emojis.
* **FEAT-13: Duo Chemistry Stats & Memory Bank** (`lib/ui/home_screen.dart`)
  * Displays best syncs, average rounds to convergence, and play count per friend in the Friends list.
* **FEAT-14: Personal Lifetime Stats & Bridge Words**
  * Metrics: Total Twins, Fastest Convergence, and "Most Frequent Bridge Words" graph.
* **FEAT-15: The Daily Twin**
  * Globally seeded daily word pair with 24-hour expiration, global leaderboards, and streak tracking.

### Pillar 5: Android APK & Infrastructure
* **FEAT-12: FCM Push Notifications**
  * Cloud Functions listening on Firestore `/users/{uid}/invites` and room turn commits to dispatch push notifications to Android devices.
* **FEAT-16: Firestore TTL & Code Recycling** (`firestore.rules`, backend config)
  * Auto-delete rooms after 24h and allow overwriting expired room codes in `_db.runTransaction` to prevent collision exhaustion.

---

## 3. Recommended Phased Implementation Plan

```
Phase 1 (Completed):
  ├── GameConfig custom start words & theme expansion
  ├── CreateRoomSheet custom mode & category chips
  ├── ConvergenceHero animated orbital resonance UI
  └── DeepLinkService & ResultView zero-slop human copy

Phase 2 (Immediate Next Steps):
  ├── FEAT-07: Warm Friend Onboarding (name prompt on join)
  ├── FEAT-08: Direct WhatsApp 1-tap invite button in Lobby
  └── FEAT-09: Turn chime & Nudge button in GameView

Phase 3 (Retention & Virality):
  ├── FEAT-10: Instant Rematch acceptance banner
  ├── FEAT-13: Duo Chemistry & friendship memory bank
  └── FEAT-15: The Daily Twin global mode

Phase 4 (Infrastructure & Native APK):
  ├── FEAT-16: Firestore TTL & room code recycling
  └── FEAT-12: FCM push notifications via Cloud Functions
```
