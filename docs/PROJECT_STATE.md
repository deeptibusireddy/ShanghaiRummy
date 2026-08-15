# Shanghai Rummy Project State

Last updated: 2026-08-15 01:10 PDT

## Resume first

1. Read this file before making changes.
2. Run `git status -sb`, `git branch --show-current`, and inspect recent commits.
3. Resume the relevant Copilot session with `copilot --continue` or
   `copilot --resume`.
4. If session history is incomplete after a crash or restore, run
   `/chronicle reindex`.

## Released state

- Released branch: `main`
- Released commit: `24c3559` (`Release Build 31`)
- Marketing version: `1.0`
- Project build number: `31`
- Pull request: https://github.com/deeptibusireddy/ShanghaiRummy/pull/3
- Main GitHub Actions run:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/31871973244
- Xcode Cloud archive:
  https://appstoreconnect.apple.com/teams/35852cea-059f-4cb5-95f1-c9cecb6cb122/apps/6798119446/ci/builds/0b8ff90c-355c-48c1-8b54-b2bb130768b3/action/8638d84d-f6bc-4043-a2db-7b2274fc6831
- The Xcode Cloud archive succeeded and uploaded Build 31 to App Store Connect
  for TestFlight processing.

## Current task

Build 31 is released. The user is about to test it on their phone and asked
that all progress and context be persisted before the laptop sleeps.

Build 31 completed:

- Fixed the stock-exhaustion hang with deterministic discard recycling.
- Retains the top discard on the first recycle.
- Ends and scores the hand on the second stock exhaustion.
- Added a persistent local-player `BUYS LEFT` counter from 3 to 0.
- Repeats the remaining-buy count in actual non-turn buy prompts.
- Uses a fixed-size, high-contrast rank/suit chip in the Buy/Take button while
  keeping the purchase panel 216 points wide.
- Final feature commits: `23388cf`, `a072bda`, and `d60dc8b`.
- Release commit: `24c3559`.
- PR #3, release-SHA validation, main GitHub Actions, and Xcode Cloud all
  succeeded.

Persistence state:

- Explicit Copilot CLI session syncing remains enabled with
  `remoteExport: true`.
- User-level hooks mirror checkpoints on `agentStop`, `sessionEnd`, and
  `errorOccurred`.
- Current session checkpoint:
  `.copilot-local/checkpoints/5bafc69c-36a7-4854-a3b0-d55684515da2/002-build-31-released.md`
- Release handoff:
  `.copilot-local/artifacts/release-handoff/build-31.md`
- Credential-free backup:
  `%USERPROFILE%\.copilot-safe-backup`
- Source code and release history are pushed to GitHub.

## Pending

- Install and test Build 1.0 (31) from TestFlight.
- Record the next batch of phone feedback before changing code.
- Start future work on `feedback/build-32` from `main` at `24c3559`.
- Select a **Usage billed to** entity in GitHub Copilot settings if durable
  Copilot Memory is still desired. Local checkpointing and GitHub source
  persistence are already active.
- Do not merge this continuity-only branch into `main` by itself because every
  `main` push triggers an Xcode Cloud/TestFlight archive.

## Established release process

1. Accumulate the requested feedback batch without incrementing the build.
2. Validate the exact candidate through macOS GitHub Actions.
3. Fix failures and inspect screenshot artifacts.
4. Set `CURRENT_PROJECT_VERSION` to the intended TestFlight build.
5. Promote the validated candidate and release bump to `main` in one push.
6. Confirm `Build & Test (iOS Simulator)` succeeds.
7. Confirm `ShanghaiRummy | Default | Archive - iOS` succeeds.
8. Report the build as uploaded and processing only after Xcode Cloud succeeds.

## Future checkpoint fields

Every update to this file should include:

- Current objective and user intent.
- Completed work and meaningful decisions.
- Current branch and released commit/build.
- Dirty or unpushed files and commits.
- Validation, PR, GitHub Actions, and Xcode Cloud links.
- Blockers or required user actions.
- One exact next action.
