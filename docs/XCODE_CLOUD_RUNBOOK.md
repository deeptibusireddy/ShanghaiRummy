# Xcode Cloud → TestFlight (No Mac needed after one-time bootstrap) 🚀

> **⚠️ IMPORTANT — Read this first:**
> Apple's docs claim Xcode Cloud can be set up entirely from the web. **This is only partially true.**
> The **very first** enablement (creating the initial `ciProduct`) must be done from Xcode on a Mac — one time.
> After that one-time click-through, EVERYTHING else works from Windows/web/API.
>
> **For that one-time step, see one of:**
> - `docs/FRIEND_WITH_MAC_RUNBOOK.md` — ask a friend/family member with a Mac to do it in 10 min (free)
> - `docs/TESTFLIGHT_RUNBOOK.md` — rent MacinCloud for 20–30 min (~$1–3)
>
> This document describes what happens AFTER that bootstrap is done.

**Goal:** Ship Shanghai Rummy Nights to TestFlight on your iPad using **only a web browser** on Windows. Apple builds the app in their cloud on every push to `main`.

**Cost:** $0 (included with your $99/yr developer account — 25 build-hours/mo free).

**Time:** ~15 min for one-time setup, then every future build is automatic.

**Prerequisites (already done in prior session):**
- [x] Apple Developer Program enrollment ✅
- [x] App ID registered (`com.deeptibusireddy.ShanghaiRummy` + Game Center) ✅
- [x] App Store Connect record created ("Shanghai Rummy Nights") ✅
- [x] TestFlight app installed on your iPad ✅
- [x] `ci_scripts/ci_post_clone.sh` present + executable in the repo ✅
- [x] App icon, privacy manifest, encryption declaration ✅

---

## One-time setup (Windows browser only, ~15 min)

### Step 1 — Open Xcode Cloud in App Store Connect

1. Go to https://appstoreconnect.apple.com/apps
2. Click your app: **Shanghai Rummy Nights**
3. In the top navigation, click the **"Xcode Cloud"** tab.

If you see a "Get Started" hero, click it. Otherwise you'll see a workflow list.

### Step 2 — Connect to GitHub

1. When prompted "**Grant access to your source code**", pick **GitHub**.
2. You'll be bounced to GitHub to authorize the **Xcode Cloud** GitHub App.
3. Grant access to just the `deeptibusireddy/ShanghaiRummy` repo (safer than "all repos").
4. Back in App Store Connect, the repo should now appear in the list. Select it → **Next**.

If the repo doesn't appear, go to https://github.com/settings/installations → Xcode Cloud → Configure → make sure `ShanghaiRummy` is in the repository access list.

### Step 3 — First workflow

Apple auto-suggests a default workflow. Configure it as follows:

| Field | Value |
|---|---|
| **Workflow Name** | `Deploy to TestFlight` |
| **Description** | *(optional)* Push to main → build → deploy to internal testers |
| **Project or Workspace** | `ShanghaiRummy.xcodeproj` *(created by our `ci_post_clone.sh`)* |
| **Primary Repository** | `deeptibusireddy/ShanghaiRummy` |
| **Branch** | `main` |

**Start Conditions:**
- **Branch Changes** → Any commit → Auto-start workflow.
- Delete any other start conditions Apple adds by default.

**Environment:**
- **Xcode:** latest release
- **macOS:** Recommended

**Actions:**
- **Build** — check "iOS", scheme = `ShanghaiRummy` *(this is defined in `project.yml`)*
- *(Optional)* **Test** — same scheme. Skip for now; our tests are already covered by GitHub Actions.
- **Archive** — deployment preparation → **App Store Connect**

**Post-Actions:**
- **TestFlight Internal Testing** → select **App Store Connect Users** group (or create a new group later).

Click **Save**.

### Step 4 — First build

Xcode Cloud will offer to **Start Build** immediately. Click yes.

You'll see live logs — click into the run to watch:
- Clone repo
- Run `ci_post_clone.sh` (installs XcodeGen, generates the .xcodeproj)
- Resolve Swift packages
- Build & sign
- Archive
- Upload to App Store Connect
- Deliver to TestFlight

**Duration:** ~10–15 min for a first build (cold caches).

### Step 5 — Sign the compliance nag (one time)

When the build lands in TestFlight, it may show "Missing Compliance."

1. App Store Connect → your app → **TestFlight** tab → click the build.
2. Click **Manage** next to Export Compliance.
3. Answer **"No"** to "does your app use encryption not exempt from export".
4. Save.

We declare `ITSAppUsesNonExemptEncryption=false` in both `project.yml` and
`Info.plist`, so subsequent generated builds shouldn't need this.

### Step 6 — Install on your iPad

1. Open the **TestFlight** app on your iPad.
2. You should see **Shanghai Rummy Nights** listed automatically (because you're an internal tester on your own account).
3. Tap **Install** → wait ~15 sec → tap **Open**.
4. Play! 🎉

---

## From now on (Zero-touch delivery)

Every `git push` to `main` from Windows automatically:
1. Kicks off Xcode Cloud in the background (~10 min).
2. Uploads the new build to TestFlight.
3. Notifies you on your iPad in TestFlight when it's ready to install.

You literally never touch a Mac.

### Bumping the version number

Xcode Cloud increments `CURRENT_PROJECT_VERSION` automatically per build. You only need to touch `project.yml` when bumping the **marketing version** (user-visible version like `0.2.0` → `1.0.0`):

```yaml
settings:
  base:
    MARKETING_VERSION: "0.2.0"  # <-- bump this before major releases
```

---

## Adding family testers (when you're ready)

Same App Store Connect → TestFlight → **External Testing** → **Create Group** ("Family").

- Add family emails (up to 10,000 external testers, no Apple ID enrollment required for them).
- **First external build requires ~24-hour Apple beta review** (they sanity-check it isn't crash-on-launch). Subsequent builds from the same group ship in minutes.
- Family downloads TestFlight from the App Store, then taps the invite link you send them.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Xcode Cloud can't see repo | Re-visit https://github.com/settings/installations → Xcode Cloud → Configure repo access |
| Build fails at "Detecting schemes" | `ci_post_clone.sh` didn't run. Check it's executable (`git ls-files --stage` shows `100755`). Currently ✅. |
| Build fails at Archive | Usually first-time signing. In workflow config, ensure "Managed by Apple" is selected for signing. |
| No TestFlight notification | Check spam. Or open TestFlight app manually — build should appear silently. |
| "Missing compliance" nag every build | Confirm `ITSAppUsesNonExemptEncryption=false` is in both `project.yml` and `Info.plist` (it is ✅). |
| Homebrew missing in ci_post_clone | Xcode Cloud runners have Homebrew pre-installed; if it fails, the script installs it. |

---

## MacinCloud is still Plan B

If Xcode Cloud proves finicky (rare), the paid-Mac fallback in `TESTFLIGHT_RUNBOOK.md` still works. Xcode Cloud is the newer, cheaper, cleaner path — but MacinCloud is a valid escape hatch.
