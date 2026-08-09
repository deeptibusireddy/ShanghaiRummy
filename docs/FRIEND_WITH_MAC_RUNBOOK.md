# 🍎 Xcode Cloud Bootstrap — Instructions for a Friend with a Mac

**What we're asking you to do:** Spend ~10 minutes clicking through a wizard in Xcode so my iOS game can auto-deliver to my iPhone via TestFlight. After this one-time click-through, I never need a Mac again.

**Your risk:** essentially none.
- You will use **my** Apple ID (I'll be sitting next to you, or on a video call, entering my password)
- You will not need to download my code
- You will not commit anything
- You will not need to keep any files afterwards
- Nothing gets installed on your Mac permanently except Xcode itself (which is free from Apple, safe, made by Apple)

**What you need:**
- macOS Sonoma (14) or later
- Free disk space: ~10 GB *(most of it is Xcode)*
- ~40 min total if you don't have Xcode yet, ~10 min if you do

---

## Step 1 — Install Xcode (skip if already installed)

1. Open the **App Store** on the Mac.
2. Search for **Xcode**.
3. Click **Get** / **Install**. Enter *your* Apple ID password to authorize the download.
4. Wait ~20–30 min for the download to finish (Xcode is ~10 GB).
5. Once installed, open **Xcode**.
6. It'll ask you to install additional components — click **Install**.
7. Accept the license.

---

## Step 2 — Sign into Xcode with MY Apple ID (2 min)

*(I'll be next to you or on a video call and will type my password myself.)*

1. In Xcode's menu bar: **Xcode → Settings…** (or **Preferences** on older Xcode).
2. Click the **Accounts** tab.
3. Click the **"+"** button in the bottom-left.
4. Choose **Apple ID**.
5. I'll type my Apple ID email and password.
6. Once signed in, my team ("Deepti Busireddy") should appear in the middle.
7. Close Settings.

---

## Step 3 — Open my project (2 min)

Open Terminal (Applications → Utilities → Terminal) and paste:

```bash
cd ~
git clone https://github.com/deeptibusireddy/ShanghaiRummy.git
cd ShanghaiRummy
brew install xcodegen 2>/dev/null || true
xcodegen generate
open ShanghaiRummy.xcodeproj
```

Xcode opens with the project.

*(If `brew` isn't installed, run this first, then re-run the above:*
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
*)*

---

## Step 4 — Fill in the Team ID (1 min)

*(I'll tell you my 10-character Team ID — it's not a secret but I don't publish it.)*

1. In the Xcode left sidebar, click the blue **ShanghaiRummy** project icon at the top.
2. Center pane → target **ShanghaiRummy** → **Signing & Capabilities** tab.
3. **"Team"** dropdown → pick **"Deepti Busireddy"** (or whatever my personal team is named).
4. "Automatically manage signing" should already be checked. If not, check it.
5. Xcode will download a signing certificate. Wait for any yellow warnings to clear (~10 sec).

---

## Step 5 — Create the Xcode Cloud workflow (3 min) 🎯 THIS IS THE ONE STEP THAT ONLY WORKS FROM XCODE

1. Menu bar: **Product → Xcode Cloud → Create Workflow…**
   *(If "Xcode Cloud" isn't in the Product menu, try: **Integrate → Create Workflow…** — Apple renamed this in some Xcode versions.)*

2. A wizard opens.

3. **First screen** — "Select a Product":
   - Should already show **ShanghaiRummy** — click **Next**.

4. **Grant Source Code Access**:
   - Choose **GitHub**.
   - You'll be sent to your browser to authorize the **Xcode Cloud** GitHub App.
   - When GitHub asks which repos: choose **"Only select repositories"** → pick **`deeptibusireddy/ShanghaiRummy`** → **Install & Authorize**.
   - Return to Xcode.

5. **Workflow Details** screen — accept defaults or set:
   - Name: `Deploy to TestFlight`
   - Description: (leave blank)
   - Repository: `deeptibusireddy/ShanghaiRummy` (should be pre-filled)
   - Branch: `main`

6. **Actions:**
   - Xcode auto-adds a **Build** action. Keep it.
   - Click **"+ "** next to Actions → add **Archive**.
     - Deployment Preparation: **App Store Connect**

7. **Post-Actions:**
   - Click **"+"** next to Post-Actions → add **TestFlight Internal Testing**.
     - Groups: **App Store Connect Users** (default).

8. Click **Next → Save**.

9. Xcode will offer to **Start Build**. Click **Start Build**.

The build now runs in Apple's cloud (nothing runs on your Mac). You can close Xcode — the build continues remotely and I'll get notified on my phone when it lands in TestFlight.

---

## Step 6 — Sign me out (1 min)

Before you close everything:

1. **Xcode → Settings → Accounts** → select my account → click **"–"** to remove it.
2. This signs me out; I don't stay logged in on your Mac afterwards.
3. Feel free to delete the `~/ShanghaiRummy` folder if you like (`rm -rf ~/ShanghaiRummy` in Terminal).

---

## That's it! 🙏

You just saved me a $99+ Mac rental. From this point on, every time I push code from Windows, Apple's cloud rebuilds and delivers to TestFlight automatically — you never need to help again unless something breaks.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Xcode signing shows "No account for team" | Repeat Step 2 |
| "Failed to register bundle identifier" | Tell me — probably means my App ID isn't linked correctly |
| GitHub authorization fails | Try Safari instead of another browser; Apple's GitHub OAuth sometimes hates Chrome |
| "Xcode Cloud" not in Product menu | Update Xcode to the latest version (App Store → Updates) |
| Build fails in Apple's cloud | Send me the error message — I'll fix it and we retry (from Windows, no more Mac needed) |
