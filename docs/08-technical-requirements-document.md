# Technical Requirements Document (TRD)

## 1. System Architecture

TWIN is a hybrid multiplatform application supporting **Android (Native APK)** and **Web (Wasm / CanvasKit SPA)** backed by **Google Cloud Firestore** and **Firebase Authentication**.

```
[ Android Client ]        [ Web Client ]
(AppLinks / Native)       (Chrome / Safari)
         │                       │
         └───────────┬───────────┘
                     │ HTTPS / WebSockets
                     ▼
          ┌─────────────────────┐
          │  Cloud Firestore    │
          │  (asia-south1)      │
          └──────────┬──────────┘
                     │ Event triggers
                     ▼
          ┌─────────────────────┐
          │ Cloud Functions v2  │
          │ (Push Notifications)│
          └──────────┬──────────┘
                     ▼
          ┌─────────────────────┐
          │     FCM Gateway     │
          └─────────────────────┘
```

---

## 2. Core Data Models & Firestore Schema

### 2.1. `/rooms/{roomCode}`
Root document for each game session. `roomCode` is a 5-character uppercase string from an unambiguous 24-character alphabet (`RoomCode.alphabet`).

```typescript
interface RoomDoc {
  code: string;              // "ABCDE"
  p1Id: string;              // Firebase Anonymous UID
  p1Name: string;            // Player 1 display name
  p2Id?: string;             // Player 2 UID (null while waiting)
  p2Name?: string;           // Player 2 display name
  status: 'waiting' | 'in_progress' | 'finished' | 'abandoned';
  finishReason?: 'converged' | 'abandoned' | 'max_rounds_reached';
  createdAt: Timestamp;
  updatedAt: Timestamp;
  config: {
    maxRounds: number | null;
    startWordA: string | null; // e.g. "Coffee"
    startWordB: string | null; // e.g. "Sleep"
    theme: string | null;      // e.g. "Food & Drink"
  };
  currentRound: number;      // 1-indexed
  convergedWord?: string;    // e.g. "caffeine"
  rematchCode?: string;      // Room code if a rematch room was spawned
  ttlExpiry: Timestamp;      // Auto-deletion timestamp for TTL policy
}
```

### 2.2. `/rooms/{roomCode}/rounds/{roundNumber}`
Subcollection holding individual round data.

```typescript
interface RoundDoc {
  index: number;             // 1-indexed
  p1Word?: string;           // Hidden until both submit
  p2Word?: string;           // Hidden until both submit
  matched: boolean;          // true if p1Word.toLowerCase() === p2Word.toLowerCase()
  revealedAt?: Timestamp;
}
```

### 2.3. `/rooms/{roomCode}/submissions/{playerId}`
Atomic staging document for simultaneous turn reveals.
* When Player 1 submits: writes `/submissions/p1` with `{ word, roundNumber }`.
* When Player 2 submits: writes `/submissions/p2` with `{ word, roundNumber }`.
* The client detecting both submissions executes a Firestore transaction to write to `/rounds/{roundNumber}` and clear staging.

### 2.4. `/users/{uid}/invites/{inviteId}`
Stores active game invitations sent between friends.

```typescript
interface InviteDoc {
  fromUid: string;
  fromName: string;
  roomCode: string;
  config: GameConfigMap;
  createdAt: Timestamp;
  status: 'pending' | 'accepted' | 'declined' | 'expired';
}
```

---

## 3. Room Code Recycling & Database Lifecycle (TTL)

### 3.1. Problem Definition
The 5-character alphabet yields $24^5 = 7,962,624$ distinct codes. Without deletion, active rooms will collide with dead historic rooms, increasing transaction retry storms in `_db.runTransaction`.

### 3.2. Lifecycle Policies
1. **Firestore Native TTL**:
   * Set TTL field on `/rooms` to `ttlExpiry`.
   * For active/waiting rooms: `createdAt + 2 hours`.
   * For completed/abandoned rooms: `updatedAt + 24 hours`.
2. **Atomic Code Reservation**:
   * Room creation transaction checks `status != 'finished' && updatedAt > now - 2 hours`.
   * If an old room document exists past its expiry threshold, the transaction is permitted to overwrite and reset the document, recycling the code cleanly.

---

## 4. Deep Linking & Cross-Platform Transport

### 4.1. Link Formats
* **Primary (Android App Links / Web)**: `https://twinnn.web.app/join?code=ABCDE`
* **Fallback Custom Scheme**: `twin://join?code=ABCDE`

### 4.2. Verification & Host Routing
* **Android Intent Filter**:
  * Hosts: `twinnn.web.app` and `naamkaran-31493.web.app`.
  * AssetLinks served at `https://twinnn.web.app/.well-known/assetlinks.json` matching the SHA-256 fingerprint of the release signing key.
* **Web Client Handling**:
  * On web, `AppLinks` plugin is bypassed; incoming code is extracted synchronously from `Uri.base` query parameters upon initial DOM mount.

---

## 5. Notification Architecture (Android APK)

### 5.1. Firebase Cloud Messaging (FCM)
* Client registers `firebase_messaging` on APK launch and saves the FCM device token to `/users/{uid}.fcmTokens[]`.
* Cloud Functions (Node.js runtime):
  1. `onInviteCreated`: Fires on write to `/users/{uid}/invites/{inviteId}`. Dispatches high-priority push:
     ```json
     {
       "title": "TWIN Challenge",
       "body": "Vatsal challenged you to TWIN! Can you bridge 'Coffee' and 'Sleep'?",
       "data": { "roomCode": "ABCDE", "click_action": "FLUTTER_NOTIFICATION_CLICK" }
     }
     ```
  2. `onTurnCommitted`: Fires when player 1 commits a word, waking player 2's device with a silent data payload or low-latency heads-up notification.

---

## 6. Frontend Architecture & State Machines

### 6.1. State Controller Hierarchy
* `GameController` (ChangeNotifier):
  * Manages UI state: `ViewStage.waitingForPlayers`, `ViewStage.playing`, `ViewStage.revealing`, `ViewStage.finished`.
  * Delegates all database mutations to abstract `GameBackend` interface.
* `GameBackend` Implementations:
  * `FirestoreBackend`: Remote real-time game state driven by Firestore snapshot listeners.
  * `LocalBackend`: Solo offline game loop with bot logic.

### 6.2. Visual & Animation Engine
* **Dial Resonance Engine** (`ConvergenceHero`):
  * Uses `AnimationController` driven by `CurvedAnimation(curve: Curves.easeOutCubic)`.
  * Custom `_ResonanceDialPainter` executing canvas math for dual converging orbital arcs (Player 1 Marigold + Player 2 Cyan fusing into Sage).
  * Haptic integration via `HapticFeedback.lightImpact()` and `HapticFeedback.heavyImpact()`.
