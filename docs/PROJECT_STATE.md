# Shanghai Rummy Project State

Last updated: 2026-08-14 19:17 PDT

## Resume first

1. Read this file before making changes.
2. Run `git status -sb`, `git branch --show-current`, and inspect recent commits.
3. Resume the relevant Copilot session with `copilot --continue` or
   `copilot --resume`.
4. If session history is incomplete after a crash or restore, run
   `/chronicle reindex`.

## Released state

- Released branch: `main`
- Released commit: `17878d3` (`Release Build 29`)
- Marketing version: `1.0`
- Project build number: `29`
- Pull request: https://github.com/deeptibusireddy/ShanghaiRummy/pull/1
- Main GitHub Actions run:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/31854365524
- Xcode Cloud archive:
  https://appstoreconnect.apple.com/teams/35852cea-059f-4cb5-95f1-c9cecb6cb122/apps/6798119446/ci/builds/2fffa5ed-e533-4ab1-966c-4396f24be482/action/75ae163f-69ef-4bf0-a1f5-b52ebc7e2f14
- The Xcode Cloud archive succeeded and uploaded Build 29 to App Store Connect.
  TestFlight processing or device availability has not been independently
  confirmed.

## Current task

Persistence and recovery infrastructure is being added on branch
`chore/persistent-agent-context`.

Completed locally:

- Explicit Copilot CLI session syncing: `remoteExport: true`.
- Explicit Copilot Memory preference: `memory: true`.
- User-level hooks mirror session checkpoints on `agentStop`, `sessionEnd`, and
  `errorOccurred`.
- A credential-free backup of the active session and safe Copilot configuration
  is written to `%USERPROFILE%\.copilot-safe-backup`.
- Repository-wide continuity and release-safety instructions are defined in
  `.github/copilot-instructions.md`.
- `.copilot-local/` is ignored repository-wide.

## Pending

- Select a **Usage billed to** entity in GitHub Copilot settings so Copilot
  Memory can store durable facts. The local `memory: true` preference is already
  set, but server-side memory writes remain blocked until billing is selected.
- Restart or resume Copilot CLI after this setup so the updated hooks and
  instructions are loaded.
- Include `chore/persistent-agent-context` in the next requested app release.
  Do not merge it into `main` by itself because every `main` push triggers an
  Xcode Cloud/TestFlight archive.
- Install and test Build 29 when it becomes available in TestFlight.

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
