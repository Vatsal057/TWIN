import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Single place that decides which Firebase project the app talks to.
///
/// Web has no native config file, so it needs explicit options — hence the
/// generated `firebase_options.dart`. Android and iOS can also read
/// `google-services.json` / `GoogleService-Info.plist`, which is the fallback
/// when a platform is not in the generated file.
///
/// Regenerate the options with:
///   `flutterfire configure --project=PROJECT_ID --platforms=web,android`
///
/// Kept separate from the generated file so re-running that never clobbers this
/// hook.
FirebaseOptions? resolveFirebaseOptions() {
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    // Platform absent from the generated file. Returning null tells
    // Firebase.initializeApp to look for a native config file instead, and if
    // there isn't one the app drops into offline practice mode.
    return null;
  }
}
