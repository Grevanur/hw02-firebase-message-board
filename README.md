# Vault Board

Vault Board is a Flutter and Firebase message board built for CSC 4360 Homework 02. It includes Firebase Authentication, a private five-field user record, a signed-in live board, owner-only update and delete operations, production Firestore rules, emulator rule tests, deterministic exactly-once message creation, and a demonstrated schema migration.

Repository: https://github.com/Grevanur/hw02-firebase-message-board

## Requirements

- Flutter 3.47.2 or later
- Android SDK and an Android emulator or device
- Firebase CLI 15.35.0 or later
- Node.js 20 or later for the security-rule tests
- Java 21 or later for the Firebase Emulator Suite

## Firebase setup

The submitted Android build is configured for a dedicated Firebase project. Email/password authentication is enabled and the deployed Firestore rules are in `firestore.rules`. Project-specific client configuration is intentionally kept out of Git.

Configure a Firebase project after cloning:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
firebase deploy --only firestore
```

This generates the ignored `lib/firebase_options.dart`, `android/app/google-services.json`, and `.firebaserc` files. Firebase client configuration does not grant database access, but it is still excluded here to keep the public repository project-neutral. Firestore Security Rules provide authorization. No service-account credentials, signing keys, passwords, or access tokens belong in source control.

## Run the app

```bash
flutter pub get
flutter run
```

To use the local Auth and Firestore emulators from an Android emulator:

```bash
firebase emulators:start --only auth,firestore
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

The Android emulator reaches the host through `10.0.2.2`. The production project is not touched while `USE_FIREBASE_EMULATOR=true`.

## Architecture and data placement

Widgets render state and collect input. `AuthService` owns every Firebase Authentication call and the registration write. `BoardService` owns all message reads and writes. Both live streams are created once in `BoardScreen.initState`; `StreamBuilder` owns and disposes their subscriptions with the screen.

### `users/{uid}`

| Field | Writer | Placement decision |
| --- | --- | --- |
| `uid` | Registration transaction | Keys the private document to the authenticated user. |
| `firstName` | Registration transaction | Private profile data used to build the display name. |
| `lastName` | Registration transaction | Private profile data used to build the display name. |
| `role` | Registration transaction | Descriptive only; rules never treat it as an authority claim. |
| `registrationDateTime` | Firestore server timestamp | Provides an authoritative creation time. |

Only the matching UID may create and read this document. Client updates and deletes are denied so the required registration record remains stable.

### `messages/{uid_requestId}`

| Field | Writer | Placement decision |
| --- | --- | --- |
| `text` | Author client | Shared board content, limited to 1-500 characters. |
| `authorUid` | Author client, rules verified | Immutable ownership key. |
| `authorName` | Author client | Public attribution on this signed-in board. |
| `createdAt` | Firestore server timestamp | Stable ordering independent of device clocks. |
| `editedAt` | Firestore server timestamp | Records owner edits without replacing creation time. |
| `schemaVersion` | Board service | Current message schema is version 2. |
| `clientRequestId` | Board service | Stable operation identifier used for idempotency. |

The document ID combines the authenticated UID and a request UUID. A transaction first checks that document, then creates it only if absent. Replaying the same request therefore produces one document. A failed attempt keeps the request ID for a safe retry; a successful post clears it for the next distinct action.

## Security rules

The deployed rules enforce authorization independently of the UI:

- signed-out message reads are denied;
- signed-in users may read the board;
- create requires `authorUid == request.auth.uid` and an exact v2 field shape;
- author identity, creation time, and request ID are immutable on update;
- only the original author may update or delete a message;
- private user records are readable only by their UID;
- unmatched paths are denied.

Hiding edit and delete controls improves usability but is not an authorization boundary.

## Tests

Run Flutter checks:

```bash
flutter analyze
flutter test
```

Run the Firestore rule suite:

```bash
npm --prefix firebase_tests install
firebase emulators:exec --only firestore --project=demo-message-board-vault \
  "npm --prefix firebase_tests test"
```

The five automated cases prove signed-out read denial, cross-UID update/delete denial, forged-author denial, correct-author CRUD, and private-profile isolation.

Run the lossless migration demonstration:

```bash
firebase emulators:exec --only firestore --project=demo-message-board-vault \
  "npm --prefix firebase_tests run seed:v1 && npm --prefix firebase_tests run migrate:v2"
```

The seed utility refuses to run outside the emulator. It creates realistic v1 documents with legacy names. The migration maps all values to the v2 schema in one batch, removes only obsolete key names, and rereads every migrated document to verify the content and version.

## Offline behavior and stream lifetime

Firestore mobile clients cache documents and queue supported writes while offline. The board includes metadata changes and marks locally pending messages with a cloud-upload icon. Reconnection is expected to synchronize the queued operation. The deterministic document ID prevents a retry of the same operation from creating a second document. Distinct user actions intentionally receive distinct IDs.

The message stream is stored once rather than recreated on every widget rebuild. `StreamBuilder` subscribes when mounted and cancels when `BoardScreen` leaves the tree. This prevents navigation-driven duplicate listeners and unnecessary reads.

## Release build

The submission APK was built with:

```bash
flutter build apk --release
```

Expected output: `build/app/outputs/flutter-apk/app-release.apk`

SHA-256 for the tested APK:

```text
41298e47471d31b70c73f4ae9e8be22ba20053c84d78baffda4d8ab1c5cc2c77
```

The signing key and `android/key.properties` are intentionally excluded. The attached APK remains installable; a future rebuild for distribution should use the owner's protected signing material.

## Graduate deliverables

- Main Spice: exact release APK installed and smoke tested
- Spice 1: Auth and Firestore emulator workflow documented
- Spice 2: automated security-rule test suite
- Spice 4: deterministic exactly-once message creation
- Spice 5: seeded and verified v1-to-v2 migration
- all three case files, the graduate AI design critique, reflections, test matrix, citations, and captioned screenshots are in the evidence document

## Privacy

Use fictional test accounts and content. Do not commit Firebase client configuration, service-account JSON, access tokens, signing keys, keystore passwords, or real user data. Run `flutterfire configure` locally to generate the ignored client files; the deployed rules remain the security boundary.
