# 02 — Setup from zero

Everything that has to happen to turn an empty folder into a game two people can
play from different cities.

If you just want to run the already-configured project, skip to
[Already set up?](#already-set-up) at the bottom.

---

## Step 1 — Install the tools

You need four things. Note there is no word list or model to prepare — the app ships no dictionary at all.

**Flutter** — the framework the app is written in. This project was built with
Flutter 3.41.5.

```bash
flutter --version
```

**Android SDK** — to make Android app files. Comes with Android Studio, or via
Homebrew:

```bash
brew install --cask android-commandlinetools
```

**Firebase CLI** — talks to Google's servers from the terminal.

```bash
npm install -g firebase-tools
```

**FlutterFire CLI** — connects Flutter to Firebase.

```bash
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Check everything's happy:

```bash
flutter doctor
```

---

## Step 2 — Create the Firebase project

Firebase is the piece that lets two phones talk to each other. There's no server
to write or host — Firebase's database is the messenger.

**Log in first.** This opens a browser. There's no way around it and no way to
script it.

```bash
firebase login
```

**Then run the setup script:**

```bash
./tools/setup_firebase.sh
```

It does all of this for you:

1. Creates a Firebase project (or uses one you name)
2. Registers your Android app
3. Downloads `google-services.json` into `android/app/`
4. Turns on the Firestore database API
5. Creates the database
6. Uploads the security rules

**Choosing a database location matters.** The script defaults to `asia-south1`
(Mumbai). Override it:

```bash
FIRESTORE_LOCATION=europe-west1 ./tools/setup_firebase.sh
```

Pick the region closest to most of your players. **You cannot change this later** —
moving means making a new project and copying the data across. Firebase has no
"worldwide" option; every database lives in one place.

For a game like this the choice isn't critical. A round involves a handful of
quick messages, and a person takes several seconds to think of a word, so even a
player on the other side of the planet won't notice a few hundred extra
milliseconds.

---

## Step 3 — Turn on Anonymous sign-in (by hand)

This is the one step nobody can automate. Open:

```
https://console.firebase.google.com/project/YOUR-PROJECT-ID/authentication/providers
```

Then: **Authentication → Get started → Anonymous → Enable**

### Why can't this be scripted?

The Firebase CLI has no command for sign-in methods. There *is* a web API for it,
but that API belongs to a paid product called Identity Platform, and it refuses
to work on the free plan with the error `BILLING_NOT_ENABLED`.

**Don't turn on billing to get around this.** The console button does the same
thing for free. It's one click.

### What is "anonymous sign-in"?

Every phone quietly gets a random ID number the first time it opens the app. No
email, no password, nothing for the player to do. The security rules use that ID
to check who's allowed to read and write what.

Skip this step and every player fails to sign in. The app then falls back to
offline practice mode, which looks like Firebase was never set up at all.

---

## Step 4 — Connect the web version

The web version can't read `google-services.json` — that's an Android-only file.
It needs its settings written into the Dart code instead.

```bash
flutterfire configure --project=YOUR-PROJECT-ID --platforms=web,android --yes
```

This creates `lib/firebase_options.dart`.

You don't need to edit anything after this. `lib/firebase_bootstrap.dart` already
reads that file, and falls back to the native config files on platforms that
aren't listed.

---

## Step 5 — Put it on the web

```bash
./tools/build_web.sh --deploy
```

That builds the web version, stages the App Links file, and uploads it. When it
finishes you get a URL like `https://your-project-id.web.app`.

Doc 03 explains what App Links are and why that matters for sharing.

---

## Step 6 — Make the phone app files

```bash
flutter build apk --release --split-per-abi
```

You get three files in `build/app/outputs/flutter-apk/`. Install
**`app-arm64-v8a-release.apk`** — that's the right one for essentially every phone
made in the last several years.

Send it to both phones however you like. Both must be built from the same
Firebase project, or they'll each work fine and never see each other.

---

## Step 7 — Check it worked

Open the app. **Look for the amber warning box on the home screen.**

- **No warning** — Firebase is connected. Create a room and you'll get a code.
- **Warning present** — something's off. The app is in offline practice mode. Most
  likely Anonymous sign-in isn't enabled (step 3) or `google-services.json` is
  missing.

Then the real test: create a room on one phone, join with the code on the other.
Both should jump into round 1 at the same moment.

---

## Already set up?

For the existing `naamkaran-31493` project:

```bash
flutter pub get
flutter run                    # on a connected phone
flutter run -d chrome          # in a browser
```

To redeploy the website after a code change:

```bash
./tools/build_web.sh --deploy
```

To rebuild the phone app:

```bash
flutter build apk --release --split-per-abi
```
