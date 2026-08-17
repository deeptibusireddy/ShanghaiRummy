<overview>
Build 42 is fully released through the internal TestFlight workflow. The
released source is main commit 0130cd4, GitHub Actions succeeded, Xcode Cloud
succeeded, and the next task is physical-iPad testing and feedback capture.
</overview>

<history>
1. Build 41 established the current foundation.
   - Improved table setup, hand interactions, HUD clarity, bot pacing, and the
     level-10 ranked winner celebration.
   - Added deterministic production-rule simulation infrastructure.
   - Completed 5,000 games and fixed wild-redemption and late-level bot-buy
     bugs exposed by simulation.
   - Released through TestFlight as main commit 0de5789.

2. Build 42 expanded turn feedback and bot pacing.
   - The local-player cue now covers draw, off-turn buy, and meld/discard
     prompts.
   - Same-phase edits, bots, initial observation, and inactive apps remain
     silent.
   - Visible local and hosted bot actions now wait 900 ms.
   - Feature commit: 17b4c45.

3. Build 42 added a real-life-style opening draw.
   - Every player draws a unique non-joker rank.
   - Ace is high.
   - Players are seated highest-to-lowest clockwise.
   - The lowest draw deals first and the highest draw takes the first turn.
   - An animated reveal and seating ceremony gates all play until completion
     or Take Your Seats.
   - Local, hot-seat, bot-only, and Game Center games are supported.
   - Feature commit: e4a08d8.

4. The first opening-draw CI run exposed stale assumptions.
   - Tests assumed the input roster remained GameState.players order.
   - The screenshot test tapped Continue after automatic dismissal.
   - Tests now identify semantic players by name or UUID.
   - UI testing holds the seated stage for reliable screenshots.
   - Correction commit: 792c123.

5. Build 42 added selectable bot strengths.
   - Every bot seat offers Easy, Medium, and Hard, defaulting to Hard.
   - Difficulty follows bot UUIDs through local and Game Center games.
   - Every tier remains legal and can complete all ten levels.
   - Feature commit: e7fa232.

6. Build 42 was released.
   - PR #15 merged into main as 0130cd4.
   - Main GitHub Actions run 32054226680 succeeded.
   - Xcode Cloud build 13f48d49-9f24-4f5e-8df5-359a3dac45d2
     succeeded and uploaded Build 42 through the internal TestFlight workflow.
</history>

<work_done>
Build 42 completed:
- [x] Prompt-based local-player turn chimes
- [x] 900 ms visible bot pacing
- [x] Deterministic opening seating draw
- [x] Unique non-joker ranks with Ace high
- [x] Highest-to-lowest clockwise seating
- [x] Lowest-draw opening dealer
- [x] Highest-draw first turn
- [x] Animated reveal and seating ceremony
- [x] Human, local-bot, and hosted-bot ceremony gating
- [x] Easy, Medium, and Hard selection per bot
- [x] Local and Game Center difficulty propagation
- [x] Unit, protocol, view-model, and UI regression coverage
- [x] Player-facing and UX documentation
- [x] PR and released-main validation
- [x] Xcode Cloud archive and TestFlight upload

Release state:
- Branch: main
- Commit: 0130cd41e486097309ee39fc3828fb5bc779ee17
- Build: 1.0 (42)
- PR: https://github.com/deeptibusireddy/ShanghaiRummy/pull/15
- Main validation:
  https://github.com/deeptibusireddy/ShanghaiRummy/actions/runs/32054226680
- Xcode Cloud:
  https://appstoreconnect.apple.com/teams/35852cea-059f-4cb5-95f1-c9cecb6cb122/apps/6798119446/ci/builds/13f48d49-9f24-4f5e-8df5-359a3dac45d2

Candidate validation:
- 32042491451: turn feedback and pacing succeeded
- 32045952363: failed due stale test assumptions
- 32046951460: corrected opening draw succeeded
- 32048943134: final bot difficulty candidate succeeded

No new 5,000-game workflow was run for Build 42. Build 41's complete
production-rule dataset remains committed under docs/build-41-readiness.
</work_done>

<technical_details>
Turn feedback:
- GameState.activePlayerId drives the cue because an off-turn buyer can own the
  actionable prompt while currentPlayerId remains unchanged.
- The cue fires once per distinct actionable draw, buy, or meld/discard prompt.
- It remains silent for bots, initial observation, inactive apps, and
  same-phase edits.
- Local and hosted bots share GameViewModel.defaultCPUActionDelay = 900 ms.
- Tests and simulations use an immediate synchronous CPU execution path.

Opening draw:
- OpeningDraw stores player identity and card.
- A separate RNG seeded with seed ^ 0xD1B54A32D192ED03 preserves the original
  game-deck shuffle for the same match seed.
- Jokers and duplicate ranks are redrawn.
- Ace has seating value 14.
- openingDraws preserves original roster order for the reveal.
- GameState.players is reordered descending by draw value.
- dealerIndex = players.count - 1 and currentTurnIndex = 0.
- Seat layout rotates around the local player by UUID while preserving
  clockwise order.
- The reveal and seating stages each use 2.4 seconds.
- The ceremony appears only for a pristine first-hand state.
- Under --ui-testing, automatic dismissal is disabled for screenshots.

Identity and networking:
- newVsCPU returns localPlayerId, bot IDs, and the difficulty map.
- Code must not assume the local player is players[0].
- Game Center creates identities before sorting and binds participants by UUID.
- Realtime protocol version is 4.

Bot difficulty:
- BotDifficulty is Codable with easy, medium, and hard values.
- Easy uses obvious matches, limited buys, and simple high-point discards.
- Medium measures and protects contract progress but lacks opponent-aware
  discard and advanced redemption tactics.
- Hard preserves the full opponent-aware strategy, optimized layoffs, and
  immediate wild redemption.
- Every difficulty performs required level 7-10 capacity buys.
- Difficulty changes decisions only, not information, legality, or pacing.
- Game Center setup sends ordered strengths; snapshots carry the UUID map.

Release behavior:
- Every push to main starts Xcode Cloud and can create another TestFlight build.
- Future feedback must accumulate on a separate branch.
- Only merge or push main when the user explicitly authorizes the next release.
</technical_details>

<important_files>
- Sources/ShanghaiRummy/Models/OpeningDraw.swift
- Sources/ShanghaiRummy/Models/BotDifficulty.swift
- Sources/ShanghaiRummy/Models/GameState.swift
- Sources/ShanghaiRummy/Rules/GameFactory.swift
- Sources/ShanghaiRummy/Rules/CPUPlayer.swift
- Sources/ShanghaiRummy/ViewModels/GameViewModel.swift
- Sources/ShanghaiRummy/App/Views/OpeningDrawView.swift
- Sources/ShanghaiRummy/App/Views/GameContainerView.swift
- Sources/ShanghaiRummy/App/Views/FamilyTableSetupView.swift
- Sources/ShanghaiRummy/App/Views/EntryFinalistDesignView.swift
- Sources/ShanghaiRummy/App/RootView.swift
- Sources/ShanghaiRummy/Multiplayer/RealtimeGameProtocol.swift
- Sources/ShanghaiRummy/Multiplayer/GameCenterManager.swift
- Sources/ShanghaiRummy/Scenes/GameScene.swift
- Tests/ShanghaiRummyTests/CPUPlayerTests.swift
- Tests/ShanghaiRummyTests/RealtimeGameProtocolTests.swift
- Tests/ShanghaiRummyUITests/ScreenshotUITests.swift
- project.yml
- docs/ux.md
- docs/how-to-play.md
- docs/XCODE_CLOUD_RUNBOOK.md
- docs/PROJECT_STATE.md
- .copilot-local/artifacts/release-handoff/build-42.md
</important_files>

<next_steps>
1. Install Build 42 on the physical iPad.
2. Verify opening seating, turn cues, 900 ms bot pacing, Easy/Medium/Hard bots,
   Game Center behavior, and the level-10 celebration.
3. Record the next feedback batch before making source changes.
4. Start future work on feedback/build-43 from main at 0130cd4.
5. Do not push main until the user explicitly requests the next TestFlight
   release.
6. Copilot Memory remains blocked by the missing default Usage billed to
   entity, but GitHub-backed continuity does not depend on it.
</next_steps>
