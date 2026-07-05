# Android release keystore — BACKUP (keep this repo private)

This folder holds the **release signing keystore** for the Felege Metsahft Android app,
committed on purpose as a durable backup of the *file*. A keystore cannot be "rotated":
a differently-signed APK will not install as an update over one signed with this key, so
losing `felege-release.jks` means you can never ship an update over the current APK.

> ⚠️ SECURITY: The **password is intentionally NOT stored in git.** Keep it in a password
> manager. Keep this repository private; the keystore file alone is useless without the
> password, but both together let anyone sign apps as this identity.

## Files
- `felege-release.jks` — the keystore (RSA 2048, alias `felege`, valid ~27 years)

## Credentials (store these in your password manager, NOT here)
- **keyAlias:** `felege`
- **storePassword / keyPassword:** *(kept out of git — see your password manager)*

## Restore signing on a fresh checkout
```bash
cp keystore/felege-release.jks felege-release.jks
cat > key.properties <<EOF
storePassword=<from password manager>
keyPassword=<from password manager>
keyAlias=felege
storeFile=felege-release.jks
EOF
```
Then `flutter build apk --release` will sign with this key.
