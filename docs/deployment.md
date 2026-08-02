# Deployment & Testing (No Mac Required)

This project is designed to be built and tested by CI on Apple's / GitHub's
macOS runners, so you can develop from Windows and still ship to the App Store.

## Testing tiers

| Stage                          | Where it runs             | Requires a Mac?      |
| ------------------------------ | ------------------------- | -------------------- |
| Unit tests + build validation  | GitHub Actions (`ios.yml`) | No (already set up) |
| Beta distribution (family)     | Xcode Cloud → TestFlight  | ~1 hour one-time    |
| Manual debugging on device     | Xcode + physical iPhone   | Yes (rent a Mac)    |
| App Store submission           | Xcode Cloud or Transporter | ~1 hour one-time    |

## Tier 1 — GitHub Actions (active now)

Every push to `main` and every PR runs `.github/workflows/ios.yml`:
1. Checks out the repo on a `macos-14` runner
2. Installs XcodeGen and generates `ShanghaiRummy.xcodeproj`
3. Runs `xcodebuild ... test` against the iOS Simulator
4. Uploads `.xcresult` bundles as an artifact

This is your daily safety net. **If your push turns green, your code compiles
and passes tests.**

Free-tier budget: ~2,000 macOS-runner minutes/month on a personal account.
Each run of this workflow takes ~5–8 minutes → hundreds of pushes/month.

## Tier 2 — Xcode Cloud + TestFlight (set up when ready for M5)

Xcode Cloud is Apple's CI, free with your $99/yr developer account (25
compute hours/month). It can build, sign, and deliver to TestFlight without
you ever running Xcode locally.

### One-time setup (~1 hour, needs a Mac)

Options for the one-hour Mac session:
- Rent a MacinCloud instance (~$1 for the hour)
- Borrow a friend's Mac
- Use a MacStadium free trial

Steps on the Mac:
1. Install Xcode from the App Store
2. Sign in to your Apple Developer account in Xcode preferences
3. In App Store Connect (browser), create the app record:
   - Name: Shanghai Rummy
   - Bundle ID: `com.deeptibusireddy.ShanghaiRummy`
   - SKU: `shanghairummy001`
4. Clone this repo, run `xcodegen generate`, open `.xcodeproj`
5. In **Signing & Capabilities**: pick your Team → Xcode auto-creates a
   provisioning profile
6. Enable the **Game Center** capability
7. **Product → Xcode Cloud → Create Workflow**:
   - Trigger: push to `main`
   - Action: Archive → TestFlight (Internal Testing)
   - Xcode Cloud will find `ci_scripts/ci_post_clone.sh` automatically
8. Push a commit — Xcode Cloud builds it and uploads to TestFlight
9. Invite family via email in TestFlight

After that, every push to `main` auto-delivers to your family testers.

## Tier 3 — Debugging on a real device

If a bug shows up only on real hardware, you have two paths:

**a) Rent a cloud Mac + connect over VNC**
Runs Xcode, deploys to a locally connected iPhone via
[Sidecar-style relay](https://developer.apple.com/documentation/xcode/running-your-app-in-a-simulator-or-device)
— tricky, latency-sensitive, but doable for occasional debugging.

**b) Add extensive logging + read TestFlight crash reports**
For a card game, this is usually enough. Xcode Cloud + TestFlight surfaces
crash logs and analytics without you touching Xcode.

## Tier 4 — App Store submission

Once TestFlight testing is happy:
1. In App Store Connect (browser): fill in listing, screenshots, privacy labels
2. Xcode Cloud workflow can be extended with a `Release → App Store` action
3. Submit for review from the browser

**No Mac required after the one-hour setup.**

## Cost summary

| Item                      | Cost                              |
| ------------------------- | --------------------------------- |
| Apple Developer Program   | $99/year (you already have this)  |
| GitHub Actions macOS      | Free (2,000 min/mo)               |
| Xcode Cloud               | Free (25 hr/mo)                   |
| MacinCloud (one-time)     | ~$1–5 for initial setup           |
| **Total ongoing**         | **$99/year**                      |
