# Build 41 App Store Readiness Handoff

Saved: 2026-08-17

This file is the durable restart point for the Build 41 work. It is tracked
in git and pushed to GitHub so continuity does not depend on Copilot session
state, temporary files, or expiring GitHub Actions artifacts.

## Resume snapshot

- Repository: `deeptibusireddy/ShanghaiRummy`
- Branch: `feedback/build-41-simplify-seat-cards`
- Pull request: https://github.com/deeptibusireddy/ShanghaiRummy/pull/14
- Head before this handoff commit: `ebe3026a972a71e125498d445edb7dac67b162b3`
- Marketing version: `1.0`
- Build number: `41`
- Device target: native iPad only (`TARGETED_DEVICE_FAMILY=2`)
- PR state: open and mergeable
- TestFlight status at handoff creation: Build 41 had not yet been merged,
  uploaded, or published.
- Release authorization: the user explicitly requested a TestFlight release
  on 2026-08-17 after the final simulation and iPad results passed.
- Release action: commit this handoff, merge PR #14 into `main`, and monitor
  Xcode Cloud/TestFlight. A push to `main` triggers Xcode Cloud.

## Final validation state

Both final runs used commit `ebe3026` and completed successfully:

- Pull request iPad build and test:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32007028036
- Manually dispatched iPad build, 5,000-game simulation, and aggregate
  verification:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32007027665

The manually dispatched workflow verified:

- 1,000 successful 2-player games
- 1,000 successful 3-player games
- 1,000 successful 4-player games
- 1,000 successful 5-player games
- 1,000 successful 6-player games
- 5,000 successful games total
- Zero final simulation failures
- Full iPad suite success

## Durable artifacts

### Complete raw simulation dataset

Path:

`docs/build-41-readiness/game-simulation-results.zip`

Contents:

- 100 JSON batch reports
- 50 games per report
- All 5,000 per-game records
- Deterministic seeds, action totals, turn totals, hand totals, scores,
  winners, contract progress, reshuffles, stock exhaustion, and hand sizes

Integrity:

- Size: 342,560 bytes
- SHA-256:
  `C1C76AE3DFCE60C29202D15D9AC4A77A9A1C51FBE4A45734BBB7E41DCAFA1820`

The dataset is committed to the repository so it remains available after the
GitHub Actions artifact expires.

### Reviewed bot-turn screenshot

Path:

`docs/build-41-readiness/bot-turn-progress.png`

Integrity:

- Size: 442,994 bytes
- SHA-256:
  `D9B73FF576F4847F978539ABCD2724BBFC467A9B8242E862FE40A013FBED0740`

Visual verdict:

- Active bot seat is clearly highlighted.
- The top banner clearly says `ALEX - BOT TURN`.
- Action guidance is visible.
- The center `Waiting for Alex` indicator prevents the table from appearing
  frozen.
- No visual release blocker was found.

## Completed Build 41 work

### Table setup and hand interaction

- Replaced shifting setup content with six stable reserved-seat positions.
- Anchored Add Human and Add Bot controls.
- Removed redundant Human/Bot toggles from occupied seat cards.
- Added only the X removal action to occupied seat cards.
- Changed hand rank sorting so Ace follows King.
- Changed suit sorting to Clubs, Hearts, Spades, Diamonds.
- Made taps reliably move cards into the staging tray.
- Kept discard, public meld placement, and wild redemption drag-targeted.

### Readability and feedback

- Increased player HUD readability.
- Added a local-human turn chime and supported haptic feedback.
- Added paced bot turns for local and host-authoritative online games.
- Normal bot actions wait 550 ms so activity remains visible.
- Added BOT TURN text, action-specific guidance, animated dots, and active-seat
  highlighting.
- Kept an immediate synchronous bot path for tests and simulations.

### Level 10 finale

- Games now end automatically when the final hand closes after a player
  completes level 10.
- Removed the extra Deal Next Hand / repeated scorecard path.
- Added ranked final standings, podium placement, crowns, confetti, and tied
  placements.
- Final ranking prioritizes champions, then contract progress, then lower
  penalty score.

### Production-rule simulation harness

- `Package.swift` exposes the production Models and Rules sources as
  `ShanghaiRummyCore`.
- `Simulation/main.swift` runs deterministic games and writes JSON reports.
- The simulator does not duplicate the game rules.
- `.github/workflows/ios.yml` runs 100 independent 50-game jobs.
- A final workflow job downloads all reports and requires exactly 1,000
  successful games for every table size.
- Run it with:

  `gh workflow run ios.yml --ref feedback/build-41-simplify-seat-cards`

## Bugs found and fixed during simulation

### Expanded-sequence wild redemption

Problem:

The engine reapplied the initial meld wild-count limit when redeeming a wild
from a sequence that had already been extended on the table. Table melds are
allowed to exceed the initial wild limit.

Observed failures included:

- 5-player game 17
- 6-player game 38
- 4-player game 24
- 3-player game 76

Fix:

- Added established-sequence validation that does not reapply the initial
  contract wild limit.
- Added a regression test for redeeming from an expanded sequence that remains
  over the initial wild limit after the swap.

Commit:

`b5e184b Fix wild redemption on expanded melds`

### Late-level two-player bot stalls

Problem:

At levels 7 through 10, a player needs enough cards to hold the full contract
and still discard. The bot's comparison between minimum required buys and
remaining buy allowance was reversed. In two-player games, bots could
continually skip the extra cards they needed and repeat hands indefinitely.

Earlier failing two-player game numbers included:

`186, 191, 291, 295, 456, 463, 540, 591, 653, 692`

Successful two-player games normally completed in about 800 actions, while
these seeds exceeded the old 100,000-action guard.

Fix:

- Late-level bots now buy while the remaining allowance can cover the
  contract-card deficit.
- Bots stop forced buying once the next normal draw leaves enough cards to
  complete the contract and discard.
- Added direct high-level buy tests.
- Added deterministic regression coverage for seed `2_000_591`.
- Added detailed failure-state diagnostics to future simulation reports.
- Reduced the simulation guard to 10,000 actions; the longest successful final
  game used only 2,967 actions.

Commit:

`ebe3026 Prevent late-level bot stalls`

## Aggregate simulation results

Totals across all table sizes:

- Games: 5,000
- Engine actions: 6,820,683
- Completed turns: 1,793,107
- Hands: 64,982
- Stock-exhausted hands: 1
- Stock reshuffles: 9
- Buy decisions: 2,542,270
- Buy passes: 2,164,807 (85.2 percent)
- Maximum observed hand size: 18 cards
- Games with tied winners: 14

| Players | Games | Avg actions | P95 actions | Max actions | Avg turns | Avg hands | Max hands | Avg buy decisions | Avg non-winner contracts |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 1,000 | 760.1 | 990 | 1,217 | 265.9 | 12.71 | 17 | 167.2 | 7.75 |
| 3 | 1,000 | 1,007.2 | 1,262 | 1,646 | 301.6 | 12.27 | 17 | 301.5 | 8.01 |
| 4 | 1,000 | 1,284.7 | 1,597 | 1,975 | 343.8 | 12.61 | 17 | 455.3 | 7.99 |
| 5 | 1,000 | 1,718.8 | 2,191 | 2,758 | 417.2 | 13.38 | 19 | 707.4 | 7.84 |
| 6 | 1,000 | 2,049.8 | 2,602 | 2,967 | 464.6 | 14.01 | 19 | 910.8 | 7.78 |

### Seat balance

No meaningful seat-position advantage was detected.

- 2 players: 49.6, 50.4 percent
- 3 players: 35.4, 32.5, 32.1 percent
- 4 players: 24.6, 25.9, 23.5, 26.1 percent
- 5 players: 21.1, 20.9, 20.6, 18.6, 18.8 percent
- 6 players: 17.1, 15.9, 16.0, 18.8, 15.3, 16.9 percent

No rules or dealer-balance adjustment is recommended from these results.

### Other non-issues

- Stock exhaustion occurred once across 64,982 hands.
- Only nine reshuffles were recorded.
- Final winner ties were rare and are already supported by the celebration.
- No simulation evidence calls for a stock-exhaustion UX change.

## UX recommendations for review

These are recommendations only. The user chose to test the current Build 41
candidate in TestFlight before selecting additional changes.

### 1. Autosave and resume unfinished games

Priority: highest, recommended before App Store submission.

Evidence:

- Games average 12 to 14 hands.
- Games average 266 to 465 turns.
- Large-table games reached 19 hands and 702 turns.
- The setup screen estimates 45 to 90 minutes.
- The repository describes persistence as planned, but no local game restore
  implementation was found.

Suggested experience:

- Save authoritative `GameState` after every accepted action.
- Restore an interrupted local game after app termination.
- Show Resume Game on the home screen.
- Preserve an explicit Start New Game option.

### 2. Pace meaningful bot actions, not routine buy passes

Priority: high.

Evidence:

- There were 2.54 million buy decisions.
- 85.2 percent were passes.
- Six-player games average 911 buy decisions.
- The current 550 ms delay is applied before every CPU action, including
  automatic pass decisions.

Suggested experience:

- Keep the visible pause for draws, discard takes, melds, layoffs, redemption,
  and discards.
- Make routine bot buy passes instant or very short.
- Preserve the BOT TURN banner throughout the bot's meaningful turn.

### 3. Add a small recent-action feed

Priority: high.

Evidence:

- Six-player games average about 49 contracts, 125 laid-off cards, and 21 wild
  redemptions.
- A transient banner explains the current action but cannot show what a player
  missed a moment earlier.

Suggested experience:

- Keep the latest two or three meaningful actions near the turn banner.
- Examples: `Alex drew stock`, `Jordan laid off 7 diamonds`,
  `Sam discarded king of clubs`.
- Exclude routine buy passes to avoid noise.

### 4. Add an 18-card hand regression fixture

Priority: high validation item.

Evidence:

- The maximum observed hand size was 18 cards.
- The existing crowded-hand screenshot fixture uses 17 cards.

Suggested experience:

- Extend the screenshot fixture and hit-testing coverage to 18 cards.
- Confirm readable overlap, new-card markers, reordering, staging, and drag
  targets on the smallest supported iPad layout.

### 5. Consider an optional Quick Match mode

Priority: post-launch or only if the user wants a shorter pre-launch mode.

Evidence:

- Full games commonly require 12 to 14 hands.
- Five- and six-player games average 417 and 465 turns.

Possible options:

- Start all players at a later contract.
- Play a selected subset of levels.
- Clearly label Quick Match as a separate rules mode so the family game remains
  unchanged.

### 6. Add a compact race-to-level-10 view

Priority: medium.

Evidence:

- Non-winners typically complete about eight contracts before the game ends.
- The current seat pills already show level, and Score opens standings, but
  the overall race requires scanning several areas.

Suggested experience:

- Add a compact ten-step progress row to the Score panel.
- Avoid adding permanent table clutter.

## Exact next steps for the next session

1. Open this file first.
2. Confirm whether Build 41 finished processing and is available in TestFlight.
3. Collect the user's iPad feedback after they try Build 41.
4. Review the six UX recommendations with the user.
5. Decide which, if any, are required before App Store submission.
6. Implement only the approved items on a new post-Build-41 branch.
7. Bump the build number before any later TestFlight upload.
8. If rules or bot behavior changes again, rerun the full 5,000-game workflow.
9. If only UI changes, run the focused iPad suite and inspect screenshots.

Useful commands:

```powershell
git switch feedback/build-41-simplify-seat-cards
git pull --ff-only
gh pr view 14
gh run view 32007027665
gh run view 32007028036
gh workflow run ios.yml --ref feedback/build-41-simplify-seat-cards
```

## Important files

- `.github/workflows/ios.yml`
  - iPad CI and parallel 5,000-game simulation workflow.
- `Package.swift`
  - Linux-compatible target using the production Models and Rules.
- `Simulation/main.swift`
  - Deterministic simulation and JSON reporting.
- `Sources/ShanghaiRummy/Rules/CPUPlayer.swift`
  - Bot draw, buy, meld, layoff, redemption, and discard decisions.
- `Sources/ShanghaiRummy/Rules/MeldValidator.swift`
  - Initial and established meld validation.
- `Sources/ShanghaiRummy/Rules/TurnEngine.swift`
  - Authoritative game state transitions and final-hand completion.
- `Sources/ShanghaiRummy/ViewModels/GameViewModel.swift`
  - Local bot pacing, turn activity, score/rank data, and view state.
- `Sources/ShanghaiRummy/Multiplayer/GameCenterManager.swift`
  - Host-authoritative online bot pacing.
- `Sources/ShanghaiRummy/Scenes/GameScene.swift`
  - Bot banner, active seats, cards, staging, melds, and table interaction.
- `Sources/ShanghaiRummy/App/Views/GameOverCelebrationView.swift`
  - Ranked winner celebration.
- `Sources/ShanghaiRummy/App/Views/EntryFinalistDesignView.swift`
  - Supper Club home and Dossier table setup.
- `project.yml`
  - Version `1.0 (41)` and iPad-only target.
- `docs/ux.md`
  - Current UX source of truth.

## Recent key commits

- `ebe3026` Prevent late-level bot stalls
- `ec3e9f2` Parallelize game simulation batches
- `b5e184b` Fix wild redemption on expanded melds
- `68c7523` Fix simulation CLI Swift 6 build
- `3215e11` Run simulations with Swift core harness
- `278e82c` Fix bot pacing and soak test execution
- `f46d802` Pace bot turns and add soak testing
- `b57d126` Finish level ten games with celebration
- `3f5d41e` Add player turn alerts
- `fd57d56` Improve player HUD readability
- `b6b40ec` Make hand taps stage cards

## Copilot Memory status

Repository-backed persistence is complete through this handoff and its
committed artifacts.

Copilot Memory itself is currently blocked because no default `Usage billed
to` entity is selected in Copilot settings. Do not depend on Memory for this
handoff. Once billing is configured, store a repository memory pointing future
sessions to this file.
