# Build 42 Release Handoff

Updated: 2026-08-17 11:32 PDT

## Final state

- Released branch: `main`
- Released commit: `0130cd41e486097309ee39fc3828fb5bc779ee17`
  (`Release Build 42 (#15)`)
- Marketing version: `1.0`
- Build number: `42`
- Device family: iPad only
- Pull request:
  https://github.com/deeptibusireddy/ShanghaiRummy/pull/15
- Main GitHub Actions:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32054226680
  - Result: succeeded
- Xcode Cloud:
  https://appstoreconnect.apple.com/teams/35852cea-059f-4cb5-95f1-c9cecb6cb122/apps/6798119446/ci/builds/13f48d49-9f24-4f5e-8df5-359a3dac45d2
  - Result: succeeded
  - Build 42 was uploaded through the internal TestFlight workflow.

## Included feedback

- Plays the turn cue for every distinct actionable local-player prompt.
- Slows visible bot actions to 900 ms.
- Adds a deterministic opening-card draw and seating ceremony.
- Seats players highest-to-lowest clockwise, with Ace high.
- Assigns the lowest draw as opening dealer and the highest draw first turn.
- Adds selectable Easy, Medium, and Hard strength for every bot.
- Preserves bot strengths through local and Game Center games.
- Includes full regression coverage and updated player-facing documentation.

## Validation

- Candidate runs `32042491451`, `32046951460`, and `32048943134` succeeded.
- Run `32045952363` exposed stale ordering/UI assumptions; those tests were
  corrected before release.
- Released-main run `32054226680` succeeded.
- No new 5,000-game simulation was required for Build 42. Build 41's complete
  5,000-game production-rule results remain in `docs/build-41-readiness`.

## Next action

Install Build 42 on the physical iPad and record feedback for opening seating,
turn cues, bot pacing, bot strengths, Game Center, and the level-10 finale.
Begin future work from `main` at `0130cd4` on `feedback/build-43`.
