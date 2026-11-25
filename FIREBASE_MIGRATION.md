# Firebase migration on Spark

Android and Web use Firebase Authentication for accounts and Firestore for
shared vocabulary, profiles, and learning progress. The app uses the Spark
(free) plan and does not require Cloud Functions. SQLite is opened in the
background only as an optional source for importing an existing installation.

## Firebase setup

Project `vocabgo-c37af` is configured for Android and Web. Enable Email/Password
Authentication and create the Firestore `(default)` database. Deploy the
Firestore rules with:

```sh
firebase deploy --only firestore:rules --project vocabgo-c37af
```

The rules authorize admins only through the Firebase Auth custom claim
`admin: true`. Assign or remove that claim from a trusted Admin SDK environment;
changing `users/{uid}.role` alone does not grant privileges. After changing a
claim, the account must refresh its ID token by signing out and back in.

## Free-plan account boundaries

Sign-up and username reservation use an atomic Firestore transaction protected
by rules, so a username cannot be claimed by two accounts. Firebase Auth owns
email and password credentials. On Spark, manage account creation, disabling,
deletion, and password resets in Firebase Console. The app's admin user list is
read-only; catalog and learning administration that is protected by Firestore
rules remains available to an admin claim.

## Firestore layout

- `users/{uid}`: profile and username normalization.
- `usernameClaims/{normalizedUsername}`: unique username reservation.
- `users/{uid}/settings/current` and `statistics/current`: preferences and totals.
- `users/{uid}/progress/{wordId}` and `favorites/{wordId}`: learning state.
- `users/{uid}/quizResults/{resultId}` and `studySessions/{sessionId}`: history.
- `users/{uid}/badges/{badgeId}`: earned badges.
- `users/{uid}/migrationState/local_sqlite_v1`: completion marker for a local
  learning-data import.
- `categories`, `words`, `quizQuestions`, and `badges`: shared catalog.

## Existing local data

After Firebase sign-in, the app looks for a local SQLite account with the same
email and copies that account's learning data to the matching Firebase UID.
The transfer excludes password hashes, is safe to retry, and writes its marker
only after Firestore writes succeed. Existing users must sign in on the device
that holds their old SQLite data. Keep that data until its marker is present and
the Firestore copy is checked.

The accessible emulator contained only catalog seed data and no local user
progress. Its catalog document IDs match the existing Firestore catalog, so no
catalog import was needed. Firestore already contains three user profiles and
their learning data; deployment did not overwrite those documents.
