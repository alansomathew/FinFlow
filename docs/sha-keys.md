# FinFlow — Android SHA Key Fingerprints

> **Security notice:** Keep the release keystore file and its passwords out of version control.
> Add `android/app/finflow-release.keystore` to your `.gitignore`.

---

## Debug (Testing)

Used for development, Firebase/Google services during testing.

| Type   | Keystore                                | Alias            | Store/Key Password |
|--------|-----------------------------------------|------------------|--------------------|
| Debug  | `C:\Users\CHRIST\.android\debug.keystore` | `androiddebugkey` | `android`          |

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA-1** | `7F:3E:FE:3F:A9:B0:E0:18:55:C8:37:42:D5:F2:80:AF:44:31:D0:25` |
| **SHA-256** | `7B:31:E7:82:6F:E9:9D:B3:88:CF:4B:71:82:0C:5D:0F:33:79:C1:29:C2:24:BD:E9:E9:87:27:38:C0:E2:41:19` |

---

## Release (Production)

Used for Play Store distribution and production Firebase/Google services.

| Type    | Keystore                                         | Alias     | Store/Key Password  |
|---------|--------------------------------------------------|-----------|---------------------|
| Release | `android/app/finflow-release.keystore`           | `finflow` | `finflow@release`   |

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA-1** | `7F:F8:53:99:3A:C3:F2:F2:27:25:87:D6:7E:CB:C0:9C:89:B5:41:28` |
| **SHA-256** | `53:8C:47:46:DF:07:E6:D6:66:76:CD:2F:D0:F4:B9:CD:A3:C4:B1:05:8D:6F:9A:A5:25:C0:12:72:35:76:6C:80` |

---

## Regenerate / Verify

### Debug
```
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android
```

### Release
```
keytool -list -v \
  -keystore android/app/finflow-release.keystore \
  -alias finflow \
  -storepass finflow@release
```

---

## Adding to Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com) → Project Settings → Your Apps → Android app.
2. Click **Add fingerprint** and paste the **SHA-1** and **SHA-256** values for both debug and release.
3. Re-download `google-services.json` and replace `android/app/google-services.json`.
