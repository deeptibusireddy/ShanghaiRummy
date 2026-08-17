# Shanghai Rummy Project State

Last updated: 2026-08-17 11:32 PDT

## Resume first

1. Read this file before making changes.
2. Run `git status -sb`, `git branch --show-current`, and inspect recent commits.
3. The released source is `main` at `0130cd4`.
4. Resume the relevant Copilot session with `copilot --continue` or
   `copilot --resume`.
5. If session history is incomplete after a crash or restore, run
   `/chronicle reindex`.

## Released state

- Released branch: `main`
- Released commit: `0130cd41e486097309ee39fc3828fb5bc779ee17`
  (`Release Build 42 (#15)`)
- Marketing version: `1.0`
- Project build number: `42`
- Device family: iPad only
- Pull request:
  https://github.com/deeptibusireddy/ShanghaiRummy/pull/15
- Main GitHub Actions:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32054226680
  - Result: succeeded
- Xcode Cloud:
  https://appstoreconnect.apple.com/teams/35852cea-059f-4cb5-95f1-c9cecb6cb122/apps/6798119446/ci/builds/13f48d49-9f24-4f5e-8df5-359a3dac45d2
  - Result: succeeded
  - Build 42 was archived, signed, uploaded, and delivered to the internal
    TestFlight workflow.

## Build 42 completed

- Plays the local-player turn cue for each distinct actionable draw, off-turn
  buy, and meld/discard prompt.
- Keeps the cue silent for bots, initial observation, inactive apps, and
  same-phase hand edits.
- Uses a 900 ms delay for visible local and hosted bot actions while keeping
  tests and simulations synchronous.
- Draws a unique non-joker opening card for every player.
- Treats Ace as high, seats players highest-to-lowest clockwise, makes the
  lowest draw the opening dealer, and gives the highest draw the first turn.
- Shows an animated opening-card reveal and seating ceremony before play.
- Blocks human and bot actions until the ceremony completes or
  `Take Your Seats` is selected.
- Supports the opening ceremony in local, hot-seat, bot-only, and Game Center
  games.
- Adds per-bot Easy, Medium, and Hard selection, defaulting to Hard.
- Preserves each selected difficulty through local setup, Game Center setup,
  realtime snapshots, and hosted bot execution.
- Keeps every difficulty legal and able to complete all ten levels.
- Includes the Build 41 level-10 ranked winner celebration and the production
  simulation fixes.

## Important decisions

- `GameState.activePlayerId`, rather than only `currentPlayerId`, controls turn
  feedback because an off-turn buyer can own the actionable prompt.
- Opening draws use a separate deterministic RNG seeded with
  `seed ^ 0xD1B54A32D192ED03`, preserving the existing game-deck shuffle for a
  given match seed.
- Jokers and duplicate opening ranks are redrawn.
- Do not assume the local player is `players[0]`; identify players by UUID.
- Realtime protocol version 4 separates Build 42 from Build 41 protocol
  version 3.
- Easy uses simple matching and high-point discards. Medium protects contract
  progress. Hard retains the full opponent-aware strategy.
- Required level 7-10 capacity buys remain active at every bot difficulty.
- Bot difficulty affects decisions only, not hidden information, legality, or
  animation speed.

## Validation history

- Turn pacing candidate:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32042491451
  - Result: succeeded
- First opening-draw run:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32045952363
  - Result: failed because tests still assumed input player order and an
    automatically dismissed UI screen.
- Corrected opening-draw run:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32046951460
  - Result: succeeded
- Final bot-difficulty candidate:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32048943134
  - Result: succeeded
- Released `main`:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32054226680
  - Result: succeeded
- No new 5,000-game workflow was run for Build 42. The last complete production
  rules simulation remains Build 41's 5,000 successful games and raw archive
  in `docs/build-41-readiness`.

## Persistence state

- Source and release history are pushed to GitHub.
- This continuity-only branch is `chore/persistent-agent-context`.
- Detailed release handoff:
  `.copilot-local/artifacts/release-handoff/build-42.md`
- Current session checkpoint:
  `.copilot-local/checkpoints/5bafc69c-36a7-4854-a3b0-d55684515da2/014-build-42-released.md`
- User-level checkpoint hooks continue mirroring session checkpoints into the
  project.
- Credential-free local backup:
  `%USERPROFILE%\.copilot-safe-backup`
- Copilot Memory remains blocked until GitHub recognizes a default
  `Usage billed to` entity. The repository handoff does not depend on Memory.

## Next action

Install and test Build 42 on the physical iPad. Verify the opening seating
ceremony, prompt-wide turn cue, 900 ms bot pacing, all three bot strengths,
Game Center behavior, and the round-10 winner celebration. Record the next
feedback batch before changing source.

Start future source work from released `main` at `0130cd4`, normally on
`feedback/build-43`. Do not use this continuity branch for product changes, and
do not push another change to `main` until the user explicitly requests the
next TestFlight release because every `main` push starts Xcode Cloud.

## Established release process

1. Accumulate the requested feedback batch without incrementing the build.
2. Validate the exact candidate through macOS GitHub Actions.
3. Fix failures and inspect screenshot artifacts.
4. Set `CURRENT_PROJECT_VERSION` to the intended TestFlight build.
5. Promote the validated candidate and release bump to `main` in one push.
6. Confirm the iPad GitHub Actions job succeeds.
7. Confirm the `ShanghaiRummy | Default` Xcode Cloud status succeeds.
8. Report the build as uploaded only after Xcode Cloud succeeds.

## Future checkpoint fields

Every update to this file should include:

- Current objective and user intent.
- Completed work and meaningful decisions.
- Current branch and released commit/build.
- Dirty or unpushed files and commits.
- Validation, PR, GitHub Actions, and Xcode Cloud links.
- Blockers or required user actions.
- One exact next action.
