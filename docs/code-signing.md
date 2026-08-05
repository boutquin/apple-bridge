# Code signing and notarization

How apple-bridge is signed today, what a Developer ID adds, and the exact steps
to get there. Written 2026-08-05 against macOS 15/26 and Xcode 16+.

## What signing does and does not fix

Signing is about **distribution and integrity**, not permissions.

A belief worth correcting up front, because it cost real time: it was recorded
in this project's notes that the binary had to be Developer ID-signed for
EventKit to grant `fullAccess` instead of `writeOnly`. **That is false.** On
2026-08-05 the server obtained Full Access to Calendars while running as an
*unsigned, ad-hoc, linker-signed* binary. The only thing that changed was a
human setting the grant on the responsible parent app in System Settings.

| Problem | Does signing fix it? |
|---|---|
| `writeOnly` instead of `fullAccess` | **No.** Grant Full Access to the responsible parent app (see README → *Granting permissions when launched by an MCP host*). |
| Privacy prompt never appears | **No.** The prompt comes from the *responsible process*' usage-description strings, not this binary's. |
| `Info.plist=not bound` in `codesign -dv` | **Yes** — and plain ad-hoc signing is enough (see below). |
| Gatekeeper blocks the binary on someone else's Mac | **Yes** — needs Developer ID **and** notarization. |
| "Unidentified developer" warning on download | **Yes** — needs Developer ID + notarization + stapling. |
| Verifiable authorship / tamper-evidence for users | **Yes** — needs Developer ID. |

## Today: ad-hoc signing (no certificate required)

`scripts/install.sh` signs every install, ad-hoc by default. This is not
cosmetic. SwiftPM emits a **linker-signed** binary, and `codesign -dv` on it
reports:

```
CodeDirectory ... flags=0x20002(adhoc,linker-signed)
Info.plist=not bound
```

The privacy usage strings are embedded through `-sectcreate __TEXT __info_plist`
(see `Package.swift`), but "not bound" means they are **not covered by the
signature**. An explicit `codesign` run binds them:

```
CodeDirectory ... flags=0x2(adhoc)
Info.plist entries=15
```

`install.sh` fails the install if the plist is still unbound afterward, rather
than reporting success on a binary whose usage strings aren't covered.

## Upgrading to Developer ID

Needed only if you distribute the binary to other people's Macs. An Apple
Developer account alone is **not** sufficient — you must create a certificate.

### 1. Create the certificate (must be done by you, interactively)

Easiest path, in Xcode:

**Xcode → Settings → Accounts → select your Apple ID → Manage Certificates… →
`+` → Developer ID Application**

Xcode generates the keypair, submits the CSR, and installs the certificate into
your login keychain. Verify:

```bash
security find-identity -v -p codesigning
```

You want a line reading `Developer ID Application: Your Name (TEAMID)`. Zero
identities means the certificate was never created — signing up for the
developer program does not create one for you.

> Do this in Xcode rather than by hand. The manual route
> (developer.apple.com → Certificates → `+` → upload a CSR from Keychain
> Access) works but is easy to get wrong, and a Developer ID certificate's
> private key cannot be re-downloaded if lost — only revoked and reissued.

### 2. Sign with it

`install.sh` takes the identity from an environment variable:

```bash
APPLE_BRIDGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/install.sh
```

That path adds `--options runtime` (hardened runtime, a notarization
prerequisite) and `--timestamp` (a secure timestamp, so the signature stays
valid after the certificate expires).

### 3. Notarize

Notarization is Apple scanning the binary and issuing a ticket. Store the
credentials once in the keychain:

```bash
xcrun notarytool store-credentials "apple-bridge-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Use an **app-specific password** from appleid.apple.com, never your Apple ID
password. `notarytool` requires a zip/pkg/dmg, not a bare executable:

```bash
ditto -c -k --keepParent ~/bin/apple-bridge apple-bridge.zip
xcrun notarytool submit apple-bridge.zip \
  --keychain-profile "apple-bridge-notary" --wait
```

### 4. Stapling — and why it does not apply here

`xcrun stapler staple` attaches the ticket to the artifact so Gatekeeper can
verify offline. **Stapling a bare executable is not supported** — only bundles,
disk images, and installer packages. For a command-line binary distributed in an
archive, Gatekeeper verifies online instead, which is fine. If you later ship a
`.app` or `.dmg`, staple that.

Verify the result:

```bash
codesign -dv --verbose=4 ~/bin/apple-bridge     # identity, hardened runtime, timestamp
spctl -a -vvv -t install ~/bin/apple-bridge     # Gatekeeper assessment
```

## Signing in CI

`.github/workflows/release.yml` signs Developer ID when the secrets are present
and ad-hoc when they are not. **Which path it took is always announced** — an
ad-hoc fallback emits a `::warning::`, and missing notary credentials emit
another. A release that quietly degrades is the failure worth engineering
against: the artifact looks fine and Gatekeeper rejects it on the user's machine.

### Required secrets

| Secret | What it is |
|---|---|
| `MACOS_CERTIFICATE` | base64 of the exported `.p12` (certificate **and** private key) |
| `MACOS_CERTIFICATE_PWD` | the password you set when exporting the `.p12` |
| `MACOS_KEYCHAIN_PASSWORD` | any random string; scopes the throwaway keychain created during the job |

Optional, for notarization (absent → signed but not notarized, with a warning):

| Secret | What it is |
|---|---|
| `NOTARY_APPLE_ID` | your Apple ID email |
| `NOTARY_TEAM_ID` | your team ID (e.g. `GYM6J3XZTR`) |
| `NOTARY_PASSWORD` | an **app-specific password** from appleid.apple.com — never your Apple ID password |

### Exporting the `.p12`

The private key never leaves your machine except as this encrypted `.p12`, so do
this yourself and pick a strong export password.

1. **Keychain Access → login → My Certificates.**
2. Right-click **Developer ID Application: Your Name (TEAMID)** → **Export…**
3. Save as `.p12`, set a strong password (this becomes `MACOS_CERTIFICATE_PWD`).
4. Base64 it and load the secrets:

```bash
base64 -i ~/Desktop/DeveloperID.p12 | gh secret set MACOS_CERTIFICATE -R boutquin/apple-bridge.Dev
gh secret set MACOS_CERTIFICATE_PWD    -R boutquin/apple-bridge.Dev   # prompts; paste the export password
gh secret set MACOS_KEYCHAIN_PASSWORD  -R boutquin/apple-bridge.Dev   # prompts; any random string
```

5. **Delete the `.p12` afterwards** — `rm ~/Desktop/DeveloperID.p12`. It is your
   signing identity in a single file.

### How the job handles the key

The `.p12` is decoded into a keychain created in `$RUNNER_TEMP` and deleted by a
step with `if: always()`, so a failure between import and cleanup cannot leave
the key on the runner. `security set-key-partition-list` is called after import —
without it `codesign` blocks on an interactive keychain prompt nobody can answer
and the job hangs until it times out.

### Where releases are published — and why the key lives in exactly one repo

This project has two remotes: the private `apple-bridge.Dev` (`origin`, holds
specs and dev history) and the public `apple-bridge` (a squash mirror). Signing
happens **only in the private repo**, and the signed artifact is then uploaded to
a release on the public mirror by the last step of `release.yml`.

The reason is custody. Putting the same `.p12` into the public repo's secrets
would duplicate your code-signing identity — the thing that asserts software is
from you — into a repository anyone can fork and open workflows against. GitHub
does withhold secrets from fork PRs, so it is not directly exploitable, but the
blast radius of any future misconfiguration is your signing identity, and
revoking one is disruptive. It would also create two release paths for one tag,
which is a race rather than redundancy.

So only a token crosses the boundary:

| Secret | What it is |
|---|---|
| `RELEASE_PAT` | fine-grained PAT scoped to `boutquin/apple-bridge`, **Contents: read and write** |

```bash
gh secret set RELEASE_PAT -R boutquin/apple-bridge.Dev   # prompts; paste the token
```

Create it at **github.com → Settings → Developer settings → Personal access
tokens → Fine-grained tokens**, with `boutquin/apple-bridge` as the only
repository and Contents write as the only permission. A token this narrow can
publish releases and nothing else, and rotating it costs a minute — unlike a
Developer ID key. If `RELEASE_PAT` is absent the step is skipped with a warning,
so the private release still succeeds and you simply have no public download.

### Custody

A Developer ID private key in CI is a real custody decision, not a checkbox.
Anyone who can run workflows in `apple-bridge.Dev` can sign code as you. Keep
that repository private, or move signing to a protected environment, if that
matters. Revoke and reissue at developer.apple.com if a key is ever exposed.

## Reference

- README → *Granting permissions when launched by an MCP host* — the permissions
  path, which signing does not replace
- `specs/done/chore-calendar-event-identifier-roundtrip.md` — the write-only
  diagnosis and its resolution
- `scripts/install.sh` — the signing implementation
