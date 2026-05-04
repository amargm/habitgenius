# HabitGenius — Firebase SHA Certificate Fingerprints

Add **all four SHA-1 values** to Firebase Console so Google Sign-In works for
every build variant.

---

## How to add in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com) → **habitgenius** project
2. ⚙️ **Project settings** → **Your apps** → Android app `com.habitgenius`
3. Scroll to **SHA certificate fingerprints** → click **Add fingerprint**
4. Paste each SHA-1 below (one at a time) → **Save**
5. After adding all fingerprints, click **Download google-services.json**
6. Replace `android/app/google-services.json` with the new file
7. Re-generate base64 and update the `GOOGLE_SERVICES_JSON` variable in
   Codemagic → firebase group

---

## Local machine — Debug keystore

> Used when running `flutter run` or building locally with `flutter build apk --debug`
> Keystore: `C:\Users\AMUGALI\.android\debug.keystore`

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA-1** | `91:AD:61:FB:AF:FA:6E:EF:FE:BD:43:6D:2D:B3:BB:88:55:FD:EA:E4` |
| SHA-256   | `B2:4D:EA:63:82:1A:B5:28:DD:7C:3E:6D:9E:A6:A4:53:10:F9:96:FD:39:04:09:1A:1C:2F:5D:2B:4D:BC:44:37` |

---

## Codemagic CI — Debug keystore

> Used when Codemagic builds a debug APK (`flutter build apk --debug`).
> Codemagic generates its own `~/.android/debug.keystore` on the build machine.
> The exact SHA-1 is printed in the **"Print debug keystore SHA-1"** build step.
>
> **After the next successful build**, copy the SHA-1 from the build log and
> add it here, then register it in Firebase.

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA-1** | *(see "Print debug keystore SHA-1" step in Codemagic build log)* |

---

## Release keystore (Codemagic + local)

> Used for `flutter build apk --release` and `flutter build appbundle --release`
> Keystore: `android/app/habitgenius-release.keystore`
> Alias: `habitgenius`

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA-1** | `8A:90:6A:4F:E2:B5:A4:7F:12:A8:C9:89:A8:A9:1F:50:92:FF:33:1A` |
| SHA-256   | `99:A8:ED:AF:4E:13:76:CA:CF:A5:DB:70:CE:FC:C6:70:BE:8A:6D:0D:6D:EE:8B:7C:43:8C:C3:CB:8E:F3:7B:19` |

---

## Summary — SHA-1 values to register in Firebase right now

```
91:AD:61:FB:AF:FA:6E:EF:FE:BD:43:6D:2D:B3:BB:88:55:FD:EA:E4   ← local debug
8A:90:6A:4F:E2:B5:A4:7F:12:A8:C9:89:A8:A9:1F:50:92:FF:33:1A   ← release
(Codemagic debug SHA-1 — get from next build log)               ← CI debug
```

---

> **Note:** SHA-256 fingerprints are only needed if you later configure
> App Check or Android App Links. For Google Sign-In, only SHA-1 is required.
