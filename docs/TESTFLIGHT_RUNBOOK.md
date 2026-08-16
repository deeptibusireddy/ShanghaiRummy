# TestFlight Runbook (Windows → MacinCloud → your iPad)

**Goal:** Get Shanghai Rummy running on your own iPad via TestFlight in a single ~30-minute paid Mac session.

**Cost:** $1–$3 for the MacinCloud hour, plus your existing $99/yr Apple Developer membership. TestFlight itself is free.

---

## Prerequisites (do these on Windows, FREE, ~15 min)

### 1. Apple Developer setup (App Store Connect side)

Sign in at https://appstoreconnect.apple.com/ and do these once:

1. **Get your Team ID** — Users and Access → Integrations → App Store Connect API (or Membership page). Copy the 10-character team ID; you'll paste it into `project.yml` on the Mac. Example: `A1B2C3D4E5`.

2. **Register the App ID** — https://developer.apple.com/account/resources/identifiers/list
   - Click "+", pick "App IDs", "App".
   - Bundle ID (Explicit): `com.deeptibusireddy.ShanghaiRummy`
   - Description: `Shanghai Rummy`
   - Capabilities: check **Game Center** (we'll use it later for M3 multiplayer)
   - Save.

3. **Create the App Store Connect record** — https://appstoreconnect.apple.com/apps → "+" → New App
   - Platform: iOS
   - Name: `Shanghai Rummy Nights` *(App Store listing name; on-device home-screen name stays "Shanghai Rummy")*
   - Primary language: English (U.S.)
   - Bundle ID: pick the one you just registered
   - SKU: `shanghai-rummy-001` (any unique string)
   - User Access: Full Access

### 2. Verify Apple ID is on your iPad

On your iPad: Settings → App Store → make sure you're signed in with the same Apple ID that owns the developer account. Install the **TestFlight** app from the App Store.

---

## MacinCloud session (~30 min, ~$1–$3)

### 3. Rent a Mac

Go to https://www.macincloud.com/ → Pay As You Go plan (~$1/hr Managed Server, or ~$3/hr Dedicated). The **Managed Server plan comes with Xcode preinstalled** — pick that.

Log in via the browser or the RDP client they provide. You'll see a full macOS desktop.

### 4. On the Mac: install XcodeGen (~2 min)

Open Terminal:
```bash
# Homebrew is pre-installed on MacinCloud managed servers
brew install xcodegen
```

If Homebrew is missing:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
```

### 5. Clone the repo (~1 min)

```bash
cd ~
git clone https://github.com/deeptibusireddy/ShanghaiRummy.git
cd ShanghaiRummy
```

If the repo is private, use `gh auth login` first, or use `git clone https://<user>:<PAT>@github.com/...`.

### 6. Fill in your Team ID (~1 min)

Edit `project.yml`, replace line ~12:
```yaml
    DEVELOPMENT_TEAM: "A1B2C3D4E5"  # <-- your 10-char team ID
```

### 7. Generate the Xcode project (~10 sec)

```bash
xcodegen generate
open ShanghaiRummy.xcodeproj
```

### 8. In Xcode: sign in and pick your team (~2 min)

- Xcode → Settings → Accounts → "+" → Apple ID → sign in.
- Close settings.
- Left sidebar → click blue `ShanghaiRummy` project icon → target `ShanghaiRummy` → **Signing & Capabilities** tab.
- Check **"Automatically manage signing"**. Pick your team from the dropdown.
- Xcode will provision the app identifier and download a signing certificate. Wait for the amber warnings to clear.

### 9. Pick a device destination (~10 sec)

Top bar next to the play button — change destination from a simulator to **"Any iOS Device (arm64)"**. You need this for archiving.

### 10. Archive (~3 min)

Menu: **Product → Archive**.

Xcode compiles Release, signs it, and opens the Organizer window when done. If a signing error pops up, click "Try Again" — the automatic team management usually resolves it.

### 11. Upload to App Store Connect (~5 min)

In the Organizer window:
1. Select the archive that just appeared.
2. Click **"Distribute App"** on the right.
3. Choose **"App Store Connect"** → Next
4. Choose **"Upload"** → Next
5. Accept the defaults (symbols yes, automatically manage signing yes)
6. Click **Upload**. Wait ~2 min for the progress bar.

### 12. Wait for processing (~5–15 min — you can log off the Mac now!)

App Store Connect will email you when processing completes. You can end your MacinCloud session here to stop the meter running.

Meanwhile, in App Store Connect:
1. Go to your app → **TestFlight** tab.
2. When the build shows up, it'll have a yellow "Missing Compliance" badge.
3. Click the build → **Manage** next to Export Compliance → answer **"No" to encryption** (you added the `ITSAppUsesNonExemptEncryption=false` key to Info.plist, but the first upload still asks).
4. Fill in a very short "What to test" (e.g. "First playable — pass-and-play with three CPU bots").

### 13. Add yourself as an internal tester (~2 min)

Still in App Store Connect → TestFlight tab:
1. **Internal Testing** left sidebar → "+" next to Internal Group (or "App Store Connect Users").
2. Add your own Apple ID email.
3. Assign the build.
4. You'll get a TestFlight email/notification on your iPad within a minute.

### 14. Install on your iPad (~1 min)

1. Open the TestFlight email on your iPad → tap "View in TestFlight".
2. Or open the TestFlight app → your app → **Install**.
3. Play! 🎉

---

## Round-trip iteration (for subsequent builds)

Once step 1–2 are done and you have signing set up on the Mac, subsequent iterations are:

1. Push code from Windows → `git push`
2. On MacinCloud: `cd ShanghaiRummy && git pull && xcodegen generate` (only if `project.yml` changed) then Archive + Distribute (~5 min)
3. Bump the build number in `project.yml` before each upload: `CURRENT_PROJECT_VERSION: "2"`, `"3"`, ... (App Store Connect requires monotonically increasing build numbers)
4. Install the new build via TestFlight app on your iPad.

---

## When you're ready to open it up to family

In App Store Connect → TestFlight → **External Testing** → New Group ("Family").
- Add family emails (up to 10,000 external testers, no Apple ID required for them).
- First external build requires a ~24-hour Apple review (they check the build isn't obviously broken). Subsequent builds from the same group deploy in minutes.
- Each family member downloads TestFlight from the App Store and taps the invite link you send them.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "No account for team" in Xcode Signing | Settings → Accounts → sign in with the Apple ID that owns the developer account |
| "Failed to register bundle identifier" | The App ID exists but under a different team. Delete it in developer.apple.com or change the bundle ID prefix in `project.yml` |
| Archive missing / grayed out | Destination must be "Any iOS Device", not a simulator |
| Upload succeeds but build never appears in TestFlight | Check your email — Apple sends processing failures there (usually missing icon or version conflict) |
| "Missing compliance" won't clear | Delete the build in TestFlight, add `ITSAppUsesNonExemptEncryption=false` (already done), bump build number, re-upload |
| TestFlight says "This beta isn't accepting testers" | Open App Store Connect and click the build to accept it after processing |

---

## Cost expectation

| Item | Cost |
|---|---|
| Apple Developer Program (annual) | $99/yr (already paid) |
| MacinCloud Managed Server, one session | ~$1–3 |
| MacinCloud subsequent sessions (until you decide to buy a Mac) | ~$1–3 each |
| TestFlight itself | Free |
| Total to get onto your iPad this weekend | **~$3** |
